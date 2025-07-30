# Log Centralization, Commitment Tiers & Dedicated Clusters

## PowerShell Script: Create-ClusterAndLinkWorkspaces.ps1

Automates Azure Monitor Dedicated Cluster creation and workspace linking to achieve 15-36% cost savings through commitment tier pricing.

> **⚠️ Important**: Before using this script, review the [dedicated clusters preparation guide](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/logs-dedicated-clusters?tabs=azure-portal#preparation) to understand planning requirements, capacity considerations, and deployment best practices.

### Prerequisites

1. **Clone this repository** and navigate to the script folder:
2. **Install Azure CLI** and run `az login`
3. **Tag your Log Analytics workspaces** with a key/value pair (e.g., `Environment=Production`)
4. **Ensure workspaces are in the same region** as your planned cluster
5. **Have Contributor permissions** on subscription and resource groups

### Usage

```powershell
git clone https://github.com/claestom/lawcostoptseries.git
cd lawcostoptseries/03_Log_Centralization_Commitment_Tiers/scripts
```

```powershell
.\Create-ClusterAndLinkWorkspaces.ps1 `
  -SubscriptionId "your-subscription-id" `
  -ResourceGroupName "your-resource-group" `
  -ClusterName "your-cluster-name" `
  -Region "westeurope" `
  -CommitmentTier 100 `
  -TagKey "Environment" `
  -TagValue "Production"
```

### Parameters

- **SubscriptionId**: Your Azure subscription ID
- **ResourceGroupName**: Resource group for the cluster
- **ClusterName**: Unique cluster name
- **Region**: Azure region (must match workspace locations)
- **CommitmentTier**: Daily GB commitment (minimum 100)
- **TagKey/TagValue**: Tag filter for workspace selection

### What It Does

1. Creates dedicated cluster with specified commitment tier
2. Waits for provisioning (up to 2.5 hours)
3. Finds workspaces matching region and tags
4. Links workspaces to cluster automatically that contain the required key/value tag pairs

### Troubleshooting

See [Azure Monitor dedicated clusters troubleshooting guide](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/logs-dedicated-clusters?tabs=azure-portal#error-messages).