param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    [Parameter(Mandatory=$false)]
    [string]$ProfileName = "lawcostoptimization"
)

# Path to the policy definition file
$PolicyFile = Join-Path $PSScriptRoot "..\policy\definition.json"

# Create the custom policy definition
$policyDef = New-AzPolicyDefinition -Name "Custom" `
    -DisplayName "Configure diagnostic settings for Log Analytics workspace to Log Analytics workspace" `
    -Description "Deploys diagnostic settings for Log Analytics workspaces to stream Audit logs to themselves." `
    -Policy $PolicyFile `
    -Mode All `
    -SubscriptionId $SubscriptionId

# Assign the policy at the subscription scope with optional profileName parameter
$parameters = @{ profileName = @{ value = $ProfileName } }
$assignment = New-AzPolicyAssignment -Name "lawcostopt-diagnostics-assignment" `
    -PolicyDefinition $policyDef `
    -Scope "/subscriptions/$SubscriptionId" `
    -AssignIdentity `
    -PolicyParameterObject $parameters

Write-Host "Policy definition and assignment created."
Write-Host "Assignment Name: $($assignment.Name)"
Write-Host "Managed Identity PrincipalId: $($assignment.Identity.PrincipalId)"
Write-Host "Assign the required roles to this managed identity at the subscription or resource group scope."
