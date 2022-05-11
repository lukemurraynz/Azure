#requires -Version 3.0 -Modules Az.Accounts, Az.AlertsManagement
<#
    .SYNOPSIS
    PowerShell Azure Automation Runbook for Stopping Virtual Machines, that have been Shutdown within the Windows Operating System (Stopped and not Deallocated). 
    .AUTHOR
    Luke Murray (https://github.com/lukemurraynz/)
#>

[OutputType('PSAzureOperationResponse')]
param ( 
    [Parameter(Mandatory = $true, HelpMessage = 'Data from the WebHook/Azure Alert')][Object]$WebhookData
)

Import-Module Az.AlertsManagement
$ErrorActionPreference = 'stop'

# Get the data object from WebhookData
$WebhookData = $WebhookData.RequestBody
Write-Output -InputObject $WebhookData 
$Schema = $WebhookData | ConvertFrom-Json

#Sets the Webhook data into object
$Essentials = [object] ($Schema.data).essentials
Write-Output -InputObject $Essentials 

# Get the first target only as this script doesn't handle multiple and and export variables for the resource.
$alertIdArray = (($Essentials.alertId)).Split('/')
$alertTargetIdArray = (($Essentials.alertTargetIds)[0]).Split('/')
$alertid =  ($alertIdArray)[6]
$SubId = ($alertTargetIdArray)[2]
$ResourceGroupName = ($alertTargetIdArray)[4]
$ResourceType = ($alertTargetIdArray)[6] + '/' + ($alertTargetIdArray)[7]
$ResourceName = ($alertTargetIdArray)[-1]
$status = $Essentials.monitorCondition
Write-Output -InputObject $alertTargetIdArray
Write-Output  -InputObject "status: $status" -Verbose

#Sets VM shutdown
if (($status -eq 'Activated') -or ($status -eq 'Fired')) {
    $status = $Essentials.monitorCondition
    Write-Output -InputObject "resourceType: $ResourceType" -Verbose
    Write-Output  -InputObject "resourceName: $ResourceName" -Verbose
    Write-Output  -InputObject "resourceGroupName: $ResourceGroupName" -Verbose
    Write-Output  -InputObject "subscriptionId: $SubId" -Verbose

    # Determine code path depending on the resourceType
    if ($ResourceType -eq 'Microsoft.Compute/virtualMachines') {
        # This is an Resource Manager VM
        Write-Output  -InputObject 'This is an Resource Manager VM.' -Verbose

        # Ensures you do not inherit an AzContext in your runbook
        Disable-AzContextAutosave -Scope Process

        # Connect to Azure with system-assigned managed identity
        $AzureContext = (Connect-AzAccount -Identity).context

        # set and store context
        $AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext
        Write-Output   -InputObject $AzureContext 
        #Checks Azure VM status
        $VMStatus = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $ResourceName -Status

        Write-Output  -InputObject $VMStatus
        If ($VMStatus.Statuses[1].Code -eq 'PowerState/stopped') {
            Write-Output  -InputObject "Stopping the VM, it was Shutdown without being Deallocated - $ResourceName - in resource group - $ResourceGroupName" -Verbose
            Stop-AzVM -Name $ResourceName -ResourceGroupName $ResourceGroupName -DefaultProfile $AzureContext -Force -Verbose
      
            #Check VM Status after deallocation
            $VMStatus = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $ResourceName -Status -Verbose
            
            Write-Output  -InputObject $VMStatus

            If ($VMStatus.Statuses[1].Code -eq 'PowerState/deallocated') {
                #Closes Alert
                Write-Output  -InputObject $VMStatus.Statuses[1].Code
                Write-Output  -InputObject $alertid 
                Get-AzAlert -AlertId $alertid  -verbose -DefaultProfile $AzureContext
                Get-AzAlert -AlertId $alertid  -verbose -DefaultProfile $AzureContext | Update-AzAlertState -State 'Closed' -Verbose -DefaultProfile $AzureContext
            }
        }
             
        Elseif ($VMStatus.Statuses[1].Code -eq 'PowerState/deallocated') {
            Write-Output  -InputObject 'Already deallocated' -Verbose
        }

        Elseif ($VMStatus.Statuses[1].Code -eq 'PowerState/running') {
            Write-Output  -InputObject 'VM running. No further actions' -Verbose
        }

        # [OutputType(PSAzureOperationResponse")]
    }
}
else {
    # The alert status was not 'Activated' or 'Fired' so no action taken
    Write-Output  -InputObject ('No action taken. Alert status: ' + $status) -Verbose
}
