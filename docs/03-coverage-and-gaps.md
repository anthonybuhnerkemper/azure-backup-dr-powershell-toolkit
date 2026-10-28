# 03 - Coverage and gaps

## 1. Which VMs are backed up, and when did it last work?
```powershell
./scripts/Coverage/Get-AzBackupProtectedItemReport.ps1 -StaleHours 26
```
`HoursSinceBackup` sorted high to low shows the worst first. Common causes:
- **VM is deallocated.** Azure Backup still runs, but check the VM is meant to be off.
- **VM agent is not running or out of date.** Fix the agent, then retry the backup.
- **Protection stopped.** Someone stopped protection and kept the data. Decide if that VM should be protected again.

## 2. Which VMs are not backed up at all?
```powershell
./scripts/Coverage/Get-AzUnprotectedVmReport.ps1
```
Every VM should end up in one of two places: protected, or tagged `Backup = Exempt` with a reason. Test and build VMs are good candidates for the tag.

## 3. Close the gaps
Copy `samples/vms-to-protect.sample.csv`, fill it with the VMs from the gap report, then:
```powershell
./scripts/Protection/Enable-AzVmBackupFromCsv.ps1 -Path ./vms.csv -WhatIf
./scripts/Protection/Enable-AzVmBackupFromCsv.ps1 -Path ./vms.csv
```
The script skips VMs that are already protected, so it is safe to run again.
