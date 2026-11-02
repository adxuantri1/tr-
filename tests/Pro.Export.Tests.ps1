$ErrorActionPreference='Stop'
. "$PSScriptRoot/../Pro-1-Core.ps1"
. "$PSScriptRoot/../Pro-2-Tools.ps1"
$ast=[Management.Automation.Language.Parser]::ParseFile("$PSScriptRoot/../Pro-3-Window.ps1",[ref]$null,[ref]$null)
foreach($fn in $ast.FindAll({param($a) $a -is [Management.Automation.Language.FunctionDefinitionAst]},$false)){ Invoke-Expression $fn.Extent.Text }
$code=ExportProText
$tokens=$null;$errors=$null;$export=[Management.Automation.Language.Parser]::ParseInput($code,[ref]$tokens,[ref]$errors)
if($errors.Count){throw $errors[0]}
$definitions=@($export.FindAll({param($a) $a -is [Management.Automation.Language.FunctionDefinitionAst]},$false))
if($definitions.Count -ne 39){throw 'Export missing application functions'}
# Load only the preamble, not the final Windows UI invocation, then verify config serialization.
$preamble=$code.Substring(0,$code.IndexOf('function UserID'))
Invoke-Expression $preamble
if($script:Targets.Count -ne 4 -or $script:Targets[0][1] -ne 'EnableTransparency' -or $script:Targets[3][1] -ne 'GameDVR_Enabled'){throw 'Target serialization changed'}
if($code -notmatch 'Start-Pro\s*$' -or $code -match '\$PSScriptRoot'){throw 'Export is not standalone'}
$temp=Join-Path ([IO.Path]::GetTempPath()) ('pro-install-test-'+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $temp
try {
 $message=InstallPro $temp
 $saved=@(Get-ChildItem -LiteralPath $temp -Directory)
 if($saved.Count -ne 1){throw 'Installer did not create one isolated app folder'}
 $ps1=Join-Path $saved[0].FullName 'PC-Tuner-Pro.ps1'
 $cmd=Join-Path $saved[0].FullName 'START.cmd'
 if((Get-Content -LiteralPath $ps1 -Raw) -cne $code){throw 'Saved app differs from verified export'}
 $bytes=[IO.File]::ReadAllBytes($ps1)
 if($bytes[0] -ne 239 -or $bytes[1] -ne 187 -or $bytes[2] -ne 191){throw 'Saved Windows script needs UTF-8 BOM'}
 $launcher=Get-Content -LiteralPath $cmd -Raw
 $expectedLauncher=ProLauncherText
 foreach($file in @($cmd,(Join-Path (Split-Path -Parent $PSScriptRoot) 'START-PRO.cmd'))){
  $raw=[IO.File]::ReadAllBytes($file)
  if(@($raw|Where-Object {$_ -gt 127}).Count){throw "Batch launcher must be ASCII without BOM: $file"}
  $text=[Text.Encoding]::ASCII.GetString($raw)
  if($text -cne $expectedLauncher -or $text -match '(?<!\r)\n' -or $text -match '\r(?!\n)'){throw "Root and installed launchers must use identical CRLF Windows batch content: $file"}
  if(-not $text.Contains('"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"') -or $text.Contains('chcp')){throw 'Launcher must use native PowerShell without changing the code page'}
 }
 if(-not $launcher.Contains('%~dp0PC-Tuner-Pro.ps1') -or -not $launcher.Contains('-STA') -or -not $launcher.StartsWith('@echo off')){throw 'Invalid standalone Windows launcher'}
 'PASS: Keep app writes the verified standalone script and launcher; all 39 functions, four targets and UTF-8 BOM preserved.'
} finally {Remove-Item -LiteralPath $temp -Recurse -Force}
