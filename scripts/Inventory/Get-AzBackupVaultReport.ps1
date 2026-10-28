#Requires -Version 7.4
#Requires -Modules Az.Accounts, Az.RecoveryServices
<#
.SYNOPSIS
    Reports every Recovery Services vault in the subscription and its safety settings.
.DESCRIPTION
    Read-only. For each vault shows location, storage redundancy, cross region restore,
    soft delete state, immutability state and the number of protected Azure VMs.
    Flags vaults with soft delete off, locally redundant storage or no immutability. Exports CSV.
.PARAMETER ResourceGroupName
    Optional. Only check vaults in this resource group.
.PARAMETER OutputFolder
    Folder for CSV output. Defaults to ./output.
.EXAMPLE
    ./Get-AzBackupVaultReport.ps1
.EXAMPLE
    ./Get-AzBackupVaultReport.ps1 -ResourceGroupName rg-backup-prod
#>
[CmdletBinding()]
param(
    [string]$ResourceGroupName,
    [string]$OutputFolder = (Join-Path (Get-Location) 'output')
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { throw 'Not connected. Run Connect-M365Admin -Service Azure first.' }
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

$vaultParams = @{}
if ($ResourceGroupName) { $vaultParams.ResourceGroupName = $ResourceGroupName }
$vaults = @(Get-AzRecoveryServicesVault @vaultParams)

$rows = foreach ($v in $vaults) {
    $backupProps = Get-AzRecoveryServicesBackupProperty -Vault $v
    $vaultProps = Get-AzRecoveryServicesVaultProperty -VaultId $v.ID
    $immutability = $v.Properties.ImmutabilitySettings.ImmutabilityState ?? 'NotSet'
    $vmItems = @(Get-AzRecoveryServicesBackupItem -BackupManagementType AzureVM -WorkloadType AzureVM -VaultId $v.ID)

    $issues = @()
    if ($vaultProps.SoftDeleteFeatureState -notin 'Enabled', 'AlwaysON') { $issues += 'Soft delete off' }
    if ($backupProps.BackupStorageRedundancy -eq 'LocallyRedundant') { $issues += 'LRS only' }
    if ($immutability -notin 'Unlocked', 'Locked') { $issues += 'No immutability' }

    [pscustomobject]@{
        Vault              = $v.Name
        ResourceGroup      = $v.ResourceGroupName
        Location           = $v.Location
        StorageRedundancy  = $backupProps.BackupStorageRedundancy
        CrossRegionRestore = $backupProps.CrossRegionRestore
        SoftDelete         = $vaultProps.SoftDeleteFeatureState
        Immutability       = $immutability
        ProtectedVMs       = $vmItems.Count
        Issues             = $issues -join '; '
    }
}

$file = Join-Path $OutputFolder "AzBackupVaults-$(Get-Date -Format 'yyyyMMdd-HHmm').csv"
$rows | Export-Csv $file -NoTypeInformation
$rows | Format-Table Vault, Location, StorageRedundancy, SoftDelete, Immutability, ProtectedVMs, Issues -AutoSize -Wrap
Write-Information "Vaults: $(@($rows).Count). Needing attention: $(@($rows | Where-Object Issues).Count). CSV: $file" -InformationAction Continue
