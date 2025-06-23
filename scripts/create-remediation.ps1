param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    [Parameter(Mandatory=$false)]
    [string]$AssignmentName = "lawcostopt-diagnostics-assignment"
)

# Get the policy assignment object to retrieve its Id
$assignment = Get-AzPolicyAssignment -Name $AssignmentName -Scope "/subscriptions/$SubscriptionId"

# Create a remediation task for the policy assignment
$remediation = Start-AzPolicyRemediation -Name "lawcostopt-diagnostics-remediation" `
    -PolicyAssignmentId $assignment.Id `
    -Scope "/subscriptions/$SubscriptionId"

Write-Host "Remediation task created."
Write-Host "Remediation Name: $($remediation.Name)"
