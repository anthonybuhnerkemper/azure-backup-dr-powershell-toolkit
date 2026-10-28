#Requires -Version 7.4
#Requires -Modules Az.Accounts, Az.RecoveryServices
<#
.SYNOPSIS
    Turns on Azure Backup for a list of VMs from a CSV file.
.DESCRIPTION
    Reads a CSV with columns VMName, ResourceGroup, Vault and Policy (see
    samples/vms-to-protect.sample.csv). For each row it checks the vault and policy exist,
    skips VMs that are already protected, and enables protection. Supports -WhatIf / -Confirm.
    Tip: feed it the gaps from Get-AzUnprotectedVmReport.
.PARAMETER Path
    Path to the CSV file.
.EXAMPLE
    ./Enable-AzVmBackupFromCsv.ps1 -Path ./samples/vms-to-protect.sample.csv -WhatIf
.EXAMPLE
    ./Enable-AzVmBackupFromCsv.ps1 -Path ./vms.csv
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)][ValidateScript({ Test-Path $_ })][string]$Path
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { throw 'Not connected. Run Connect-M365Admin -Service Azure first.' }

$rows = @(Import-Csv $Path)
foreach ($col in 'VMName', 'ResourceGroup', 'Vault', 'Policy') {
    if ($rows -and $col -notin $rows[0].PSObject.Properties.Name) { throw "CSV is missing column $col." }
}

$vaults = @{}
foreach ($v in @(Get-AzRecoveryServicesVault)) { $vaults[$v.Name] = $v }

foreach ($r in $rows) {
    $vault = $vaults[$r.Vault]
    if (-not $vault) { Write-Warning "$($r.VMName): vault $($r.Vault) not found. Skipped."; continue }
    $policy = Get-AzRecoveryServicesBackupProtectionPolicy -VaultId $vault.ID | Where-Object Name -eq $r.Policy
    if (-not $policy) { Write-Warning "$($r.VMName): policy $($r.Policy) not found in $($r.Vault). Skipped."; continue }

    $existing = Get-AzRecoveryServicesBackupItem -BackupManagementType AzureVM -WorkloadType AzureVM -VaultId $vault.ID |
        Where-Object { ($_.VirtualMachineId -split '/')[-1] -eq $r.VMName -and ($_.VirtualMachineId -split '/')[4] -eq $r.ResourceGroup }
    if ($existing) { Write-Verbose "$($r.VMName) is already protected by $($existing.ProtectionPolicyName)"; continue }

    if ($PSCmdlet.ShouldProcess("$($r.ResourceGroup)/$($r.VMName)", "Enable backup in $($r.Vault) with policy $($r.Policy)")) {
        try {
            Enable-AzRecoveryServicesBackupProtection -Policy $policy -Name $r.VMName -ResourceGroupName $r.ResourceGroup -VaultId $vault.ID | Out-Null
            Write-Information "$($r.VMName): backup enabled ($($r.Policy))" -InformationAction Continue
        }
        catch { Write-Warning "$($r.VMName): $($_.Exception.Message)" }
    }
}
