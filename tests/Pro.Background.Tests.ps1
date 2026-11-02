$ErrorActionPreference='Stop'
. "$PSScriptRoot/../Pro-1-Core.ps1"
. "$PSScriptRoot/../Pro-2-Tools.ps1"
$ast=[Management.Automation.Language.Parser]::ParseFile("$PSScriptRoot/../Pro-3-Window.ps1",[ref]$null,[ref]$null)
foreach($name in @('StartReport','SetUiStatus','ShowUiResult','UpdateDashboard')){
 $fn=$ast.Find({param($a) $a -is [Management.Automation.Language.FunctionDefinitionAst] -and $a.Name -eq $name},$false)
 Invoke-Expression $fn.Extent.Text
}
$script:Theme=@{Muted='muted';Blue='blue';Text='text';Danger='danger'}
$script:StatusText=[pscustomobject]@{Text='';ForeColor=''}
$script:Progress=[pscustomobject]@{Style='Blocks';Value=0}
foreach($name in @('SnapshotTime','CpuValue','CpuDetail','RamValue','RamDetail','GpuValue','GpuDetail','DiskValue','DiskDetail')){Set-Variable -Scope Script -Name $name -Value ([pscustomobject]@{Text=''})}
function UpdateBackupState {}
$script:Job=$null
$script:Output=[pscustomobject]@{Text='';ForeColor=''}
$script:Buttons=@([pscustomobject]@{Enabled=$true})
$script:Timer=[pscustomobject]@{Started=$false}
$script:Timer|Add-Member ScriptMethod Start {$this.Started=$true}
$script:Timer|Add-Member ScriptMethod Stop {$this.Started=$false}
try {
 StartReport 'HealthReport'
 if($null -eq $script:Job -or $script:Buttons[0].Enabled -or -not $script:Timer.Started){throw 'Report did not enter busy state correctly'}
 $null=Wait-Job $script:Job -Timeout 20
 $tick=$ast.Find({param($a) $a -is [Management.Automation.Language.InvokeMemberExpressionAst] -and $a.Member.Value -eq 'Add_Tick'},$true)
 & $tick.Arguments[0].ScriptBlock.GetScriptBlock()
 if($null -ne $script:Job -or -not $script:Buttons[0].Enabled -or $script:Timer.Started){throw 'Report completion did not clean up its job and busy state'}
 if($script:Output.Text -notmatch 'ỨNG DỤNG DÙNG NHIỀU CPU' -or $script:Output.Text -notmatch 'ỨNG DỤNG DÙNG NHIỀU RAM'){throw 'Report did not return the intended process statistics'}
 if(-not $script:SnapshotTime.Text.StartsWith('Lần kiểm tra:')){throw 'Serialized snapshot did not update dashboard timestamp'}
 'PASS: actual report controller, background job and completion handler updated results/dashboard and restored busy controls (mock UI, live process counters).'

} finally {
 if($null -ne $script:Job){if($script:Job.State -eq 'Running'){Stop-Job $script:Job};Remove-Job $script:Job -Force}
}
