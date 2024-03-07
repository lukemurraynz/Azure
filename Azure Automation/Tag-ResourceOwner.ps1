<# Ensures you do not inherit an AzContext in your runbook #>
Disable-AzContextAutosave -Scope Process | Out-Null;

#Toggle to stop warnings with regards to Breaking Changes in Azure PowerShell
Set-Item -Path Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value $true

# Import the required modules
Import-Module Az.Accounts
Import-Module Az.Resources

# Define the tag name as a variable
$tagName = "Createdby"

#Adjust to suit your management group, this is the top scope that the Script will run under
$ManagementGroupID = 'mg-landingzones'


<# Connect using a Managed Service Identity #>

Connect-AzAccount -Identity



# Get the subscription IDs under the specified management group AND child management groups
function Get-AzSubscriptionsFromManagementGroup {
    param($ManagementGroupName)
    $mg = Get-AzManagementGroup -GroupId $ManagementGroupName -Expand
    foreach ($child in $mg.Children) {
        if ($child.Type -match '/managementGroups$') {
            Get-AzSubscriptionsFromManagementGroup -ManagementGroupName $child.Name
        }
        else {
            $child | Select-Object @{N = 'Name'; E = { $_.DisplayName } }, @{N = 'Id'; E = { $_.Name } }
        }
    }
}


Write-Output "Setting ManagementGroupID to $($mgid.DisplayName)'..."

Write-Output "Retrieving management group with ID '$ManagementGroupID'..."
$mgid = Get-AzManagementGroup -GroupId $ManagementGroupID -Expand

Write-Output "Successfully retrieved management group with ID '$ManagementGroupID'."

Write-Output "Retrieving subscription IDs from management group '$($mgid.DisplayName)'..."

$subIds = Get-AzSubscriptionsFromManagementGroup -ManagementGroupName $ManagementGroupID 

foreach ($subId in $subIds) {
    Write-Output "Setting subscription context for subscription $subId..."
    Set-AzContext -Subscription $subId.Id

    $resources = Get-AzResource 

    Write-Output "Found resources in subscription $subId."

    foreach ($resource in $resources) {
        Write-Output "Processing resource $($resource.Name)..."
        $tags = $resource.Tags
        if ($null -ne $tags -and -not $tags.ContainsKey($tagName)) {          
            Write-Output "Resource $($resource.Name) does not have 'resource-owner' and  tags. Adding tags..."

            $endTime = Get-Date
            $startTime = $endTime.AddDays(-7)
            $owners = Get-AzLog -ResourceId $resource.ResourceId -StartTime $startTime -EndTime $endTime |
            Where-Object { $_.Authorization.Action -like "*/write*" } |
            Select-Object -ExpandProperty Caller 
            $owner = $owners | Where-Object { $_ -match "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$" } | Select-Object -First 1

            #Objects created by a Service Principal will tag the objects with a GUID instead of a name by default. You can fix this behavior by giving the Managed Identity the Application Developer role in Entra ID. 

            # If owner is null, stop the script
            if ($null -eq $owner) {
                Write-Output "No owner found that matches an email address."
            }
            
            # Output owners
            Write-Output "Owners: $owners, selected owner: $owner"
            $existingTags = $resource.Tags
            $modifiedTags = @{
                $tagName = $owner
            }
            # Merge existing tags with new tags
            $allTags = $existingTags + $modifiedTags

            $resource | Set-AzResource -Tag $allTags -Force
        }
    }
}
