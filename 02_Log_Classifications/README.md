# Log Classifications

## Change Table Plan

### Analytics to Basic Plan Changes

You can switch between Analytics and Basic table plans for supported tables. The change takes effect immediately on existing data and affects both new and historical data in the table.

**Methods to change table plans**:
- **Azure Portal**: Navigate to your Log Analytics workspace > Tables > Select table > Manage table
- **PowerShell**: Use `Update-AzOperationalInsightsTable` cmdlet
- **Azure CLI**: Use `az monitor log-analytics workspace table update` command
- **REST API**: Use the Tables - Update API

**Requirements and limitations**:
- Only supported Azure tables and DCR-based custom tables can use Basic plan - see [supported tables list](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/basic-logs-azure-tables)
- Table plan can only be changed once per week
- When switching from Analytics to Basic, data older than 30 days becomes long-term retention
- Total retention period remains unchanged unless explicitly modified

**Automation at scale**: For bulk operations across multiple tables, see the PowerShell script in the [scripts](./scripts/) folder that automates the transition of all eligible tables to Basic plan.

**Getting Started**:
```powershell
# Clone the repository
git clone https://github.com/claestom/log-analytics-cost-optimizer.git

# Navigate to the scripts folder
cd log-analytics-cost-optimizer/02_Log_Classifications/scripts

# If not logged in, connect to Azure
Connect-AzAccount
```

**PowerShell Scripts for Automation**:

The [scripts](./scripts/) folder contains PowerShell scripts to automate table plan management. These scripts only consider tables that have had data ingested in the last 30 days to avoid processing unused or inactive tables.

1. **`Get-LogAnalyticsTables.ps1`** - Single workspace operations
   - Lists tables with data in a specific workspace
   - Changes all eligible tables to Basic plan
   - Handles errors gracefully and skips unsupported tables
   
   ```powershell
   # List tables only (safe mode)
   .\Get-LogAnalyticsTables.ps1 -SubscriptionId "sub-id" -ResourceGroupName "rg-name" -WorkspaceName "workspace-name" -ListOnly
   
   # Change all eligible tables to Basic plan
   .\Get-LogAnalyticsTables.ps1 -SubscriptionId "sub-id" -ResourceGroupName "rg-name" -WorkspaceName "workspace-name"
   ```

2. **`Set-AllWorkspacesToBasic.ps1`** - Subscription-wide operations
   - Processes all Log Analytics workspaces in a subscription
   - Supports workspace exclusions for critical environments
   - Includes dry-run mode for safe testing
   
   ```powershell
   # Dry run to see what would be changed
   .\Set-AllWorkspacesToBasic.ps1 -SubscriptionId "sub-id" -DryRun
   
   # Exclude critical workspaces and run
   .\Set-AllWorkspacesToBasic.ps1 -SubscriptionId "sub-id" -ExcludeWorkspaces @("prod-workspace", "security-logs")
   
   # Run for all workspaces in subscription
   .\Set-AllWorkspacesToBasic.ps1 -SubscriptionId "sub-id"
   ```

**Safety Features**:
- Both scripts include confirmation prompts before making changes
- Error handling continues processing other tables if individual changes fail
- Dry-run mode for safe exploration (subscription-wide script)
- List mode for safe exploration (single workspace script)
- Detailed progress reporting and summary statistics

### Auxiliary Plan

The Auxiliary plan has different constraints compared to Analytics and Basic plans:

**Creation only**: Auxiliary plan can only be set when creating custom tables using the API. You cannot switch existing tables to Auxiliary plan.

For detailed steps and examples, see [Select a table plan in Log Analytics workspace](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/logs-table-plans?tabs=azure-powershell).