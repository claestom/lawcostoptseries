#Requires -Modules Az.OperationalInsights
<#
.SYNOPSIS
    Loops through all Log Analytics workspaces in a subscription and changes all eligible tables to Basic plan.

.DESCRIPTION
    This script discovers all Log Analytics workspaces in a subscription, identifies tables with data,
    and attempts to change them to Basic plan for cost optimization. Only tables that contain data
    in the last 30 days and support Basic plan will be processed.

.PARAMETER SubscriptionId
    The Azure subscription ID to scan for Log Analytics workspaces.

.PARAMETER ExcludeWorkspaces
    Optional array of workspace names to exclude from processing.

.PARAMETER DryRun
    If specified, shows what would be changed without actually making changes.

.EXAMPLE
    .\Set-AllWorkspacesToBasic.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012"

.EXAMPLE
    .\Set-AllWorkspacesToBasic.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -DryRun

.EXAMPLE
    .\Set-AllWorkspacesToBasic.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -ExcludeWorkspaces @("critical-workspace", "prod-workspace")

.NOTES
    Author: Azure Monitor Cost Optimization Series
    Version: 1.0
    
    Prerequisites:
    - Az.OperationalInsights PowerShell module
    - Appropriate Azure RBAC permissions (Log Analytics Contributor or higher)
    - Authenticated Azure session (Connect-AzAccount)

.LINK
    https://learn.microsoft.com/en-us/azure/azure-monitor/logs/logs-table-plans
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string[]]$ExcludeWorkspaces = @(),
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

# Error handling preference
$ErrorActionPreference = 'Stop'

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [ConsoleColor]$ForegroundColor = 'White'
    )
    Write-Host $Message -ForegroundColor $ForegroundColor
}

# Function to get tables with data for a workspace
function Get-TablesWithData {
    param(
        [string]$WorkspaceId,
        [string]$WorkspaceName
    )
    
    try {
        # Query to get tables with data
        $query = @"
union withsource=TableName1 *
| where TimeGenerated > ago(30d)
| summarize Count = count() by TableName1
| where Count > 0
| project TableName = TableName1
| sort by TableName asc
"@
        
        $queryResult = Invoke-AzOperationalInsightsQuery -WorkspaceId $WorkspaceId -Query $query -ErrorAction SilentlyContinue
        if ($queryResult -and $queryResult.Results) {
            return $queryResult.Results | Select-Object -ExpandProperty TableName
        }
        return @()
    }
    catch {
        Write-ColorOutput "    Warning: Could not query tables for workspace $WorkspaceName`: $($_.Exception.Message)" -ForegroundColor Yellow
        return @()
    }
}

# Function to convert tables in a single workspace
function Convert-WorkspaceTables {
    param(
        [object]$Workspace,
        [bool]$DryRunMode
    )
    
    Write-ColorOutput "`nProcessing workspace: $($Workspace.Name)" -ForegroundColor Cyan
    Write-ColorOutput "  Resource Group: $($Workspace.ResourceGroupName)" -ForegroundColor Gray
    Write-ColorOutput "  Location: $($Workspace.Location)" -ForegroundColor Gray
    
    # Get tables with data
    $tablesWithData = Get-TablesWithData -WorkspaceId $Workspace.CustomerId -WorkspaceName $Workspace.Name
    
    if ($tablesWithData.Count -eq 0) {
        Write-ColorOutput "  No tables with data found in the last 30 days." -ForegroundColor Yellow
        return @{
            WorkspaceName = $Workspace.Name
            TablesProcessed = 0
            TablesChanged = 0
            TablesAlreadyBasic = 0
            TablesFailed = 0
            Tables = @()
        }
    }
    
    Write-ColorOutput "  Found $($tablesWithData.Count) tables with data" -ForegroundColor Green
    
    # Get all tables in the workspace to get plan information
    try {
        $allTables = Get-AzOperationalInsightsTable -ResourceGroupName $Workspace.ResourceGroupName -WorkspaceName $Workspace.Name
    }
    catch {
        Write-ColorOutput "  Error: Could not retrieve table information: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            WorkspaceName = $Workspace.Name
            TablesProcessed = 0
            TablesChanged = 0
            TablesAlreadyBasic = 0
            TablesFailed = 0
            Tables = @()
            Error = $_.Exception.Message
        }
    }
    
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
    
    # Display current state for this workspace
    Write-ColorOutput "  Current table plans:" -ForegroundColor White
    $tableInfo | Format-Table @{Name="    TableName"; Expression={$_.TableName}}, @{Name="Plan"; Expression={$_.CurrentPlan}} -AutoSize
    
    if ($DryRunMode) {
        Write-ColorOutput "  [DRY RUN] Would attempt to change tables to Basic plan..." -ForegroundColor Yellow
        foreach ($table in $tableInfo) {
            if ($table.CurrentPlan -eq 'Basic') {
                Write-ColorOutput "    [DRY RUN] $($table.TableName): Already Basic plan" -ForegroundColor Gray
            }
            else {
                Write-ColorOutput "    [DRY RUN] $($table.TableName): Would change from $($table.CurrentPlan) to Basic (if eligible)" -ForegroundColor Yellow
            }
        }
        return @{
            WorkspaceName = $Workspace.Name
            TablesProcessed = $tableInfo.Count
            TablesChanged = ($tableInfo | Where-Object { $_.CurrentPlan -ne 'Basic' }).Count
            TablesAlreadyBasic = ($tableInfo | Where-Object { $_.CurrentPlan -eq 'Basic' }).Count
            TablesFailed = 0
            Tables = $tableInfo
        }
    }
    
    # Actually change the tables
    Write-ColorOutput "  Attempting to change tables to Basic plan..." -ForegroundColor Yellow
    
    foreach ($table in $tableInfo) {
        if ($table.CurrentPlan -eq 'Basic') {
            $table.Status = 'Already Basic'
            $table.NewPlan = 'Basic'
            Write-ColorOutput "    $($table.TableName): Already Basic plan" -ForegroundColor Gray
            continue
        }
        
        try {
            Write-Host "    $($table.TableName): Changing to Basic..." -ForegroundColor Yellow -NoNewline
            
            # Attempt to change to Basic plan (suppress output)
            Update-AzOperationalInsightsTable -ResourceGroupName $Workspace.ResourceGroupName -WorkspaceName $Workspace.Name -TableName $table.TableName -Plan 'Basic' | Out-Null
            
            $table.Status = 'Changed Successfully'
            $table.NewPlan = 'Basic'
            Write-Host " SUCCESS" -ForegroundColor Green
            
        } catch {
            $table.Status = "Failed: $($_.Exception.Message)"
            $table.NewPlan = $table.CurrentPlan
            Write-Host " FAILED ($($_.Exception.Message))" -ForegroundColor Red
        }
    }
    
    # Return results for this workspace
    return @{
        WorkspaceName = $Workspace.Name
        TablesProcessed = $tableInfo.Count
        TablesChanged = ($tableInfo | Where-Object { $_.Status -eq 'Changed Successfully' }).Count
        TablesAlreadyBasic = ($tableInfo | Where-Object { $_.Status -eq 'Already Basic' }).Count
        TablesFailed = ($tableInfo | Where-Object { $_.Status -like 'Failed:*' }).Count
        Tables = $tableInfo
    }
}

try {
    Write-ColorOutput "Starting subscription-wide Log Analytics table optimization..." -ForegroundColor Green
    Write-ColorOutput "Subscription ID: $SubscriptionId" -ForegroundColor White
    
    # Check if required module is available
    if (-not (Get-Module -ListAvailable -Name "Az.OperationalInsights")) {
        throw "Az.OperationalInsights module is not installed. Please install it using: Install-Module -Name Az.OperationalInsights"
    }
    
    # Import required module
    Import-Module Az.OperationalInsights -Force
    
    # Set Azure context
    Write-ColorOutput "Setting Azure subscription context..." -ForegroundColor Yellow
    $context = Set-AzContext -SubscriptionId $SubscriptionId
    Write-ColorOutput "Connected to subscription: $($context.Subscription.Name)" -ForegroundColor Green
    
    # Get all Log Analytics workspaces in the subscription
    Write-ColorOutput "Discovering Log Analytics workspaces..." -ForegroundColor Yellow
    $allWorkspaces = Get-AzOperationalInsightsWorkspace
    
    if (-not $allWorkspaces -or $allWorkspaces.Count -eq 0) {
        Write-ColorOutput "No Log Analytics workspaces found in subscription." -ForegroundColor Yellow
        return
    }
    
    # Filter out excluded workspaces
    $workspaces = $allWorkspaces | Where-Object { $_.Name -notin $ExcludeWorkspaces }
    $excludedCount = $allWorkspaces.Count - $workspaces.Count
    
    Write-ColorOutput "Found $($allWorkspaces.Count) total workspaces ($excludedCount excluded)" -ForegroundColor Green
    
    if ($excludedCount -gt 0) {
        Write-ColorOutput "Excluded workspaces: $($ExcludeWorkspaces -join ', ')" -ForegroundColor Gray
    }
    
    if ($workspaces.Count -eq 0) {
        Write-ColorOutput "No workspaces to process after exclusions." -ForegroundColor Yellow
        return
    }
    
    # Display mode information
    if ($DryRun) {
        Write-ColorOutput "`nRunning in DRY-RUN mode - no changes will be made" -ForegroundColor Yellow
    }
    else {
        Write-ColorOutput "`nWARNING: This will attempt to change table plans across $($workspaces.Count) workspaces!" -ForegroundColor Red
        $confirm = Read-Host "Do you want to continue? (y/N)"
        if ($confirm -ne 'y' -and $confirm -ne 'Y') {
            Write-ColorOutput "Operation cancelled." -ForegroundColor Yellow
            return
        }
    }
    
    # Process each workspace
    $results = @()
    $totalWorkspaces = $workspaces.Count
    $currentWorkspace = 0
    
    foreach ($workspace in $workspaces) {
        $currentWorkspace++
        Write-ColorOutput "`n[$currentWorkspace/$totalWorkspaces] Processing workspace: $($workspace.Name)" -ForegroundColor Magenta
        
        $result = Convert-WorkspaceTables -Workspace $workspace -DryRunMode $DryRun
        $results += $result
    }
    
    Write-ColorOutput "`nProcessing completed for all workspaces." -ForegroundColor Green
    
}
catch {
    Write-ColorOutput "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-ColorOutput "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}
finally {
    Write-ColorOutput "`nScript execution completed." -ForegroundColor Green
}
