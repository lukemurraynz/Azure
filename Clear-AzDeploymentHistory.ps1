function Clear-AzDeploymentHistory {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ManagementGroupName,

        [Parameter(Mandatory=$true)]
        [int]$NumberOfDeploymentsToKeep
    )
   # $ManagementGroupName = 'mg-landingzones'
    # Connect to Azure
    try {
        Connect-AzAccount -ErrorAction Stop
    } catch {
        Write-Error "Error connecting to Azure: $($_.Exception.Message)"
        return
    }

    # Get Management Group
    try {
        $mg = Get-AzManagementGroup -GroupName $ManagementGroupName -ErrorAction Stop -Verbose
    
    } catch {
        Write-Error "Error getting management group: $($_.Exception.Message)"
        return
    }

    # Get all subscriptions in the Management Group
    try {
        $subs = Get-AzManagementGroupSubscription -GroupName  $mg.Name -ErrorAction Stop 
        Write-Output "Get-AzManagementGroupSubscription -GroupName  $mg.Name"
    } catch {
        Write-Error "Error getting subscriptions in management group: $($_.Exception.Message)"
        return
    }

    # Iterate through subscriptions
    foreach($sub in $subs){
        # Select the subscription
        try {
           $subscriptionId = $subs.Id -split "/" | Select-Object -Last 1
            Select-AzSubscription -SubscriptionId  $subscriptionId -ErrorAction Stop
        } catch {
            Write-Error "Error selecting subscription: $($_.Exception.Message)"
            continue
        }

        # Get all resource groups
        try {
            $rgs = Get-AzResourceGroup -ErrorAction Stop
        } catch {
            Write-Error "Error getting resource groups: $($_.Exception.Message)"
            continue
        }

        # Iterate through resource groups
        foreach($rg in $rgs){
            # Get all deployments in resource group
            try {
                $deployments = Get-AzResourceGroupDeployment -ResourceGroupName $rg.ResourceGroupName -ErrorAction Stop
            } catch {
                Write-Error "Error getting deployments for resource group '$($rg.ResourceGroupName)': $($_.Exception.Message)"
                continue
            }

            # Sort the deployments by timestamp in descending order
            $deployments = $deployments | Sort-Object -Property Timestamp -Descending

            # Keep the specified number of deployments and delete the rest
            for($i = $NumberOfDeploymentsToKeep; $i -lt $deployments.Count; $i++){
                # Delete deployment
                try {
                    Remove-AzResourceGroupDeployment  -ResourceGroupName $rg.ResourceGroupName -Name $deployments[$i].DeploymentName -ErrorAction Stop
                } catch {
                    Write-Error "Error deleting deployment '$($deployments[$i].DeploymentName)' in resource group '$($rg.ResourceGroupName)': $($_.Exception.Message)"
                }
            }
        }
    }
}
