#Requires -Modules Az.OperationalInsights
<#
.SYNOPSIS
    Lists all tables in a Log Analytics workspace that contain data and changes them to Basic plan.

.PARAMETER SubscriptionId
    The Azure subscription ID containing the Log Analytics workspace.

.PARAMETER ResourceGroupName
    The name of the resource group containing the Log Analytics workspace.

.PARAMETER WorkspaceName
    The name of the Log Analytics workspace to scan.

.PARAMETER ListOnly
    If specified, only lists tables without making changes.

.EXAMPLE
    .\Get-LogAnalyticsTables.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -ResourceGroupName "rg-monitoring" -WorkspaceName "law-prod"

.EXAMPLE
    .\Get-LogAnalyticsTables.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -ResourceGroupName "rg-monitoring" -WorkspaceName "law-prod" -ListOnly
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$WorkspaceName,
    
    [Parameter(Mandatory = $false)]
    [switch]$ListOnly
)

$ErrorActionPreference = 'Stop'

try {
    # Set Azure context
    Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
    
    # Get workspace details
    $workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroupName -Name $WorkspaceName
    
    # Query to get tables with data (using the workspace)
    $query = @"
union withsource=TableName1 *
| where TimeGenerated > ago(30d)
| summarize Count = count() by TableName1
| where Count > 0
| project TableName = TableName1
| sort by TableName asc
"@
    
    # Execute query to get tables with data
    $queryResult = Invoke-AzOperationalInsightsQuery -WorkspaceId $workspace.CustomerId -Query $query
    $tablesWithData = $queryResult.Results | Select-Object -ExpandProperty TableName
    
    # Get all tables in the workspace to get plan information
    $allTables = Get-AzOperationalInsightsTable -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName
    
    # Filter to only tables with data and create output
    $tableInfo = $allTables | Where-Object { $_.Name -in $tablesWithData } | ForEach-Object {
        $currentPlan = if ($_.Plan) { $_.Plan } else { 'Analytics' }
        
        [PSCustomObject]@{
            TableName = $_.Name
            CurrentPlan = $currentPlan
            NewPlan = 'Not Changed'
            Status = 'Found'
        }
    } | Sort-Object TableName
    
    # Display current state
    Write-Host "Found $($tableInfo.Count) tables with data:" -ForegroundColor Green
    $tableInfo | Format-Table TableName, CurrentPlan -AutoSize
    
    if ($ListOnly) {
        Write-Host "List-only mode. No changes made." -ForegroundColor Yellow
        return
    }
    
    # Ask for confirmation
    $confirm = Read-Host "Do you want to change all eligible tables to Basic plan? (y/N)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        return
    }
    
    Write-Host "`nAttempting to change tables to Basic plan..." -ForegroundColor Yellow
    
    # Try to change each table to Basic plan
    foreach ($table in $tableInfo) {
        if ($table.CurrentPlan -eq 'Basic') {
            $table.Status = 'Already Basic'
            $table.NewPlan = 'Basic'
            Write-Host "  $($table.TableName): Already Basic plan" -ForegroundColor Gray
            continue
        }
        
        try {
            Write-Host "  $($table.TableName): Changing to Basic..." -ForegroundColor Yellow -NoNewline
            
            # Attempt to change to Basic plan (suppress output)
            Update-AzOperationalInsightsTable -ResourceGroupName $ResourceGroupName -WorkspaceName $WorkspaceName -TableName $table.TableName -Plan 'Basic' | Out-Null
            
            $table.Status = 'Changed Successfully'
            $table.NewPlan = 'Basic'
            Write-Host " SUCCESS" -ForegroundColor Green
            
        } catch {
            $table.Status = "Failed: $($_.Exception.Message)"
            $table.NewPlan = $table.CurrentPlan
            Write-Host " FAILED ($($_.Exception.Message))" -ForegroundColor Red
        }
    }
    
    # Display final results
    Write-Host "`nFinal Results:" -ForegroundColor Cyan
    $tableInfo | Format-Table TableName, CurrentPlan, NewPlan, Status -AutoSize
    
    # Summary
    $successful = ($tableInfo | Where-Object { $_.Status -eq 'Changed Successfully' }).Count
    $alreadyBasic = ($tableInfo | Where-Object { $_.Status -eq 'Already Basic' }).Count
    $failed = ($tableInfo | Where-Object { $_.Status -like 'Failed:*' }).Count
    
    Write-Host "`nSummary:" -ForegroundColor Cyan
    Write-Host "  Successfully changed to Basic: $successful" -ForegroundColor Green
    Write-Host "  Already Basic: $alreadyBasic" -ForegroundColor Gray
    Write-Host "  Failed to change: $failed" -ForegroundColor Red
    Write-Host "  Total tables processed: $($tableInfo.Count)" -ForegroundColor White
}
catch {
    Write-Error "Error: $($_.Exception.Message)"
}