$ErrorActionPreference='Stop'
. "$PSScriptRoot/../Pro-1-Core.ps1"
. "$PSScriptRoot/../Pro-2-Tools.ps1"
$ast=[Management.Automation.Language.Parser]::ParseFile("$PSScriptRoot/../Pro-3-Window.ps1",[ref]$null,[ref]$null)
$fn=$ast.Find({param($a) $a -is [Management.Automation.Language.FunctionDefinitionAst] -and $a.Name -eq 'StartReport'},$false)
Invoke-Expression $fn.Extent.Text
$script:Job=$null
$script:Output=[pscustomobject]@{Text=''}
$script:Buttons=@([pscustomobject]@{Enabled=$true})
$script:Timer=[pscustomobject]@{Started=$false}
$script:Timer|Add-Member ScriptMethod Start {$this.Started=$true}
try {
 StartReport 'HealthReport'
 if($null -eq $script:Job -or $script:Buttons[0].Enabled -or -not $script:Timer.Started){throw 'Report did not enter busy state correctly'}
 $null=Wait-Job $script:Job -Timeout 20
 $result=Receive-Job $script:Job -ErrorAction Stop|Out-String
 if($script:Job.State -ne 'Completed' -or $result -notmatch 'ỨNG DỤNG DÙNG NHIỀU CPU' -or $result -notmatch 'ỨNG DỤNG DÙNG NHIỀU RAM'){throw 'Report did not return the intended process statistics'}
 'PASS: actual StartReport controller launched and completed its real background report (mock UI controls, live local process counters).'
} finally {
 if($null -ne $script:Job){if($script:Job.State -eq 'Running'){Stop-Job $script:Job};Remove-Job $script:Job -Force}
}
