# This runbook deletes all resource groups under a management group except for the ones with a specific tag.
<#
.SYNOPSIS
Deletes all resource groups under a management group except for the ones with a specific tag.

.DESCRIPTION
This script deletes all resource groups under a specified management group except for the ones with a specific tag. It can also delete policy assignments and subscription role assignments if specified.

.PARAMETER ManagementGroupId
The ID of the management group to delete resource groups under. WARNING: This script will delete all resource groups under the specified management group except for the ones with the specified tag. Make sure you have specified the correct management group ID, or you may accidentally delete resources that you did not intend to delete.

.PARAMETER TagName
The name of the tag to check for. WARNING: This script will delete all resource groups that do not have this tag. Make sure you have specified the correct tag name, or you may accidentally delete resources that you did not intend to delete.

.PARAMETER RemoveResourceGroups
If specified, deletes the resource groups that do not have the specified tag.

.PARAMETER DeletePolicyAssignments
If specified, deletes the policy assignments for the management group and all child subscriptions.

.PARAMETER DeleteSubRoleAssignments
If specified, deletes the subscription role assignments for all child subscriptions.

.EXAMPLE
.\Initiate-DakaraSuperWeapon.ps1 -ManagementGroupId "my-management-group" -TagName "my-tag" -RemoveResourceGroups -DeletePolicyAssignments -DeleteSubRoleAssignments
Deletes all resource groups under the "my-management-group" management group that do not have the "my-tag" tag, and deletes the policy assignments and subscription role assignments for all child subscriptions.

.NOTES
This script requires the Azure PowerShell module to be installed. It also requires Owner rights (or User Administrator role) in order to remove roles from a subscription. Make sure your rights are set to be inherited from a management group before running this script.
Make sure the Resource Group is protected by your 'Do Not Delete' tag, otherwise the Azure Automation account and runbook - will be deleted.
This script is provided as-is with no warranties or guarantees. Use at your own risk. This is not intended to be a script to use in Production, mainly test envrionments, as this WILL CAUSE massive destruction and irretrievable data loss... You have been warned.

.AUTHOR
Written by Luke Murray, https://luke.geek.nz. 
#>

param (
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the management group to delete resource groups under. WARNING: This script will delete all resource groups under the specified management group except for the ones with the specified tag. Make sure you have specified the correct management group ID, or you may accidentally delete resources that you did not intend to delete.")]
    [string]$ManagementGroupId,
    
    [Parameter(Mandatory = $true, HelpMessage = "The name of the tag to check for. WARNING: This script will delete all resource groups that do not have this tag. Make sure you have specified the correct tag name, or you may accidentally delete resources that you did not intend to delete.")]
    [string]$TagName,
       
    [Parameter(Mandatory = $false)]
    [switch][bool]$RemoveResourceGroups = $false,
    
    [Parameter(Mandatory = $false)]
    [switch][bool]$DeletePolicyAssignments = $false,

    [Parameter(Mandatory = $false, HelpMessage = "This will need Owner rights (or User Administrator role) in order to remove roles from a Subscription. Make sure your rights are set to be inherited from an Management Group, before running this.")]
    [switch][bool]$DeleteSubRoleAssignments = $false
)

# Convert string values to boolean values
$RemoveResourceGroups = [System.Boolean]::Parse($RemoveResourceGroups)
$DeletePolicyAssignments = [System.Boolean]::Parse($DeletePolicyAssignments)
$DeleteSubRoleAssignments = [System.Boolean]::Parse($DeleteSubRoleAssignments)

# Ensures you do not inherit an AzContext in your runbook
Disable-AzContextAutosave -Scope Process

#Toggle to stop warnings with regards to Breaking Changes in Azure PowerShell
Set-Item -Path Env:\SuppressAzurePowerShellBreakingChangeWarnings -Value $true

# Connect to Azure with system-assigned managed identity
(Connect-AzAccount -Identity).context

# Write an initial log message
Write-Output "Initilizing superweapon...."

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
$mgid = Get-AzManagementGroup -GroupId $ManagementGroupID -Expand

$subIds = (Get-AzSubscriptionsFromManagementGroup -ManagementGroupName $mgid.DisplayName).id


# Delete the policy assignments

if ($DeletePolicyAssignments -eq $true) {
    Write-Output "Deleting management group policy assignments..."
    Get-AzPolicyAssignment -Scope $mgid.Id | Remove-AzPolicyAssignment -Verbose
    Write-Output "Deleting subscription group policy assignments..."

    foreach ($subId in $subIds) {
        Write-Output "Setting subscription context..."
        Set-AzContext -Subscription $subId
        Write-Output "Deleting subscription group policy assignments..."
        Get-AzPolicyAssignment -Scope "/subscriptions/$($subId)" | Remove-AzPolicyAssignment -Verbose

    }
}
else {
    Write-Output "Skipping policy assignment deletion..."
}

# Delete the resource groups
if ($RemoveResourceGroups -eq $true) {
    Write-Output "Deleting resource groups..."

    if ($null -ne $subIds -and $subIds.Count -gt 0) {

        foreach ($subId in $subIds) {
            Write-Output "Setting subscription context..."
            Set-AzContext -Subscription $subId

            $ResourceGroupsfordeletion = Get-AzResourceGroup | Where-Object { $_.Tags -eq $null -or $_.Tags.ContainsKey($tagName) -eq $false }
            Write-Output "The following Resource Groups will be deleted..."
            Write-Output -InputObject $ResourceGroupsfordeletion

            ## Checks to see if a Recovery Services Vaults exists, the Recovery Services Vault and backups need to be deleted first.
            $RSV = Get-AzRecoveryServicesVault | Where-Object { $_.ResourceGroupName -in $ResourceGroupsfordeletion.ResourceGroupName }
            if ($null -ne $RSV) {

                ForEach ($RV in $RSV) {
                    Write-Output  "Backup Vault deletion supports deletion of Azure VM backup vaults ONLY currently."
                    #Credit to Wim Matthyssen for reference in the backup section of the script - https://wmatthyssen.com/2020/11/17/azure-backup-remove-a-recovery-services-vault-and-all-cloud-backup-items-with-azure-powershell/
                    Set-AzRecoveryServicesVaultProperty -Vault $RV.ID -SoftDeleteFeatureState Disable
                    Set-AzRecoveryServicesVaultContext -Vault $RV
                    $containerSoftDelete = Get-AzRecoveryServicesBackupItem -BackupManagementType AzureVM -WorkloadType AzureVM | Where-Object { $_.DeleteState -eq "ToBeDeleted" }
 
                    foreach ($item in $containerSoftDelete) {
                        Undo-AzRecoveryServicesBackupItemDeletion -Item $item  -Force -Verbose
                    }

                    $containerBackup = Get-AzRecoveryServicesBackupItem -BackupManagementType AzureVM -WorkloadType AzureVM  | Where-Object { $_.DeleteState -eq "NotDeleted" }
                    foreach ($item in $containerBackup) {
                        Disable-AzRecoveryServicesBackupProtection -Item $item -RemoveRecoveryPoints -Force -Verbose
                    }
                    Remove-AzRecoveryServicesVault -Vault $RV -Verbose

                }

            }
        

            Write-Output "Deleting resource groups..."
            $ResourceGroupsfordeletion | ForEach-Object -Parallel {
                Remove-AzResourceGroup -Name $_.ResourceGroupName -Force
            } -ThrottleLimit 20 -Verbose

    
            # Remove the Network Watcher resource group - if remaining - in some scenarios the script left this RG behind.
            # Get the resource group with the specified tag
            $networkWatcherRG = Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -eq 'NetworkWatcherRG' }
            if ($null -ne $networkWatcherRG -and $null -ne $networkWatcherRG.Tags -and $networkWatcherRG.Tags.ContainsKey($tagName) -eq $false) {
                Remove-AzResourceGroup -Name $networkWatcherRG.ResourceGroupName -Force -ErrorAction Continue -Verbose
            }     
        }

        # Write a final log message
        Write-Output "Resource group deletion process completed."
    }
    else {
        Write-Output "No child subscriptions found under the specified management group."
    }

}
else {
    Write-Output "Skipping resource group deletion..."
}

if ($DeleteSubRoleAssignments -eq $true) {
    if ($null -ne $subIds -and $subIds.Count -gt 0) {

        foreach ($subId in $subIds) {
            Write-Output "Setting subscription context..."
            Set-AzContext -Subscription $subId
            $roleAssignments = Get-AzRoleAssignment -Scope "/subscriptions/$($subId)" -IncludeClassicAdministrators
            Write-Output -InputObject $roleAssignments
            # Loop through each role assignment and delete it if it is not inherited a management group
            foreach ($roleAssignment in $roleAssignments) {
                if ($roleAssignment.Scope -like "/subscriptions/*" -and $null -ne $roleAssignment.ObjectId -and $roleAssignment.ObjectId -ne "") {
                    Write-Output "Deleting role assignment..."
                    Remove-AzRoleAssignment -Scope $roleAssignment.Scope -ObjectId $roleAssignment.ObjectId -RoleDefinitionName $roleAssignment.RoleDefinitionName -Verbose -ErrorAction Continue 
                }
            }
            Write-Output "Deleting subscription role assignments..."
        }

    }

}
else {
    Write-Output "Skipping policy subscription role assignments deletion..."
}
