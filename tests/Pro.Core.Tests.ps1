$ErrorActionPreference='Stop'
. "$PSScriptRoot/../Pro-1-Core.ps1"
$script:Plan='381b4222-f694-41f0-9685-ff5bb260df2e'
$balanced=$script:Plan
$script:FailWrite=''
function Test-Path {
    param([string]$LiteralPath)
    if ($LiteralPath -like 'HKCU:*') { return $script:Registry.ContainsKey($LiteralPath) }
    return Microsoft.PowerShell.Management\Test-Path -LiteralPath $LiteralPath
}
function Get-Item {
    param([string]$LiteralPath)
    $key = [pscustomobject]@{ Path = $LiteralPath }
    $key | Add-Member ScriptMethod GetValueNames { return @($script:Registry[$this.Path].Keys) }
    $key | Add-Member ScriptMethod GetValueKind { param($Name) return [Microsoft.Win32.RegistryValueKind]::DWord }
    $key | Add-Member ScriptMethod GetValue { param($Name) return $script:Registry[$this.Path][$Name] }
    $key | Add-Member ScriptMethod Close { }
    return $key
}
function New-Item {
    param([string]$Path, [string]$ItemType, [switch]$Force)
    if ($Path -like 'HKCU:*') {
        # Simulate destructive replacement if an existing key is recreated.
        $script:Registry[$Path] = @{}
    } else { Microsoft.PowerShell.Management\New-Item -Path $Path -ItemType $ItemType -Force:$Force }
}
function New-ItemProperty {
    param([string]$LiteralPath, [string]$Name, [string]$PropertyType, $Value, [switch]$Force)
    if ($script:FailWrite -eq $Name) { throw 'Simulated registry write failure' }
    $script:Registry[$LiteralPath][$Name] = $Value
}
function Remove-ItemProperty {
    param([string]$LiteralPath, [string]$Name)
    $script:Registry[$LiteralPath].Remove($Name)
}
function Get-Process { param($Name,$ErrorAction) @() }
function UserID { 'lite-test-user' }
function Power($Verb,$Guid) {
 switch($Verb) {
 '/list' { $script:High }
 '/getactivescheme' { 'Text: '+$script:Plan }
 '/setactive' { $script:Plan=$Guid; '' }
 default { throw 'Unknown powercfg call' }
 }
}
$script:Registry=@{}
$script:Registry[$script:Targets[0][0]]=@{EnableTransparency=1;Unrelated=12}
$script:Registry[$script:Targets[2][0]]=@{AppCaptureEnabled=1}
$dir=Join-Path ([IO.Path]::GetTempPath()) ('lite-tests-'+[guid]::NewGuid().ToString('N'))
$backup=Join-Path $dir backup.json
$count=0
function Assert($ok,$msg) {if(-not $ok){throw $msg};$script:count++}
function Fails($op){$failed=$false;try{&$op}catch{$failed=$true};Assert $failed 'Expected failure'}
try {
 $null=Tune Daily $backup
 Assert ($script:Plan -eq $balanced) 'Daily must preserve plan'
 Assert ($script:Registry[$script:Targets[0][0]].EnableTransparency -eq 0) 'Transparency disabled'
 Assert ($script:Registry[$script:Targets[0][0]].Unrelated -eq 12) 'Unrelated key preserved'
 Assert ($script:Registry[$script:Targets[2][0]].AppCaptureEnabled -eq 1) 'Daily must preserve recording'
 Fails {Tune Gaming $backup}
 $null=Tune Restore $backup
 Assert ($script:Registry[$script:Targets[0][0]].EnableTransparency -eq 1) 'Desktop restored'
 Assert (-not $script:Registry[$script:Targets[1][0]].ContainsKey('TaskbarAnimations')) 'Absent value restored'
 $null=Tune Gaming $backup
 Assert ($script:Plan -eq $script:High) 'Game plan selected'
 Assert ($script:Registry[$script:Targets[2][0]].AppCaptureEnabled -eq 0) 'Recording disabled'
 $null=Tune Restore $backup
 Assert ($script:Plan -eq $balanced) 'Power restored'
 Assert ($script:Registry[$script:Targets[2][0]].AppCaptureEnabled -eq 1) 'Recording restored'
 $null=Tune Gaming $backup
 $s=Get-Content -LiteralPath $backup -Raw|ConvertFrom-Json
 $s.Settings[0].Path='HKCU:\Unexpected'
 $s|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $backup
 Fails {Tune Restore $backup}
 Assert (Test-Path -LiteralPath $backup) 'Invalid backup retained'
 $s.Settings[0].Path=$script:Targets[2][0]
 $s|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $backup
 $null=Tune Restore $backup
 $script:FailWrite='GameDVR_Enabled'
 Fails {Tune Gaming $backup}
 Assert (Test-Path -LiteralPath $backup) 'Partial backup retained'
 $script:FailWrite=''
 $null=Tune Restore $backup
 Assert ($script:Plan -eq $balanced) 'Partial apply restored'
 'PASS: '+$count+' Lite assertions, real backup files and mocked Windows settings.'
} finally {Remove-Item -LiteralPath $dir -Force -Recurse}
