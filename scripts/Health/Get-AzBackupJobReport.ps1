#Requires -Version 7.4
#Requires -Modules Az.Accounts, Az.RecoveryServices
<#
.SYNOPSIS
    Lists failed and warning backup jobs across every vault for the last few days.
.DESCRIPTION
    Read-only. Pulls backup jobs from every Recovery Services vault, keeps the ones that
    failed or completed with warnings, and adds the error message from the job details.
    Exports CSV. Run it every morning.
.PARAMETER Days
    How many days back to look. Default 3. Azure keeps job history for a limited time.
.PARAMETER IncludeSucceeded
    Also include jobs that completed without problems.
.PARAMETER OutputFolder
    Folder for CSV output. Defaults to ./output.
.EXAMPLE
    ./Get-AzBackupJobReport.ps1
.EXAMPLE
    ./Get-AzBackupJobReport.ps1 -Days 7 -IncludeSucceeded
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 30)][int]$Days = 3,
    [switch]$IncludeSucceeded,
    [string]$OutputFolder = (Join-Path (Get-Location) 'output')
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { throw 'Not connected. Run Connect-M365Admin -Service Azure first.' }
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
$to = (Get-Date).ToUniversalTime()
$from = $to.AddDays(-$Days)

$rows = foreach ($v in @(Get-AzRecoveryServicesVault)) {
    foreach ($j in @(Get-AzRecoveryServicesBackupJob -VaultId $v.ID -From $from -To $to)) {
        if (-not $IncludeSucceeded -and $j.Status -in 'Completed', 'InProgress') { continue }
        $errorText = $null
        if ($j.Status -ne 'Completed') {
            try {
                $detail = Get-AzRecoveryServicesBackupJobDetail -Job $j -VaultId $v.ID
                $errorText = (@($detail.ErrorDetails) | ForEach-Object { "$($_.ErrorCode): $($_.ErrorMessage)" }) -join ' | '
            }
            catch { $errorText = "Could not read job details: $($_.Exception.Message)" }
        }
        [pscustomobject]@{
            Vault       = $v.Name
            Workload    = $j.WorkloadName
            Operation   = $j.Operation
            Status      = $j.Status
            StartUtc    = $j.StartTime
            EndUtc      = $j.EndTime
            DurationMin = if ($j.Duration) { [math]::Round($j.Duration.TotalMinutes, 1) } else { $null }
            Error       = $errorText
        }
    }
}

$file = Join-Path $OutputFolder "AzBackupJobs-$(Get-Date -Format 'yyyyMMdd-HHmm').csv"
$rows | Export-Csv $file -NoTypeInformation
$rows | Sort-Object StartUtc -Descending | Format-Table Vault, Workload, Operation, Status, StartUtc, Error -AutoSize -Wrap
Write-Information "Jobs listed: $(@($rows).Count) in the last $Days days. CSV: $file" -InformationAction Continue
