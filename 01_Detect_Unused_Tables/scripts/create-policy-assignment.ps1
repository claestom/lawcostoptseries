param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    [Parameter(Mandatory=$false)]
    [string]$ProfileName = "lawcostoptimization"
)

# Path to the policy definition file
$PolicyFile = Join-Path $PSScriptRoot "..\policy\definition.json"

# Create the custom policy definition
New-AzPolicyDefinition -Name "LAWCostOptimization" `
    -DisplayName "Log Analytics workspace - cost optimization - test script v1" `
    -Description "Deploys diagnostic settings for Log Analytics workspaces to stream Audit logs to themselves." `
    -Policy $PolicyFile `
    -SubscriptionId $SubscriptionId

$Policy = Get-AzPolicyDefinition -Name 'LAWCostOptimization'

# Assign the policy at the subscription scope with optional profileName parameter
$assignment = New-AzPolicyAssignment -Name "lawcostopt-diagnostics-assignment" `
    -PolicyDefinition $Policy `
    -Scope "/subscriptions/$SubscriptionId" `
    -IdentityType SystemAssigned `
    -Location "West Europe"

if (-not $assignment) {
    Write-Error "Policy assignment creation failed. Exiting."
    exit 1
}

# Wait for the managed identity to be provisioned (poll for up to 2 minutes)
$principalId = $null
$maxAttempts = 24
$attempt = 0
while (-not $principalId -and $attempt -lt $maxAttempts) {
    $assignment = Get-AzPolicyAssignment -Name "lawcostopt-diagnostics-assignment" -Scope "/subscriptions/$SubscriptionId"
    Write-Host "Assignment object (JSON):"
    $assignment | ConvertTo-Json -Depth 10
    if ($assignment.IdentityPrincipalId) {
        $principalId = $assignment.IdentityPrincipalId
    } else {
        Start-Sleep -Seconds 5
        $attempt++
    }
}

if (-not $principalId) {
    Write-Error "Managed identity was not provisioned in time. Cannot assign roles."
    exit 1
}

# Assign Monitoring Contributor role
New-AzRoleAssignment -ObjectId $principalId `
    -RoleDefinitionName "Monitoring Contributor" `
    -Scope "/subscriptions/$SubscriptionId"

# Assign Log Analytics Contributor role
New-AzRoleAssignment -ObjectId $principalId `
    -RoleDefinitionName "Log Analytics Contributor" `
    -Scope "/subscriptions/$SubscriptionId"

Write-Host "Policy definition and assignment created."
Write-Host "Assignment Name: $($assignment.Name)"
Write-Host "Managed Identity PrincipalId: $principalId"
Write-Host "Required roles assigned to the managed identity."
