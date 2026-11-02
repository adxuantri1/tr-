function StartupWindow {
    $entries=@(StartupEntries)
    if (-not $entries.Count) { throw 'No eligible current-user Run entries found.' }
    $d=New-Object Windows.Forms.Form; $d.Text='Startup apps - current user only'; $d.Width=800; $d.Height=420; $d.StartPosition='CenterScreen'
    $label=New-Object Windows.Forms.Label; $label.SetBounds(15,10,750,55)
    $label.Text='Select ONLY apps you recognize and do not need at sign-in. Drivers/security/Riot names are hidden. Running apps are NOT closed. Startup folder, services and scheduled tasks are not edited.'
    $d.Controls.Add($label)
    $list=New-Object Windows.Forms.CheckedListBox; $list.SetBounds(15,70,750,240); $list.HorizontalScrollbar=$true
    foreach ($entry in $entries) { [void]$list.Items.Add($entry.Name+' | '+$entry.Value) }; $d.Controls.Add($list)
    $apply=New-Object Windows.Forms.Button; $apply.Text='Back up and disable selected'; $apply.SetBounds(15,320,300,40); $apply.DialogResult='OK'; $d.Controls.Add($apply)
    try {
        if ($d.ShowDialog() -eq 'OK') {
            $selected=@($list.CheckedIndices | ForEach-Object { $entries[[int]$_] })
            if (-not $selected.Count) { return }
            if ([Windows.Forms.MessageBox]::Show("Disable $($selected.Count) selected startup app(s) after backup?",'Confirm','YesNo','Question','Button2') -eq 'Yes') { $script:Output.Text=StartupChange $false $selected $script:StartupFile }
        }
    } finally { $d.Dispose() }
}
function StartReport($Task) {
    if ($null -ne $script:Job) { return }
    $defs=@('Power','Active','AppReport','HealthReport','LoadReport','NetworkReport') | ForEach-Object { 'function '+$_+' {'+(Get-Command $_).Definition+'}' }
    $lib='$ErrorActionPreference="Stop";'+($defs -join "`n")
    $script:Output.Text='Working... Sampling has a small CPU cost. Close this tool for normal play.'
    foreach ($b in $script:Buttons) { $b.Enabled=$false }
    try {
        $script:Job=Start-Job -ArgumentList $lib,$Task -ScriptBlock {
            param($Lib,$Task)
            . ([scriptblock]::Create($Lib))
            if ($Task -notin @('HealthReport','LoadReport','NetworkReport')) { throw 'Unknown report.' }; & $Task
        }
        $script:Timer.Start()
    } catch { foreach ($b in $script:Buttons) { $b.Enabled=$true }; throw }
}
function Start-Pro {
    if ([Environment]::OSVersion.Platform -ne 'Win32NT') { throw 'Windows only.' }
    Add-Type -AssemblyName System.Windows.Forms
    $root=Join-Path $env:LOCALAPPDATA 'PCTuner'; $script:Backup=Join-Path $root 'backup.json'; $script:StartupFile=Join-Path $root 'startup-backup.json'
    $old=Join-Path $env:LOCALAPPDATA 'ValorantPCToolkit\backup.json'; if (Test-Path -LiteralPath $old) { $script:Backup=$old }
    $script:Job=$null; $script:Buttons=@()
    $script:Form=New-Object Windows.Forms.Form; $script:Form.Text='PC Tuner Pro'; $script:Form.Width=960; $script:Form.Height=700; $script:Form.StartPosition='CenterScreen'; $script:Form.MinimumSize=[Drawing.Size]::new(800,550)
    $layout=New-Object Windows.Forms.TableLayoutPanel; $layout.Dock='Fill'; $layout.RowCount=2; $layout.ColumnCount=1
    [void]$layout.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute',110)); [void]$layout.RowStyles.Add([Windows.Forms.RowStyle]::new('Percent',100)); $script:Form.Controls.Add($layout)
    $top=New-Object Windows.Forms.FlowLayoutPanel; $top.Dock='Fill'; $top.AutoScroll=$true; $layout.Controls.Add($top,0,0)
    $script:Output=New-Object Windows.Forms.RichTextBox; $script:Output.Dock='Fill'; $script:Output.ReadOnly=$true; $script:Output.Font=New-Object Drawing.Font('Consolas',10)
    $script:Output.Text="PC TUNER PRO - no promised FPS boost`r`n`r`nScan: hardware, CPU/RAM apps and disk space.`r`nCPU/RAM 20s: sample while reproducing a stutter, then close this tool.`r`nNetwork: gateway + Cloudflare ICMP, NOT your game server.`r`nDaily: reduce desktop transparency/animations.`r`nGaming: also disable Game DVR + existing High performance (more heat/power).`r`nUndo settings: restore the original snapshot.`r`nStartup: select known apps, back up and disable their next-login launch.`r`nUndo startup: restore that selection; stops on conflicting changes.`r`n`r`nClose games before tuning. Sign out/in after applying/undoing settings.`r`nBackups: $root`r`nKeep app: save a reusable app folder to Desktop.`r`nReports stay local unless you share them."
    $layout.Controls.Add($script:Output,0,1)
    foreach ($name in @('Scan','CPU/RAM 20s','Network','Daily','Gaming','Undo settings','Startup apps','Undo startup','Save report','Keep app')) {
        $b=New-Object Windows.Forms.Button; $b.Text=$name; $b.Width=170; $b.Height=40; $script:Buttons+=,$b
        $b.Add_Click({
            try {
                switch ($this.Text) {
                    'Scan' { StartReport 'HealthReport' }
                    'CPU/RAM 20s' { StartReport 'LoadReport' }
                    'Network' { StartReport 'NetworkReport' }
                    'Startup apps' { StartupWindow }
                    'Undo startup' {
                        if ([Windows.Forms.MessageBox]::Show('Restore saved startup entries? Conflicting newer entries will not be overwritten.','Confirm','YesNo','Question','Button2') -eq 'Yes') { $script:Output.Text=StartupChange $true @() $script:StartupFile }
                    }
                    'Keep app' { $script:Output.Text=InstallPro }
                    'Save report' {
                        $save=New-Object Windows.Forms.SaveFileDialog; $save.Filter='Text (*.txt)|*.txt'; $save.FileName='PC-report.txt'
                        try { if ($save.ShowDialog() -eq 'OK') { [IO.File]::WriteAllText($save.FileName,$script:Output.Text,[Text.UTF8Encoding]::new($true)) } } finally { $save.Dispose() }
                    }
                    default {
                        $mode=$this.Text; if ($mode -eq 'Undo settings') { $mode='Restore' }
                        $text="Run $mode? Close games first. Daily reduces desktop effects. Gaming also disables Game DVR and selects existing High performance (more heat/power). Restore uses the original backup."
                        if ([Windows.Forms.MessageBox]::Show($text,'Confirm','YesNo','Question','Button2') -eq 'Yes') { $script:Output.Text=Tune $mode $script:Backup }
                    }
                }
            } catch { [void][Windows.Forms.MessageBox]::Show($_.Exception.Message+"`r`nKeep backups. Use the matching Undo button if an operation was partial.",'PC Tuner') }
        }); $top.Controls.Add($b)
    }
    $script:Timer=New-Object Windows.Forms.Timer; $script:Timer.Interval=300
    $script:Timer.Add_Tick({
        if ($null -eq $script:Job -or $script:Job.State -in @('Running','NotStarted')) { return }
        $script:Timer.Stop()
        try {
            $result=Receive-Job $script:Job -ErrorAction Stop | Out-String -Width 150
            if ($script:Job.State -ne 'Completed') { throw 'Report did not complete.' }; $script:Output.Text=$result
        } catch { $script:Output.Text='Report incomplete: '+$_.Exception.Message }
        finally { Remove-Job $script:Job -Force; $script:Job=$null; foreach ($b in $script:Buttons) { $b.Enabled=$true } }
    })
    $script:Form.Add_FormClosing({ param($s,$e) if ($null -ne $script:Job) { $e.Cancel=$true; [void][Windows.Forms.MessageBox]::Show('Wait for the report to finish, then close. No permanent monitoring is installed.') } })
    try { [void]$script:Form.ShowDialog() } finally { $script:Timer.Dispose(); $script:Form.Dispose() }
}
Start-Pro
