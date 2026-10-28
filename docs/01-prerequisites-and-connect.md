# 01 - Prerequisites and connecting

## 1. Install the modules
```powershell
Install-Module Az.Accounts, Az.RecoveryServices, Az.Compute -Scope CurrentUser
```
`Az.Compute` is only needed for `Get-AzUnprotectedVmReport`.

## 2. Pick the right role
- **Backup Reader** on the vaults is enough for every report.
- **Reader** on the subscription lets the coverage report see every VM.
- **Backup Operator** can start on-demand backups.
- **Backup Contributor** plus **Virtual Machine Contributor** can turn on protection for new VMs.
- **Site Recovery Reader** covers the disaster recovery report.

Give the account the smallest role that does the job.

## 3. Connect
```powershell
. ./scripts/Connect/Connect-M365Admin.ps1

# Interactive
Connect-M365Admin -Service Azure -Interactive -SubscriptionId 00000000-0000-0000-0000-000000000000

# App-only with a certificate (for scheduled runs)
$env:M365_TENANT_ID       = '00000000-0000-0000-0000-000000000000'
$env:M365_CLIENT_ID       = '00000000-0000-0000-0000-000000000000'
$env:M365_CERT_THUMBPRINT = '0000000000000000000000000000000000000000'
$env:AZ_SUBSCRIPTION_ID   = '00000000-0000-0000-0000-000000000000'
Connect-M365Admin -Service Azure
```

Never put a secret or a certificate in the repo. The `.gitignore` already blocks `*.pfx`, `*.cer` and `output/`.

When you are done:
```powershell
. ./scripts/Connect/Disconnect-M365Admin.ps1
Disconnect-M365Admin
```
