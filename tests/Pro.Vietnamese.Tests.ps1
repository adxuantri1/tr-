$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'Pro-3-Window.ps1'),[ref]$null,[ref]$null)
$assignment=$ast.Find({param($a) $a -is [Management.Automation.Language.AssignmentStatementAst] -and $a.Left.Extent.Text -eq '$labels'},$true)
Invoke-Expression $assignment.Extent.Text
$expected=@{Scan='Kiểm tra máy'; 'CPU/RAM 20s'='Đo CPU/RAM (20 giây)'; Network='Kiểm tra mạng'; Daily='Dùng hằng ngày'; Gaming='Chơi game'; 'Undo settings'='Hoàn tác thiết lập'; 'Startup apps'='Ứng dụng khởi động'; 'Undo startup'='Hoàn tác khởi động'; 'Save report'='Lưu báo cáo'; 'Keep app'='Lưu ứng dụng'}
if($labels.Count -ne 10){throw 'Missing localized action label'}
foreach($key in $expected.Keys){if($labels[$key] -cne $expected[$key]){throw "Incorrect Vietnamese label: $key"}}
$addClick=$ast.Find({param($a) $a -is [Management.Automation.Language.InvokeMemberExpressionAst] -and $a.Member.Value -eq 'Add_Click' -and $a.Arguments[0].Extent.Text.Contains('Invoke-ProAction $this.Tag')},$true)
if($null -eq $addClick){throw 'Action dispatch must use stable tags rather than translated labels'}
$handler=$addClick.Arguments[0].ScriptBlock.GetScriptBlock()
$router=$ast.Find({param($a) $a -is [Management.Automation.Language.FunctionDefinitionAst] -and $a.Name -eq 'Invoke-ProAction'},$false)
Invoke-Expression $router.Extent.Text
function ShowUiResult($Text,$ErrorState){$script:Output.Text=$Text}
function SetUiStatus($Text,$Busy){}
function UpdateBackupState{}
$script:Output=[pscustomobject]@{Text=''}
$script:Backup='test-settings-backup'
$script:StartupFile='test-startup-backup'
function ConfirmAction($Text){$script:Confirmation=$Text;return $true}
function Tune($Mode,$Backup){$script:Last='Tune:'+ $Mode;return 'Đã áp dụng thử nghiệm'}
function StartReport($Task){$script:Last='Report:'+ $Task}
function StartupWindow{$script:Last='StartupWindow'}
function StartupChange($Undo,$Entries,$File){$script:Last='StartupUndo:'+ $Undo;return 'Đã hoàn tác thử nghiệm'}
function InstallPro{$script:Last='InstallPro';return 'Đã lưu ứng dụng thử nghiệm'}
$routes=@{Daily='Tune:Daily';Gaming='Tune:Gaming';'Undo settings'='Tune:Restore';Scan='Report:HealthReport';'CPU/RAM 20s'='Report:LoadReport';Network='Report:NetworkReport';'Startup apps'='StartupWindow';'Undo startup'='StartupUndo:True';'Keep app'='InstallPro'}
foreach($key in $routes.Keys){
 $button=[pscustomobject]@{Text=$labels[$key];Tag=$key}
 $button|Add-Member ScriptMethod Press $handler
 $script:Last=''
 $button.Press()
 if($script:Last -cne $routes[$key]){throw "Localized button called the wrong action: $key"}
}
$files=@('Pro-1-Core.ps1','Pro-2-Tools.ps1','Pro-3-Window.ps1','PC-Tuner-Pro.ps1')+@(Get-ChildItem (Join-Path $root 'PRO-Paste-*.ps1')|ForEach-Object {$_.Name})
foreach($name in $files){
 $bytes=[IO.File]::ReadAllBytes((Join-Path $root $name))
 if($bytes[0] -ne 239 -or $bytes[1] -ne 187 -or $bytes[2] -ne 191){throw "Missing UTF-8 BOM for Windows PowerShell 5.1: $name"}
}
$confirm=$ast.Find({param($a) $a -is [Management.Automation.Language.FunctionDefinitionAst] -and $a.Name -eq 'ConfirmAction'},$false)
if(-not $confirm.Extent.Text.Contains("`$yes.Text='Đồng ý'") -or -not $confirm.Extent.Text.Contains("`$cancel.Text='Hủy'") -or -not $confirm.Extent.Text.Contains('$dialog.AcceptButton=$cancel')){throw 'Confirmation must be localized and default to cancellation'}
'PASS: all 10 Vietnamese labels, nine executable button routes, UTF-8 BOM and localized confirmation defaults verified (mock controls, no Windows changes).'
