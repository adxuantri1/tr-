$ErrorActionPreference='Stop'
if([Environment]::OSVersion.Platform -ne 'Win32NT'){
 Write-Host 'SKIP: native CMD launcher smoke test requires Windows.'
 exit 0
}
$root=Split-Path -Parent $PSScriptRoot
$temp=Join-Path ([IO.Path]::GetTempPath()) ('PC Tuner kiểm tra '+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $temp
$process=$null
try{
 Copy-Item -LiteralPath (Join-Path $root 'START-PRO.cmd') -Destination (Join-Path $temp 'START-PRO.cmd')
 # A harmless fixture replaces the app: verify invocation, STA and the quoted script path.
 $fixture='[IO.File]::WriteAllText((Join-Path $PSScriptRoot "proof.txt"),([Threading.Thread]::CurrentThread.ApartmentState.ToString()+"|"+$PSVersionTable.PSVersion.Major)); exit 0'
 [IO.File]::WriteAllText((Join-Path $temp 'PC-Tuner-Pro.ps1'),$fixture,[Text.Encoding]::ASCII)
 $start=New-Object Diagnostics.ProcessStartInfo
 $start.FileName=Join-Path $env:SystemRoot 'System32\cmd.exe'
 $start.Arguments='/d /c ""'+(Join-Path $temp 'START-PRO.cmd')+'""'
 $start.WorkingDirectory=[IO.Path]::GetTempPath()
 $start.UseShellExecute=$false;$start.CreateNoWindow=$true
 $start.RedirectStandardInput=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
 $process=[Diagnostics.Process]::Start($start)
 $process.StandardInput.Close()
 if(-not $process.WaitForExit(30000)){$process.Kill();throw 'Launcher did not complete within 30 seconds'}
 $output=$process.StandardOutput.ReadToEnd()+$process.StandardError.ReadToEnd()
 if($process.ExitCode -ne 0){throw ('Native CMD launcher failed: '+$output)}
 $proof=Join-Path $temp 'proof.txt'
 if(-not (Test-Path -LiteralPath $proof)){throw ('Launcher did not execute the fixture: '+$output)}
 if((Get-Content -LiteralPath $proof -Raw) -ne 'STA|5'){throw 'Launcher did not select native Windows PowerShell 5 in STA mode'}
 'PASS: native CMD starts Windows PowerShell in STA mode from a path containing spaces and Vietnamese characters.'
}finally{
 if($null -ne $process){$process.Dispose()}
 Remove-Item -LiteralPath $temp -Recurse -Force
}
