#Requires -Version 7.4
#Requires -Modules Az.Accounts, Az.RecoveryServices
<#
.SYNOPSIS
    Lists the recovery points you could restore from for one or all protected VMs.
.DESCRIPTION
    Read-only. For each protected Azure VM shows how many recovery points exist in the window,
    the newest and oldest point, and whether the newest is application consistent.
    Use it before a restore test or to prove retention to an auditor. Exports CSV.
.PARAMETER VaultName
    Optional. Only check this vault.
.PARAMETER VMName
    Optional. Only check this VM.
.PARAMETER Days
    How many days back to list recovery points. Default 30.
.PARAMETER OutputFolder
    Folder for CSV output. Defaults to ./output.
.EXAMPLE
    ./Get-AzBackupRecoveryPointReport.ps1
.EXAMPLE
    ./Get-AzBackupRecoveryPointReport.ps1 -VaultName rsv-contoso-prod -VMName vm-contoso-app01 -Days 7
#>
[CmdletBinding()]
param(
    [string]$VaultName,
    [string]$VMName,
    [ValidateRange(1, 3650)][int]$Days = 30,
    [string]$OutputFolder = (Join-Path (Get-Location) 'output')
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { throw 'Not connected. Run Connect-M365Admin -Service Azure first.' }
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
$end = (Get-Date).ToUniversalTime()
$start = $end.AddDays(-$Days)

$vaults = @(Get-AzRecoveryServicesVault)
if ($VaultName) { $vaults = @($vaults | Where-Object Name -eq $VaultName) }
if (-not $vaults) { throw "No vault found$(if ($VaultName) { " named $VaultName" })." }

$rows = foreach ($v in $vaults) {
    $items = @(Get-AzRecoveryServicesBackupItem -BackupManagementType AzureVM -WorkloadType AzureVM -VaultId $v.ID)
    if ($VMName) { $items = @($items | Where-Object { ($_.VirtualMachineId -split '/')[-1] -eq $VMName }) }
    foreach ($i in $items) {
        $points = @(Get-AzRecoveryServicesBackupRecoveryPoint -Item $i -StartDate $start -EndDate $end -VaultId $v.ID |
            Sort-Object RecoveryPointTime -Descending)
        $newest = $points | Select-Object -First 1
        [pscustomobject]@{
            Vault          = $v.Name
            VM             = ($i.VirtualMachineId -split '/')[-1]
            PointsInWindow = $points.Count
            NewestUtc      = $newest.RecoveryPointTime
            NewestType     = $newest.RecoveryPointType
            OldestUtc      = ($points | Select-Object -Last 1).RecoveryPointTime
            Issues         = if (-not $points) { 'No recovery points in window' } elseif ($newest.RecoveryPointType -ne 'AppConsistent') { 'Newest point is not app consistent' } else { '' }
        }
    }
}

$file = Join-Path $OutputFolder "AzBackupRecoveryPoints-$(Get-Date -Format 'yyyyMMdd-HHmm').csv"
$rows | Export-Csv $file -NoTypeInformation
$rows | Format-Table Vault, VM, PointsInWindow, NewestUtc, NewestType, OldestUtc, Issues -AutoSize -Wrap
Write-Information "VMs checked: $(@($rows).Count). CSV: $file" -InformationAction Continue
