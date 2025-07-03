# Part 2: Optimize the logs: Analytics vs Basic vs Auxiliary

## Introduction

Azure Monitor Logs offers three table plans designed to optimize costs based on data access patterns and analysis requirements. Understanding these classifications and their exact pricing is crucial for effective cost optimization.

## Table Plans Overview

### Analytics Table Plan
**Purpose**: High-value data for continuous monitoring and real-time detection.

**Key Features**:
- **Pricing**: $2.30 per GB (Pay-as-you-go)
- **Query Cost**: Included, **no** query cost (no additional charges)
- **Retention**: 31 days free (90 days with Sentinel/App Insights)
- **Performance**: Optimized, real-time
- **Features**: Full KQL, alerts, insights, dashboards

**Best For**: Mission-critical monitoring, real-time dashboards, automated alerts

### Basic Table Plan
**Purpose**: Medium-touch data for troubleshooting and incident response.

**Key Features**:
- **Pricing**: $0.50 per GB (78% savings vs Analytics)
- **Query Cost**: $0.005 per GB of data scanned
- **Retention**: 30 days free
- **Performance**: Optimized for single-table queries
- **Features**: Full KQL on single tables, simple alerts, dashboards

**Limitations**:
- No cross-table joins (single table queries only)
- No Insights or built-in monitoring experiences (e.g., VM Insights, Container Insights, Application Insights workbooks)
- Pay-per-query model increases costs with frequent access

**Best For**: Diagnostic logs, incident investigation, dev/test environments

### Auxiliary Table Plan
**Purpose**: Low-touch data for auditing and compliance.

**Key Features**:
- **Pricing**: Contact Microsoft (significantly lower than Basic)
- **Query Cost**: $0.005 per GB of data scanned
- **Retention**: 30 days free
- **Performance**: Slower, unoptimized
- **Features**: Single-table KQL only, no alerts or insights

**Limitations**:
- No alerting capabilities whatsoever
- No Insights or monitoring experiences (e.g., VM Insights, Container Insights, Network Insights dashboards)
- No data export functionality
- Slower query performance (not real-time optimized)
- Single-table queries only (no joins with other tables)
- DCR-based custom tables only (limited table type support)

**Best For**: Verbose logs, audit trails, compliance data, archival

For more detailed information about table plans, see [Azure Monitor Logs: Table plans](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/data-platform-logs#table-plans).

## Change Table Plan

### Analytics ↔ Basic Plan Changes

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

**Prerequisites - Check Azure Context**:
```powershell
# If not logged in, connect to Azure
Connect-AzAccount

# Set the correct subscription context
Set-AzContext -SubscriptionId "your-subscription-id"
```

### Auxiliary Plan

The Auxiliary plan has different constraints compared to Analytics and Basic plans:

**Creation only**: Auxiliary plan can only be set when creating custom tables using the API. You cannot switch existing tables to Auxiliary plan.

For detailed steps and examples, see [Select a table plan in Log Analytics workspace](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/logs-table-plans?tabs=azure-powershell).

## Recommendations

1. **Start with Analytics** for critical operational data
2. **Move to Basic** for diagnostic logs accessed weekly/monthly (consider query frequency vs savings)
3. **Use Auxiliary** for compliance data accessed rarely (understand feature limitations)
4. **Monitor query costs** on Basic/Auxiliary tables - frequent querying can negate savings
5. **Consider commitment tiers** for predictable Analytics ingestion >100GB/day
6. **Avoid Basic/Auxiliary** for data requiring real-time alerts or complex analytics
7. **Plan for limitations** - ensure single-table queries meet your analysis needs

## Conclusion

Choose table plans based on access patterns and cost sensitivity. Analytics provides full features at standard cost, Basic offers 78% cost savings for periodic access, and Auxiliary provides maximum savings for archival scenarios. The key is matching the right plan to each data type's requirements.

---

*Next: Part 3 - Log Centralization, Commitment Tiers & Dedicated Clusters*
