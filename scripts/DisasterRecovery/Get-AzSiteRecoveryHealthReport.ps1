#Requires -Version 7.4
#Requires -Modules Az.Accounts, Az.RecoveryServices
<#
.SYNOPSIS
    Reports Azure Site Recovery replication health and test failover state for every vault.
.DESCRIPTION
    Read-only. For each replicated item shows the source and target, protection state,
    replication health, current RPO (Azure to Azure only), test failover state and any
    health errors. Flags items that are not healthy, have an RPO above -MaxRpoMinutes, or
    have never had a test failover recorded. Exports CSV.
.PARAMETER MaxRpoMinutes
    An RPO above this is flagged. Default 30.
.PARAMETER OutputFolder
    Folder for CSV output. Defaults to ./output.
.EXAMPLE
    ./Get-AzSiteRecoveryHealthReport.ps1
.EXAMPLE
    ./Get-AzSiteRecoveryHealthReport.ps1 -MaxRpoMinutes 15
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 1440)][int]$MaxRpoMinutes = 30,
    [string]$OutputFolder = (Join-Path (Get-Location) 'output')
)
$ErrorActionPreference = 'Stop'
if (-not (Get-AzContext)) { throw 'Not connected. Run Connect-M365Admin -Service Azure first.' }
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

$rows = foreach ($v in @(Get-AzRecoveryServicesVault)) {
    Set-AzRecoveryServicesAsrVaultContext -Vault $v | Out-Null
    foreach ($fabric in @(Get-AzRecoveryServicesAsrFabric)) {
        foreach ($container in @(Get-AzRecoveryServicesAsrProtectionContainer -Fabric $fabric)) {
            foreach ($p in @(Get-AzRecoveryServicesAsrReplicationProtectedItem -ProtectionContainer $container)) {
                $rpoSeconds = $p.ProviderSpecificDetails.RpoInSeconds
                $rpoMin = if ($null -ne $rpoSeconds) { [math]::Round($rpoSeconds / 60, 1) } else { $null }
                $issues = @()
                if ($p.ReplicationHealth -ne 'Normal') { $issues += "Health $($p.ReplicationHealth)" }
                if ($null -ne $rpoMin -and $rpoMin -gt $MaxRpoMinutes) { $issues += "RPO $rpoMin min" }
                if (-not $p.TestFailoverState -or $p.TestFailoverState -eq 'None') { $issues += 'No test failover recorded' }
                [pscustomobject]@{
                    Vault           = $v.Name
                    Item            = $p.FriendlyName
                    Source          = $p.PrimaryFabricFriendlyName
                    Target          = $p.RecoveryFabricFriendlyName
                    ActiveLocation  = $p.ActiveLocation
                    ProtectionState = $p.ProtectionState
                    Health          = $p.ReplicationHealth
                    RpoMinutes      = $rpoMin
                    TestFailover    = $p.TestFailoverState
                    HealthErrors    = (@($p.ReplicationHealthErrors) | ForEach-Object { $_.ErrorMessage }) -join ' | '
                    Issues          = $issues -join '; '
                }
            }
        }
    }
}

$file = Join-Path $OutputFolder "AzSiteRecovery-$(Get-Date -Format 'yyyyMMdd-HHmm').csv"
$rows | Export-Csv $file -NoTypeInformation
$rows | Format-Table Vault, Item, Source, Target, Health, RpoMinutes, TestFailover, Issues -AutoSize -Wrap
Write-Information "Replicated items: $(@($rows).Count). Needing attention: $(@($rows | Where-Object Issues).Count). CSV: $file" -InformationAction Continue
