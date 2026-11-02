$ErrorActionPreference='Stop'
. "$PSScriptRoot/../Pro-1-Core.ps1"
. "$PSScriptRoot/../Pro-2-Tools.ps1"
$ast=[Management.Automation.Language.Parser]::ParseFile("$PSScriptRoot/../Pro-3-Window.ps1",[ref]$null,[ref]$null)
foreach($name in @('UpdateDashboard','ShowPage')) { $fn=$ast.Find({param($a) $a -is [Management.Automation.Language.FunctionDefinitionAst] -and $a.Name -eq $name},$false);Invoke-Expression $fn.Extent.Text }
$script:Mode='normal';$script:Checks=0
function Assert($OK,$Text){if(-not $OK){throw $Text};$script:Checks++}
function Get-CimInstance($ClassName,$Filter){
 if($script:Mode -eq 'down'){throw 'Provider unavailable'}
 switch($ClassName){
  'Win32_Processor'{[pscustomobject]@{Name='Test CPU'}}
  'Win32_PerfFormattedData_PerfOS_Processor'{$v=42;if($script:Mode -eq 'zero'){$v=0};if($script:Mode -eq 'invalid'){$v=120};[pscustomobject]@{PercentProcessorTime=$v}}
  'Win32_OperatingSystem'{$free=3MB;if($script:Mode -eq 'zero'){$free=8MB};if($script:Mode -eq 'invalid'){$free=9MB};[pscustomobject]@{TotalVisibleMemorySize=8MB;FreePhysicalMemory=$free}}
  'Win32_VideoController'{[pscustomobject]@{Name='Test GPU';DriverVersion='1.0'}}
  'Win32_LogicalDisk'{$free=30GB;if($script:Mode -eq 'zero'){$free=0};if($script:Mode -eq 'invalid'){$free=110GB};@([pscustomobject]@{DeviceID='Q:';Size=10GB;FreeSpace=1GB},[pscustomobject]@{DeviceID='Z:';Size=100GB;FreeSpace=$free})}
  default{throw 'Unexpected data source'}
 }
}
foreach($name in @('SnapshotTime','CpuValue','CpuDetail','RamValue','RamDetail','GpuValue','GpuDetail','DiskValue','DiskDetail')){Set-Variable -Scope Script -Name $name -Value ([pscustomobject]@{Text=''})}
$data=DashboardData -Drive 'Z:'
Assert ($data.CpuLoad -eq 42 -and $data.CpuName -eq 'Test CPU') 'Snapshot must use provider CPU values'
Assert ($data.TotalRamGB -eq 8 -and $data.UsedRamGB -eq 5) 'RAM units and used memory must be correct'
Assert ($data.DiskName -eq 'Z:' -and $data.FreeDiskGB -eq 30) 'Only the requested system drive should populate the card'
Assert ($data.CapturedAt -is [DateTime] -and $data.GpuName -eq 'Test GPU') 'Snapshot has actual timestamp and GPU metadata'
UpdateDashboard $data
Assert ($script:CpuValue.Text -eq '42%' -and $script:GpuValue.Text -eq 'Test GPU') 'Cards show the collected snapshot'
Assert ($script:SnapshotTime.Text.Contains('Dữ liệu tại thời điểm quét')) 'Snapshot must not be presented as live telemetry'
$script:Mode='zero';$data=DashboardData -Drive 'Z:';UpdateDashboard $data
Assert ($data.CpuLoad -eq 0 -and $script:CpuValue.Text -eq '0%') 'Valid zero CPU is not missing data'
Assert ($data.FreeDiskGB -eq 0 -and $data.UsedRamGB -eq 0) 'Full disk and unused RAM must preserve zero values'
$script:Mode='invalid';$data=DashboardData -Drive 'Z:'
Assert ($null -eq $data.CpuLoad -and $null -eq $data.UsedRamGB -and $null -eq $data.FreeDiskGB) 'Out-of-range metrics must remain unknown'
$script:Mode='down';$data=DashboardData -Drive 'Z:';UpdateDashboard $data
Assert ($null -eq $data.CpuLoad -and $null -eq $data.TotalRamGB -and $null -eq $data.GpuName -and $null -eq $data.FreeDiskGB) 'Provider failure must not manufacture healthy data'
Assert ($script:CpuValue.Text -eq '—' -and $script:GpuValue.Text -eq '—' -and $script:CpuDetail.Text.Contains('Chưa đọc được')) 'Failed refresh clears stale card values'
$script:Pages=@{};$script:PageNames=@{};$script:NavButtons=@()
foreach($key in @('Overview','Profiles','Startup','Diagnostics')){
 $p=[pscustomobject]@{Visible=$false;Raised=$false};$p|Add-Member ScriptMethod BringToFront {$this.Raised=$true};$script:Pages[$key]=$p
 $script:PageNames[$key]=@($key,'Description');$script:NavButtons+=,[pscustomobject]@{Tag=$key;BackColor='';ForeColor='';Enabled=$true}
}
$script:Theme=@{Sidebar='sidebar';Muted='muted';AccentDark='selected';Accent='accent'}
$script:PageTitle=[pscustomobject]@{Text=''};$script:PageSubtitle=[pscustomobject]@{Text=''}
ShowPage 'Profiles'
Assert ($script:Pages.Profiles.Visible -and -not $script:Pages.Overview.Visible -and $script:PageTitle.Text -eq 'Profiles') 'Navigation must switch content and title together'
ShowPage 'Diagnostics'
Assert ($script:Pages.Diagnostics.Visible -and -not $script:Pages.Profiles.Visible -and @($script:Pages.Values|Where-Object Visible).Count -eq 1) 'Navigation must leave exactly one page visible'
"PASS: $script:Checks dashboard/navigation assertions (mock providers and controls; no fake live metrics)."
