Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. "$PSScriptRoot/../Pro-1-Core.ps1"
. "$PSScriptRoot/../Pro-2-Tools.ps1"
$script:Checks=0
function Assert($OK,$Message) { if(-not $OK){throw $Message};$script:Checks++ }
function Fails([scriptblock]$Action) { $failed=$false;try{&$Action}catch{$failed=$true};Assert $failed 'Expected rejection' }
$root=Join-Path ([IO.Path]::GetTempPath()) ('pro-tests-'+[guid]::NewGuid().ToString('N'))
$backup=Join-Path $root 'startup.json'
$script:Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$script:Items=@{}
$script:FailRemove=''
function UserID { 'test-pro-user' }
function Test-Path {
 param([string]$LiteralPath)
 if($LiteralPath -like 'HKCU:*'){return $LiteralPath -eq $script:Path}
 Microsoft.PowerShell.Management\Test-Path -LiteralPath $LiteralPath
}
function Get-Item {
 param([string]$LiteralPath)
 if($LiteralPath -ne $script:Path){throw 'Unexpected registry key'}
 $k=[pscustomobject]@{}
 $k|Add-Member ScriptMethod GetValueNames { @($script:Items.Keys) }
 $k|Add-Member ScriptMethod GetValueKind { param($name) [Enum]::Parse([Microsoft.Win32.RegistryValueKind],$script:Items[$name].Kind) }
 $k|Add-Member ScriptMethod GetValue { param($name,$default,$options) $script:Items[$name].Value }
 $k|Add-Member ScriptMethod Close {}
 $k
}
function New-ItemProperty {
 param($LiteralPath,$Name,$PropertyType,$Value,[switch]$Force)
 if($LiteralPath -ne $script:Path){throw 'Unexpected registry key'}
 $script:Items[$Name]=[pscustomobject]@{Name=$Name;Kind=$PropertyType;Value=$Value}
}
function Remove-ItemProperty {
 param($LiteralPath,$Name)
 if($LiteralPath -ne $script:Path -or $Name -eq $script:FailRemove){throw 'Simulated removal failure'}
 $script:Items.Remove($Name)
}
function Fixture {
 if(Microsoft.PowerShell.Management\Test-Path -LiteralPath $root){Remove-Item -LiteralPath $root -Recurse -Force}
 $script:Items=@{
  Music=[pscustomobject]@{Name='Music';Kind='ExpandString';Value='%LOCALAPPDATA%\Music\app.exe --tray'}
  Chat=[pscustomobject]@{Name='Chat';Kind='String';Value='C:\Chat\app.exe --startup'}
  NVIDIA=[pscustomobject]@{Name='NVIDIA';Kind='String';Value='driver.exe'}
 }
 $script:FailRemove=''
}
try {
 Fixture
 $selected=@(ReadStartup 'Music')
 $null=StartupChange $false $selected $backup
 Assert (-not $script:Items.ContainsKey('Music')) 'Selected startup disabled'
 Assert ($script:Items.ContainsKey('Chat') -and $script:Items.ContainsKey('NVIDIA')) 'Unselected apps preserved'
 $state=Get-Content -LiteralPath $backup -Raw|ConvertFrom-Json
 Assert ($state.Items[0].Value -ceq '%LOCALAPPDATA%\Music\app.exe --tray') 'ExpandString is backed up without expansion'
 Assert ($state.Items[0].Kind -eq 'ExpandString') 'Registry type preserved'
 Fails {StartupChange $false @(ReadStartup 'Chat') $backup}
 $null=StartupChange $true @() $backup
 Assert ($script:Items.Music.Value -ceq $selected[0].Value -and $script:Items.Music.Kind -eq 'ExpandString') 'Exact command and type restored'
 Assert (-not (Test-Path -LiteralPath $backup)) 'Backup archived only after verified restore'

 Fixture
 $selected=@(ReadStartup 'Music')
 $script:Items.Music.Value='changed.exe'
 Fails {StartupChange $false $selected $backup}
 Assert (-not (Test-Path -LiteralPath $backup)) 'Stale selection rejected before backup/write'
 Assert ($script:Items.Music.Value -ceq 'changed.exe') 'Stale selection does not remove new command'

 Fixture
 Fails {StartupChange $false @(ReadStartup 'NVIDIA') $backup}
 Assert ($script:Items.ContainsKey('NVIDIA')) 'Protected name remains enabled'
 Assert (@(StartupEntries).Name -notcontains 'NVIDIA') 'Protected name not listed for selection'
 Fails {StartupChange $false @() $backup}

 Fixture
 $null=StartupChange $false @(ReadStartup 'Music') $backup
 $script:Items.Music=[pscustomobject]@{Name='Music';Kind='String';Value='newer.exe'}
 Fails {StartupChange $true @() $backup}
 Assert ($script:Items.Music.Value -ceq 'newer.exe' -and (Test-Path -LiteralPath $backup)) 'Restore preserves conflicting newer entry and backup'
 $script:Items.Remove('Music')
 $null=StartupChange $true @() $backup
 Assert ($script:Items.Music.Kind -eq 'ExpandString') 'Retry after conflict resolution works'

 Fixture
 $script:FailRemove='Chat'
 Fails {StartupChange $false @((ReadStartup 'Music'),(ReadStartup 'Chat')) $backup}
 Assert (-not $script:Items.ContainsKey('Music') -and (Test-Path -LiteralPath $backup)) 'Partial disable retains recoverable snapshot'
 $script:FailRemove=''
 $null=StartupChange $true @() $backup
 Assert ($script:Items.ContainsKey('Music') -and $script:Items.ContainsKey('Chat')) 'Partial operation fully restored'

 Fixture
 $null=StartupChange $false @(ReadStartup 'Music') $backup
 $state=Get-Content -LiteralPath $backup -Raw|ConvertFrom-Json
 $state.User='wrong-user';$state|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $backup
 Fails {StartupChange $true @() $backup}
 Assert (-not $script:Items.ContainsKey('Music') -and (Test-Path -LiteralPath $backup)) 'Wrong-user backup cannot mutate registry'

 Fixture
 $null=New-Item -Path $root -ItemType Directory -Force
 $held=[IO.File]::Open(($backup+'.lock'),'OpenOrCreate','ReadWrite','None')
 try {Fails {StartupChange $false @(ReadStartup 'Music') $backup};Assert ($script:Items.ContainsKey('Music')) 'Concurrent operation leaves startup unchanged'}finally{$held.Dispose()}

 $blocks=Get-ChildItem "$PSScriptRoot/../PRO-Paste-*.ps1"|Sort-Object Name
 Assert ($blocks.Count -ge 4) 'Independently copyable blocks present'
 $all=''
 foreach($file in $blocks){
  $s=Get-Content -LiteralPath $file.FullName -Raw;$all+=$s
  $tokens=$null;$errors=$null;$null=[Management.Automation.Language.Parser]::ParseInput($s,[ref]$tokens,[ref]$errors)
  Assert ($errors.Count -eq 0 -and $s.Length -lt 8000) 'Each paste block parses independently and is below 8000 characters'
 }
 Assert ($all -ceq (Get-Content "$PSScriptRoot/../PC-Tuner-Pro.ps1" -Raw)) 'Paste blocks exactly reconstruct standalone app'
 "PASS: $script:Checks Pro startup/delivery assertions (simulated registry, real backups)."
} finally {if(Microsoft.PowerShell.Management\Test-Path -LiteralPath $root){Remove-Item -LiteralPath $root -Recurse -Force}}
