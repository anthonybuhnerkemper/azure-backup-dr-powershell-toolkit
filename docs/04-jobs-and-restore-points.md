# 04 - Jobs and restore points

## 1. What failed last night?
```powershell
./scripts/Health/Get-AzBackupJobReport.ps1 -Days 3
```
The `Error` column has the message from the job details. Retry after you fix the cause, not before.

## 2. Can we actually restore?
```powershell
./scripts/Health/Get-AzBackupRecoveryPointReport.ps1 -Days 30
```
A backup you have never restored is a hope, not a plan. Use this report to pick a point, then do a real test restore to a separate resource group at least once a quarter. Note the date and how long it took.

`NewestType` should be `AppConsistent` for app and database servers. `CrashConsistent` points usually mean the VM agent or VSS had a problem during the snapshot.

## 3. Before a risky change
```powershell
./scripts/Protection/Start-AzOnDemandBackup.ps1 -VaultName rsv-contoso-prod -VMName vm-contoso-app01 -RetainDays 14 -WhatIf
./scripts/Protection/Start-AzOnDemandBackup.ps1 -VaultName rsv-contoso-prod -VMName vm-contoso-app01 -RetainDays 14 -Wait
```
Take a fresh point before patching, an upgrade or a big config change. It costs little and saves a lot.
