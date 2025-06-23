param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    [Parameter(Mandatory=$false)]
    [string]$AssignmentName = "lawcostopt-diagnostics-assignment"
)

# Create a remediation task for the policy assignment
$remediation = Start-AzPolicyRemediation -Name "lawcostopt-diagnostics-remediation" `
    -PolicyAssignmentName $AssignmentName `
    -Scope "/subscriptions/$SubscriptionId"

Write-Host "Remediation task created."
Write-Host "Remediation Name: $($remediation.Name)"
