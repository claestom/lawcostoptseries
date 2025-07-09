# Part 2: Optimize the logs: Analytics vs Basic vs Auxiliary

## Introduction

Welcome to Part 2 of our comprehensive 5-part Azure Log Analytics cost optimization series. In [Part 1](https://medium.com/@claes_tom/mastering-azure-log-analytics-cost-optimization-a-practical-5-part-guide-c6bc1781d393), we explored identifying and removing unused tables to eliminate unnecessary costs. Now, we dive deeper into one of the most impactful cost optimization strategies: **optimizing your table plans**.

Azure Monitor Logs offers three distinct table plans - Analytics, Basic, and Auxiliary - each designed to optimize costs based on different data access patterns and analysis requirements. Understanding these table plan classifications and their exact pricing implications is crucial for effective cost optimization, as choosing the right plan for each data type can result in savings of 70-90% on your log ingestion costs.

### What You'll Learn in This Part

This guide covers each table plan's features, limitations, and pricing, provides real-world cost comparisons with break-even calculations, and includes PowerShell scripts to assess your environment and automate bulk changes safely. You'll get decision frameworks and best practices to optimize costs across single workspaces or entire enterprises.

Whether you're managing a single workspace or hundreds across your enterprise, this guide provides both the knowledge and practical tools needed to optimize your Azure Monitor Logs costs effectively while maintaining operational excellence.

*This is Part 2 of our 5-part series covering: Part 1 - Unused Tables, **Part 2 - Table Plans** (this article), Part 3 - Log Centralization & Commitment Tiers, Part 4 - Dedicated Clusters, and Part 5 - Advanced Optimization Strategies.*

## Table Plans Overview

### Analytics Table Plan
**Purpose**: High-value data for continuous monitoring and real-time detection.

- **Pricing**: $2.30/GB | **Query Cost**: Free
- **Retention**: 31 days free (90 with Sentinel/App Insights)
- **Features**: Full KQL, alerts, insights, dashboards
- **Best For**: Mission-critical monitoring, real-time dashboards, automated alerts

### Basic Table Plan
**Purpose**: Medium-touch data for troubleshooting and incident response.

- **Pricing**: $0.50/GB (78% savings) | **Query Cost**: $0.005/GB scanned
- **Retention**: 30 days free
- **Features**: Single-table KQL, simple alerts, dashboards
- **Limitations**: No cross-table joins, no Insights experiences, pay-per-query
- **Best For**: Diagnostic logs, incident investigation, dev/test environments

### Auxiliary Table Plan
**Purpose**: Low-touch data for auditing and compliance.

- **Pricing**: Contact Microsoft (80%+ savings) | **Query Cost**: $0.005/GB scanned
- **Retention**: 30 days free
- **Features**: Single-table KQL only
- **Limitations**: No alerts, no Insights, no data export, slower performance, DCR-based custom tables only
- **Best For**: Verbose logs, audit trails, compliance data, archival

For more detailed information about table plans, see [Azure Monitor Logs: Table plans](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/data-platform-logs#table-plans).

## Pricing Comparison: Analytics vs Basic vs Auxiliary

Understanding the cost differences between table plans is essential for effective cost optimization:

### Ingestion and Query Costs

**Analytics Plan**
• Ingestion: $2.30/GB
• Query Cost: Free

**Basic Plan**
• Ingestion: $0.50/GB (78% savings)
• Query Cost: $0.005/GB scanned

**Auxiliary Plan**
• Ingestion: Contact Microsoft (80%+ savings)
• Query Cost: $0.005/GB scanned

### Cost Example: 10 GB Monthly Ingestion

**Scenario:** 10 GB of log data per month, queried 5 times (10 GB scanned each time)

**Analytics Plan**
• Ingestion Cost: $23.00
• Query Cost: $0.00
• **Total Monthly Cost: $23.00**

**Basic Plan**
• Ingestion Cost: $5.00
• Query Cost: $0.25 (50 GB × $0.005)
• **Total Monthly Cost: $5.25** (77% savings)

**Auxiliary Plan**
• Ingestion Cost: ~$1.00*
• Query Cost: $0.25 (50 GB × $0.005)
• **Total Monthly Cost: ~$1.25** (95% savings)

*Auxiliary pricing requires contacting Microsoft - estimated based on typical enterprise discounts

### When Query Costs Impact Basic/Auxiliary Savings

Frequent querying can reduce cost benefits for Basic and Auxiliary tables:

<strong>Break-even point:</strong> Basic becomes more expensive than Analytics when you query >360 GB per GB ingested.

<strong>Example scenarios:</strong>
• <strong>Diagnostic logs</strong> (queried 2-3 times/month): Basic saves ~75%
• <strong>Security logs</strong> (queried daily): Basic may only save ~30-50%
• <strong>Compliance logs</strong> (queried rarely): Auxiliary saves ~80-90%

For the latest pricing information, see [Azure Monitor pricing](https://azure.microsoft.com/en-us/pricing/details/monitor/).

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

**Automation at scale**: For enterprise environments managing multiple workspaces, PowerShell scripts are available to automate table plan changes across single workspaces or entire subscriptions. These scripts include safety features like dry-run modes, confirmation prompts, and error handling to ensure safe bulk operations.

**Available automation scripts**:
- **Single workspace operations**: Lists and changes tables within a specific workspace
- **Subscription-wide operations**: Processes all workspaces in a subscription with exclusion support
- **Safety features**: Dry-run modes, confirmation prompts, and detailed progress reporting

For complete PowerShell automation scripts and getting started instructions, visit the [GitHub repository](https://github.com/your-username/azure-log-analytics-cost-optimization) in the `02_Log_Classifications/scripts/` folder.

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
