# 05 - Disaster recovery with Azure Site Recovery

Backup protects you from deleted files and bad changes. Site Recovery protects you from losing a whole region. You usually want both for important servers.

## 1. Is replication healthy?
```powershell
./scripts/DisasterRecovery/Get-AzSiteRecoveryHealthReport.ps1 -MaxRpoMinutes 15
```
Look for:
- **Health Warning or Critical.** The `HealthErrors` column says why. Common causes are network rules blocking replication traffic and a missing cache storage account.
- **RPO above your target.** Check the source VM's disk churn and the network path.
- **No test failover recorded.** Run a test failover into an isolated network. It does not touch production.

## 2. A simple DR routine
1. Run the health report every week.
2. Run a test failover every quarter for each recovery plan.
3. Write down what broke and fix it before the next test.
4. Clean up the test failover when you are done.

The best time to find a DR problem is during a test, not during an outage.
