# PC Tuner Lite: Windows PowerShell 5.1, no downloads, no admin required.
$ErrorActionPreference = 'Stop'
$script:High = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
$script:Targets = @(
    @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize','EnableTransparency'),
    @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced','TaskbarAnimations'),
    @('HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR','AppCaptureEnabled'),
    @('HKCU:\System\GameConfigStore','GameDVR_Enabled')
)
function UserID { [Security.Principal.WindowsIdentity]::GetCurrent().User.Value }
function Power($Verb,$Guid) {
    $r = if ($Guid) { & powercfg.exe $Verb $Guid 2>&1 } else { & powercfg.exe $Verb 2>&1 }
    if ($LASTEXITCODE -ne 0) { throw "powercfg failed: $r" }; return ($r -join "`n")
}
function Active {
    $r = Power '/getactivescheme'; if ($r -notmatch '[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}') { throw 'Cannot read power plan.' }; $Matches[0]
}
function Plan($Guid) { $null = Power '/setactive' $Guid; if ((Active) -ne $Guid) { throw 'Power plan not applied.' } }
function ReadValue($Path,$Name) {
    $exists=$false; $value=$null
    if (Test-Path -LiteralPath $Path) {
        $k=Get-Item -LiteralPath $Path
        try { $exists=$k.GetValueNames() -contains $Name; if ($exists) { if ($k.GetValueKind($Name).ToString() -ne 'DWord') { throw 'Unexpected registry type.' }; $value=$k.GetValue($Name) } } finally { $k.Close() }
    }
    [pscustomobject]@{Path=$Path; Name=$Name; Exists=$exists; Value=$value}
}
function WriteValue($S,$Undo) {
    if ($Undo -and -not $S.Exists) {
        if ((ReadValue $S.Path $S.Name).Exists) { Remove-ItemProperty -LiteralPath $S.Path -Name $S.Name }
    } else {
        if (-not (Test-Path -LiteralPath $S.Path)) { $null=New-Item -Path $S.Path }
        $v=0; if ($Undo) { $v=$S.Value }
        $null=New-ItemProperty -LiteralPath $S.Path -Name $S.Name -PropertyType DWord -Value $v -Force
    }
    $a=ReadValue $S.Path $S.Name
    if ($Undo -and -not $S.Exists) { if ($a.Exists) { throw 'Restore verification failed.' } }
    elseif (-not $a.Exists -or $a.Value -ne $v) { throw 'Setting verification failed.' }
}
function Tune($Mode,$Backup) {
    if (@(Get-Process -Name 'VALORANT','VALORANT-Win64-Shipping' -ErrorAction SilentlyContinue).Count) { throw 'Close Valorant first; close other games too.' }
    $null=New-Item -ItemType Directory -Path (Split-Path -Parent $Backup) -Force
    $lock=[IO.File]::Open(($Backup+'.lock'),'OpenOrCreate','ReadWrite','None')
    try {
        if ($Mode -eq 'Restore') {
            if (-not (Test-Path -LiteralPath $Backup)) { throw 'No backup found.' }
            $s=Get-Content -LiteralPath $Backup -Raw | ConvertFrom-Json
            if ($s.Version -notin @(1,2) -or $s.User -ne (UserID)) { throw 'Backup user/version mismatch.' }
            $expected=@($script:Targets)
            if ($s.Version -eq 1) { $expected=@($script:Targets[2],$script:Targets[3]) }
            elseif ($s.Profile -eq 'Daily') { $expected=@($script:Targets[0],$script:Targets[1]) }
            elseif ($s.Profile -eq 'Gaming') { $expected=@($script:Targets[2],$script:Targets[3],$script:Targets[0],$script:Targets[1]) }
            else { throw 'Invalid backup profile.' }
            if ($s.ChangePower -isnot [bool] -or $s.PowerPlan -notmatch '^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$' -or @($s.Settings).Count -ne $expected.Count) { throw 'Invalid backup.' }
            if ($s.Version -eq 2 -and $s.Profile -eq 'Daily' -and $s.ChangePower) { throw 'Invalid Daily backup.' }
            for ($i=0; $i -lt $expected.Count; $i++) {
                $v=$s.Settings[$i]
                if ($v.Path -ne $expected[$i][0] -or $v.Name -ne $expected[$i][1] -or $v.Exists -isnot [bool]) { throw 'Unexpected backup target.' }
                if ($v.Exists -and ($null -eq $v.Value -or $v.Value -isnot [ValueType] -or $v.Value -lt [int]::MinValue -or $v.Value -gt [uint32]::MaxValue -or [math]::Truncate([double]$v.Value) -ne $v.Value)) { throw 'Invalid backup value.' }
            }
            foreach ($v in $s.Settings) { WriteValue $v $true }; if ($s.ChangePower) { Plan $s.PowerPlan }
            Move-Item -LiteralPath $Backup -Destination ($Backup+'.restored-'+[guid]::NewGuid().ToString('N'))
            return 'Restored. Sign out and sign in to Windows.'
        }
        if ($Mode -notin @('Daily','Gaming')) { throw 'Unknown profile.' }
        if (Test-Path -LiteralPath $Backup) { throw 'Backup exists. Restore before applying another profile.' }
        $chosen=@($script:Targets[0],$script:Targets[1]); $change=$false
        if ($Mode -eq 'Gaming') { $chosen=@($script:Targets[2],$script:Targets[3],$script:Targets[0],$script:Targets[1]); $change=(Power '/list') -match $script:High }
        $s=[pscustomobject]@{Version=2; Profile=$Mode; User=(UserID); PowerPlan=(Active); ChangePower=[bool]$change; Settings=@($chosen | ForEach-Object { ReadValue $_[0] $_[1] })}
        $s | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $Backup -Encoding UTF8
        $null=Get-Content -LiteralPath $Backup -Raw | ConvertFrom-Json
        if ($change) { Plan $script:High }; foreach ($v in $s.Settings) { WriteValue $v $false }
        return 'Applied. Sign out and sign in to Windows. Keep the backup to restore.'
    } finally { $lock.Dispose() }
}
