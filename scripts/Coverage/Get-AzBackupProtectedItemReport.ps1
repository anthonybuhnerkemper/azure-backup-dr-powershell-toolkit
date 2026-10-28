#Requires -Version 7.4
#Requires -Modules Az.Accounts, Az.RecoveryServices
<#
.SYNOPSIS
    Reports every backed up Azure VM with its last backup result and age.
.DESCRIPTION
    Read-only. For each protected Azure VM in every vault shows the policy, protection state,
    last backup status and time, and hours since the last backup. Flags items whose last backup
    failed, is older than -StaleHours, or whose protection is stopped. Exports CSV.
.PARAMETER StaleHours
    A last backup older than this is flagged. Default 26 (a daily policy plus some slack).
.PARAMETER OutputFolder
    Folder for CSV output. Defaults to ./output.
.EXAMPLE
    ./Get-AzBackupProtectedItemReport.ps1
.EXAMPLE
    ./Get-AzBackupProtectedItemReport.ps1 -StaleHours 48
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 8760)][int]$StaleHours = 26,
    [string]$OutputFolder = (Join-Path (Get-Location) 'output')
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { throw 'Not connected. Run Connect-M365Admin -Service Azure first.' }
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
$now = (Get-Date).ToUniversalTime()

$rows = foreach ($v in @(Get-AzRecoveryServicesVault)) {
    foreach ($i in @(Get-AzRecoveryServicesBackupItem -BackupManagementType AzureVM -WorkloadType AzureVM -VaultId $v.ID)) {
        $last = if ($i.LastBackupTime) { ([datetime]$i.LastBackupTime).ToUniversalTime() } else { $null }
        $age = if ($last) { [math]::Round(($now - $last).TotalHours, 1) } else { $null }
        $issues = @()
        if ($i.LastBackupStatus -and $i.LastBackupStatus -ne 'Completed') { $issues += "Last backup $($i.LastBackupStatus)" }
        if (-not $last) { $issues += 'Never backed up' }
        elseif ($age -gt $StaleHours) { $issues += "No backup for $age hours" }
        if ($i.ProtectionState -match 'Stopped') { $issues += "Protection $($i.ProtectionState)" }
        [pscustomobject]@{
            Vault            = $v.Name
            VM               = ($i.VirtualMachineId -split '/')[-1]
            VmResourceGroup  = ($i.VirtualMachineId -split '/')[4]
            Policy           = $i.ProtectionPolicyName
            ProtectionState  = $i.ProtectionState
            LastBackupStatus = $i.LastBackupStatus
            LastBackupUtc    = $last
            HoursSinceBackup = $age
            Issues           = $issues -join '; '
        }
    }
}

$file = Join-Path $OutputFolder "AzBackupProtectedItems-$(Get-Date -Format 'yyyyMMdd-HHmm').csv"
$rows | Export-Csv $file -NoTypeInformation
$rows | Sort-Object HoursSinceBackup -Descending | Format-Table Vault, VM, Policy, LastBackupStatus, HoursSinceBackup, Issues -AutoSize -Wrap
Write-Information "Protected VMs: $(@($rows).Count). Needing attention: $(@($rows | Where-Object Issues).Count). CSV: $file" -InformationAction Continue
