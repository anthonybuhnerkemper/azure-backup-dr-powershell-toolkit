#Requires -Version 7.4
#Requires -Modules Az.Accounts, Az.RecoveryServices
<#
.SYNOPSIS
    Starts an on-demand backup of one or more protected VMs, for example before a change.
.DESCRIPTION
    Finds each VM in the given vault and triggers a backup that is kept for -RetainDays.
    Use it before patching, an upgrade or a risky change so you have a fresh restore point.
    Optionally waits for the jobs to finish. Supports -WhatIf / -Confirm.
.PARAMETER VaultName
    Recovery Services vault that protects the VMs.
.PARAMETER VMName
    One or more VM names.
.PARAMETER RetainDays
    How long to keep the on-demand recovery point. Default 30.
.PARAMETER Wait
    Wait for the backup jobs to finish and report the result.
.EXAMPLE
    ./Start-AzOnDemandBackup.ps1 -VaultName rsv-contoso-prod -VMName vm-contoso-app01 -WhatIf
.EXAMPLE
    ./Start-AzOnDemandBackup.ps1 -VaultName rsv-contoso-prod -VMName vm-contoso-app01, vm-contoso-sql01 -RetainDays 14 -Wait
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)][string]$VaultName,
    [Parameter(Mandatory)][string[]]$VMName,
    [ValidateRange(1, 99)][int]$RetainDays = 30,
    [switch]$Wait
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { throw 'Not connected. Run Connect-M365Admin -Service Azure first.' }

$vault = Get-AzRecoveryServicesVault | Where-Object Name -eq $VaultName
if (-not $vault) { throw "Vault $VaultName not found." }
$items = @(Get-AzRecoveryServicesBackupItem -BackupManagementType AzureVM -WorkloadType AzureVM -VaultId $vault.ID)
$expiry = (Get-Date).ToUniversalTime().AddDays($RetainDays)

$jobs = foreach ($name in $VMName) {
    $item = $items | Where-Object { ($_.VirtualMachineId -split '/')[-1] -eq $name } | Select-Object -First 1
    if (-not $item) { Write-Warning "$name is not protected in $VaultName. Skipped."; continue }
    if ($PSCmdlet.ShouldProcess($name, "Start on-demand backup (keep $RetainDays days)")) {
        $job = Backup-AzRecoveryServicesBackupItem -Item $item -ExpiryDateTimeUTC $expiry -VaultId $vault.ID
        Write-Information "$name`: backup job $($job.JobId) started" -InformationAction Continue
        $job
    }
}

if ($Wait -and $jobs) {
    Write-Information 'Waiting for backup jobs. Snapshots are usually quick; the vault transfer can take longer.' -InformationAction Continue
    Wait-AzRecoveryServicesBackupJob -Job $jobs -VaultId $vault.ID -Timeout 14400 | Out-Null
    foreach ($j in $jobs) {
        $now = Get-AzRecoveryServicesBackupJob -JobId $j.JobId -VaultId $vault.ID
        Write-Information "$($now.WorkloadName): $($now.Status)" -InformationAction Continue
    }
}
