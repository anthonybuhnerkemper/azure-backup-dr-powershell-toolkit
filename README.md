# Azure Backup and DR PowerShell Toolkit

A practical toolkit and step-by-step guide for **Azure Backup** and **Azure Site Recovery** with **PowerShell 7** and the **Az.RecoveryServices** module.

It covers vault safety settings (soft delete, redundancy, immutability), backup policy retention, protected VM health, finding VMs with no backup, failed jobs, restore point checks, turning on protection from a CSV, on-demand backups before a change, and Site Recovery replication health. Every script has comment-based help (`Get-Help ./script.ps1 -Full`), reports export to CSV, and every change script supports `-WhatIf` / `-Confirm`. Azure authentication uses **certificates** (app-only) or **interactive** sign-in via the same `Connect-M365Admin` pattern as [graph-powershell7-admin-toolkit](https://github.com/anthonybuhnerkemper/graph-powershell7-admin-toolkit). No secrets are stored in the repo.

> ⚠️ **Disclaimer:** Test everything in a non-production subscription first. Examples use `contoso.com`, vaults like `rsv-contoso-prod`, resource groups like `rg-app-prod`, VMs like `vm-contoso-app01`, and placeholder GUIDs (`00000000-0000-0000-0000-000000000000`). Review each script before running it in your environment.

## Prerequisites

| Requirement | Version / notes |
|---|---|
| PowerShell | 7.4 or later (`pwsh`), Windows, macOS or Linux |
| Az.Accounts | 3.x or later |
| Az.RecoveryServices | 7.x or later |
| Az.Compute | Only for `Get-AzUnprotectedVmReport` |
| Rights | **Backup Reader** for reports; **Backup Operator** for on-demand backups; **Backup Contributor** + **Virtual Machine Contributor** to enable protection; **Site Recovery Reader** for the DR report |

```powershell
Install-Module Az.Accounts, Az.RecoveryServices, Az.Compute -Scope CurrentUser
```

## Quick start

```powershell
git clone https://github.com/anthonybuhnerkemper/azure-backup-dr-powershell-toolkit.git
cd azure-backup-dr-powershell-toolkit

. ./scripts/Connect/Connect-M365Admin.ps1
Connect-M365Admin -Service Azure -Interactive -SubscriptionId 00000000-0000-0000-0000-000000000000

# Reports (CSV files land in ./output)
./scripts/Inventory/Get-AzBackupVaultReport.ps1
./scripts/Coverage/Get-AzBackupProtectedItemReport.ps1
./scripts/Coverage/Get-AzUnprotectedVmReport.ps1
./scripts/Health/Get-AzBackupJobReport.ps1 -Days 3
./scripts/DisasterRecovery/Get-AzSiteRecoveryHealthReport.ps1

# Preview a change before applying it
./scripts/Protection/Enable-AzVmBackupFromCsv.ps1 -Path ./samples/vms-to-protect.sample.csv -WhatIf

. ./scripts/Connect/Disconnect-M365Admin.ps1
Disconnect-M365Admin
```

## Repo map

```text
.github/workflows/pssa.yml  PSScriptAnalyzer CI on push and PR
docs/
  01-prerequisites-and-connect.md
  02-vaults-and-policies.md
  03-coverage-and-gaps.md
  04-jobs-and-restore-points.md
  05-disaster-recovery.md
samples/            vms-to-protect.sample.csv (fake VM names)
scripts/
  Connect/          Connect-M365Admin.ps1, Disconnect-M365Admin.ps1
  Inventory/        Get-AzBackupVaultReport, Get-AzBackupPolicyReport
  Coverage/         Get-AzBackupProtectedItemReport, Get-AzUnprotectedVmReport
  Health/           Get-AzBackupJobReport, Get-AzBackupRecoveryPointReport
  Protection/       Enable-AzVmBackupFromCsv, Start-AzOnDemandBackup
  DisasterRecovery/ Get-AzSiteRecoveryHealthReport
```

## Scripts and permissions

| Script | Needs | Changes? |
|---|---|---|
| Get-AzBackupVaultReport | Backup Reader | No |
| Get-AzBackupPolicyReport | Backup Reader | No |
| Get-AzBackupProtectedItemReport | Backup Reader | No |
| Get-AzUnprotectedVmReport | Backup Reader + Reader on VMs | No |
| Get-AzBackupJobReport | Backup Reader | No |
| Get-AzBackupRecoveryPointReport | Backup Reader | No |
| Enable-AzVmBackupFromCsv | Backup Contributor + Virtual Machine Contributor | Yes (`-WhatIf`) |
| Start-AzOnDemandBackup | Backup Operator | Yes (`-WhatIf`) |
| Get-AzSiteRecoveryHealthReport | Site Recovery Reader | No |

## Related

- [azure-virtual-desktop-powershell-toolkit](https://github.com/anthonybuhnerkemper/azure-virtual-desktop-powershell-toolkit): health checks for the session hosts you back up here
- [graph-powershell7-admin-toolkit](https://github.com/anthonybuhnerkemper/graph-powershell7-admin-toolkit): the shared connect pattern and Microsoft 365 reports
- [defender-xdr-powershell-toolkit](https://github.com/anthonybuhnerkemper/defender-xdr-powershell-toolkit): security checks that pair with immutable backups for ransomware readiness

## License

[MIT](LICENSE) © 2026 Anthony Buhnerkemper
