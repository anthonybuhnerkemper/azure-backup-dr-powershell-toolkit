# 02 - Vaults and policies

## 1. Are the vaults safe?
```powershell
./scripts/Inventory/Get-AzBackupVaultReport.ps1
```
Look at the `Issues` column:
- **Soft delete off.** A deleted backup is gone at once. Turn soft delete on. It is your best defense against ransomware and mistakes.
- **LRS only.** Locally redundant storage keeps copies in one datacenter. For production, use geo redundant storage and consider cross region restore. You can only change this before the first item is protected.
- **No immutability.** Immutable vaults stop anyone from shortening retention or deleting points early. Start with `Unlocked` while you test, then lock it.

## 2. Do the policies match what you promised?
```powershell
./scripts/Inventory/Get-AzBackupPolicyReport.ps1 -MinimumDailyRetentionDays 30
```
Compare the retention columns with your written backup standard. Two things to watch:
- Policies with **no VMs** are clutter. Remove them or document why they exist.
- Run times are in **UTC**. Make sure backups do not land in the middle of your business day.
