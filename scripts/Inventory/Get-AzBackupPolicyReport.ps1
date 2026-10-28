#Requires -Version 7.4
#Requires -Modules Az.Accounts, Az.RecoveryServices
<#
.SYNOPSIS
    Lists backup policies in every Recovery Services vault with schedule and retention.
.DESCRIPTION
    Read-only. Shows each policy's workload type, how often it runs, the run time (UTC),
    daily, weekly, monthly and yearly retention, and how many items use it.
    Flags policies with short daily retention or no items. Exports CSV.
.PARAMETER MinimumDailyRetentionDays
    Policies that keep daily points for fewer days than this are flagged. Default 14.
.PARAMETER OutputFolder
    Folder for CSV output. Defaults to ./output.
.EXAMPLE
    ./Get-AzBackupPolicyReport.ps1
.EXAMPLE
    ./Get-AzBackupPolicyReport.ps1 -MinimumDailyRetentionDays 30
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 9999)][int]$MinimumDailyRetentionDays = 14,
    [string]$OutputFolder = (Join-Path (Get-Location) 'output')
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { throw 'Not connected. Run Connect-M365Admin -Service Azure first.' }
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

$rows = foreach ($v in @(Get-AzRecoveryServicesVault)) {
    $items = @(Get-AzRecoveryServicesBackupItem -BackupManagementType AzureVM -WorkloadType AzureVM -VaultId $v.ID)
    foreach ($p in @(Get-AzRecoveryServicesBackupProtectionPolicy -VaultId $v.ID)) {
        $r = $p.RetentionPolicy
        $daily = if ($r.IsDailyScheduleEnabled) { $r.DailySchedule.DurationCountInDays } else { $null }
        $used = @($items | Where-Object ProtectionPolicyName -eq $p.Name).Count
        $issues = @()
        if ($p.WorkloadType -eq 'AzureVM' -and $used -eq 0) { $issues += 'No VMs use this policy' }
        if ($null -ne $daily -and $daily -lt $MinimumDailyRetentionDays) { $issues += "Daily retention $daily days" }
        [pscustomobject]@{
            Vault          = $v.Name
            Policy         = $p.Name
            WorkloadType   = $p.WorkloadType
            Frequency      = $p.SchedulePolicy.ScheduleRunFrequency
            RunTimesUtc    = (@($p.SchedulePolicy.ScheduleRunTimes) | ForEach-Object { ([datetime]$_).ToString('HH:mm') }) -join ', '
            DailyDays      = $daily
            WeeklyWeeks    = if ($r.IsWeeklyScheduleEnabled) { $r.WeeklySchedule.DurationCountInWeeks } else { $null }
            MonthlyMonths  = if ($r.IsMonthlyScheduleEnabled) { $r.MonthlySchedule.DurationCountInMonths } else { $null }
            YearlyYears    = if ($r.IsYearlyScheduleEnabled) { $r.YearlySchedule.DurationCountInYears } else { $null }
            VMsUsingPolicy = $used
            Issues         = $issues -join '; '
        }
    }
}

$file = Join-Path $OutputFolder "AzBackupPolicies-$(Get-Date -Format 'yyyyMMdd-HHmm').csv"
$rows | Export-Csv $file -NoTypeInformation
$rows | Format-Table Vault, Policy, WorkloadType, Frequency, RunTimesUtc, DailyDays, VMsUsingPolicy, Issues -AutoSize -Wrap
Write-Information "Policies: $(@($rows).Count). CSV: $file" -InformationAction Continue
