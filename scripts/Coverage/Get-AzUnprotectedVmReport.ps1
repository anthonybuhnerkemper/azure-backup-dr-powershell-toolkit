#Requires -Version 7.4
#Requires -Modules Az.Accounts, Az.Compute, Az.RecoveryServices
<#
.SYNOPSIS
    Finds Azure VMs that are not backed up by any Recovery Services vault.
.DESCRIPTION
    Read-only. Compares every VM in the subscription with the VMs protected in every vault
    and lists the gaps. VMs tagged with -ExcludeTagName (for example Backup = Exempt) are
    listed as exempt, not as gaps, so you can document why a VM is skipped. Exports CSV.
.PARAMETER ExcludeTagName
    Tag name that marks a VM as intentionally not backed up. Default Backup.
.PARAMETER ExcludeTagValue
    Tag value that marks a VM as exempt. Default Exempt.
.PARAMETER OutputFolder
    Folder for CSV output. Defaults to ./output.
.EXAMPLE
    ./Get-AzUnprotectedVmReport.ps1
.EXAMPLE
    ./Get-AzUnprotectedVmReport.ps1 -ExcludeTagName BackupPolicy -ExcludeTagValue None
#>
[CmdletBinding()]
param(
    [string]$ExcludeTagName = 'Backup',
    [string]$ExcludeTagValue = 'Exempt',
    [string]$OutputFolder = (Join-Path (Get-Location) 'output')
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { throw 'Not connected. Run Connect-M365Admin -Service Azure first.' }
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

$protected = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($v in @(Get-AzRecoveryServicesVault)) {
    foreach ($i in @(Get-AzRecoveryServicesBackupItem -BackupManagementType AzureVM -WorkloadType AzureVM -VaultId $v.ID)) {
        if ($i.ProtectionState -notmatch 'Stopped') { [void]$protected.Add($i.VirtualMachineId) }
    }
}

$rows = foreach ($vm in @(Get-AzVM)) {
    if ($protected.Contains($vm.Id)) { continue }
    $exempt = $vm.Tags -and $vm.Tags[$ExcludeTagName] -eq $ExcludeTagValue
    [pscustomobject]@{
        VM            = $vm.Name
        ResourceGroup = $vm.ResourceGroupName
        Location      = $vm.Location
        OsType        = $vm.StorageProfile.OsDisk.OsType
        Size          = $vm.HardwareProfile.VmSize
        Status        = if ($exempt) { 'Exempt (tagged)' } else { 'Not protected' }
    }
}

$file = Join-Path $OutputFolder "AzUnprotectedVMs-$(Get-Date -Format 'yyyyMMdd-HHmm').csv"
$rows | Export-Csv $file -NoTypeInformation
$rows | Format-Table VM, ResourceGroup, Location, OsType, Status -AutoSize
$gaps = @($rows | Where-Object Status -eq 'Not protected')
Write-Information "VMs with no backup: $($gaps.Count). Exempt: $(@($rows).Count - $gaps.Count). CSV: $file" -InformationAction Continue
