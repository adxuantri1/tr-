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
    if ($LASTEXITCODE -ne 0) { throw "Không thực hiện được lệnh nguồn điện: $r" }; return ($r -join "`n")
}
function Active {
    $r = Power '/getactivescheme'; if ($r -notmatch '[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}') { throw 'Không đọc được chế độ nguồn điện.' }; $Matches[0]
}
function Plan($Guid) { $null = Power '/setactive' $Guid; if ((Active) -ne $Guid) { throw 'Chưa áp dụng được chế độ nguồn điện.' } }
function ReadValue($Path,$Name) {
    $exists=$false; $value=$null
    if (Test-Path -LiteralPath $Path) {
        $k=Get-Item -LiteralPath $Path
        try { $exists=$k.GetValueNames() -contains $Name; if ($exists) { if ($k.GetValueKind($Name).ToString() -ne 'DWord') { throw 'Kiểu dữ liệu thiết lập không được hỗ trợ.' }; $value=$k.GetValue($Name) } } finally { $k.Close() }
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
    if ($Undo -and -not $S.Exists) { if ($a.Exists) { throw 'Không xác minh được kết quả hoàn tác.' } }
    elseif (-not $a.Exists -or $a.Value -ne $v) { throw 'Không xác minh được thiết lập vừa thay đổi.' }
}
function Tune($Mode,$Backup) {
    if (@(Get-Process -Name 'VALORANT','VALORANT-Win64-Shipping' -ErrorAction SilentlyContinue).Count) { throw 'Hãy đóng Valorant và các game khác trước khi tiếp tục.' }
    $null=New-Item -ItemType Directory -Path (Split-Path -Parent $Backup) -Force
    $lock=[IO.File]::Open(($Backup+'.lock'),'OpenOrCreate','ReadWrite','None')
    try {
        if ($Mode -eq 'Restore') {
            if (-not (Test-Path -LiteralPath $Backup)) { throw 'Chưa có bản sao lưu thiết lập để hoàn tác.' }
            $s=Get-Content -LiteralPath $Backup -Raw | ConvertFrom-Json
            if ($s.Version -notin @(1,2) -or $s.User -ne (UserID)) { throw 'Bản sao lưu thuộc tài khoản khác hoặc phiên bản không được hỗ trợ.' }
            $expected=@($script:Targets)
            if ($s.Version -eq 1) { $expected=@($script:Targets[2],$script:Targets[3]) }
            elseif ($s.Profile -eq 'Daily') { $expected=@($script:Targets[0],$script:Targets[1]) }
            elseif ($s.Profile -eq 'Gaming') { $expected=@($script:Targets[2],$script:Targets[3],$script:Targets[0],$script:Targets[1]) }
            else { throw 'Chế độ trong bản sao lưu không hợp lệ.' }
            if ($s.ChangePower -isnot [bool] -or $s.PowerPlan -notmatch '^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$' -or @($s.Settings).Count -ne $expected.Count) { throw 'Bản sao lưu không hợp lệ.' }
            if ($s.Version -eq 2 -and $s.Profile -eq 'Daily' -and $s.ChangePower) { throw 'Bản sao lưu chế độ hằng ngày không hợp lệ.' }
            for ($i=0; $i -lt $expected.Count; $i++) {
                $v=$s.Settings[$i]
                if ($v.Path -ne $expected[$i][0] -or $v.Name -ne $expected[$i][1] -or $v.Exists -isnot [bool]) { throw 'Bản sao lưu chứa thiết lập không được phép thay đổi.' }
                if ($v.Exists -and ($null -eq $v.Value -or $v.Value -isnot [ValueType] -or $v.Value -lt [int]::MinValue -or $v.Value -gt [uint32]::MaxValue -or [math]::Truncate([double]$v.Value) -ne $v.Value)) { throw 'Giá trị trong bản sao lưu không hợp lệ.' }
            }
            foreach ($v in $s.Settings) { WriteValue $v $true }; if ($s.ChangePower) { Plan $s.PowerPlan }
            Move-Item -LiteralPath $Backup -Destination ($Backup+'.restored-'+[guid]::NewGuid().ToString('N'))
            return 'Đã hoàn tác. Hãy đăng xuất rồi đăng nhập lại Windows.'
        }
        if ($Mode -notin @('Daily','Gaming')) { throw 'Chế độ không được hỗ trợ.' }
        if (Test-Path -LiteralPath $Backup) { throw 'Đã có bản sao lưu. Hãy hoàn tác trước khi áp dụng chế độ khác.' }
        $chosen=@($script:Targets[0],$script:Targets[1]); $change=$false
        if ($Mode -eq 'Gaming') { $chosen=@($script:Targets[2],$script:Targets[3],$script:Targets[0],$script:Targets[1]); $change=(Power '/list') -match $script:High }
        $s=[pscustomobject]@{Version=2; Profile=$Mode; User=(UserID); PowerPlan=(Active); ChangePower=[bool]$change; Settings=@($chosen | ForEach-Object { ReadValue $_[0] $_[1] })}
        $s | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $Backup -Encoding UTF8
        $null=Get-Content -LiteralPath $Backup -Raw | ConvertFrom-Json
        if ($change) { Plan $script:High }; foreach ($v in $s.Settings) { WriteValue $v $false }
        return 'Đã áp dụng. Hãy đăng xuất rồi đăng nhập lại Windows. Giữ bản sao lưu để hoàn tác.'
    } finally { $lock.Dispose() }
}
