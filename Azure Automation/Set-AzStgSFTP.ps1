 param
    (
        [Parameter(Mandatory=$true,Position = 0, HelpMessage = 'Enter the Azure Resource Group, that contains your Azure Storage account')]
        [string]
        $resourceGroupName,
    
        [Parameter(Position = 1, Mandatory = $true, HelpMessage = 'Enter the Azure Storage account name')]
        [string]
        $storageAccountName,
    
        [Parameter(Mandatory = $true, HelpMessage = '$True = Enable SFTP & $False = Disable SFTP')][ValidateSet('$false','$true')]
        $enableSftp
    )
  
      <#
    .SYNOPSIS
    Disables or enables SFTP support on an Azure Storage Account.
    .DESCRIPTION
    Disables or enables SFTP support on an Azure Storage Account. The intention is for this script to be used in Azure Automation, alongside a Schedule to enable or disable SFTP support on an Azure Storage Account.

    .EXAMPLE
    Set-AzStgSFTP -resourceGroupName sftp_prod -storageAccountName sftpprod0 -EnableSFTP $true
  #>

  
  # Ensures you do not inherit an AzContext in your runbook
Disable-AzContextAutosave -Scope Process

Import-Module -Name Az.Storage
# Connect to Azure with system-assigned managed identity
$AzureContext = (Connect-AzAccount -Identity).context

Write-Output -InputObject $AzureContext
Write-Output -InputObject $AzureContext.Subscription
Write-Output -InputObject $resourceGroupName 
Write-Output -InputObject $storageAccountName
Write-Output -InputObject $EnableSFTP
$SetSFTP = [boolean]$enableSftp
# set and store context
$AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext
  
    $SFTPStatus = Get-AzStorageAccount -DefaultProfile $AzureContext -ResourceGroupName $resourceGroupName -Name $storageAccountName | Select-Object -ExpandProperty EnableSftp

    $Status = $SFTPStatus -replace 'True', 'Enabled' -replace 'False', 'Disabled'

    Write-Output -InputObject ('SFTP for {0} currently has SFTP set to: {1} before update.' -f $storageAccountName, $Status)
  
    Set-AzStorageAccount -DefaultProfile $AzureContext -ResourceGroupName $resourceGroupName -Name $storageAccountName -EnableSftp $SetSFTP

    $SFTPStatus = Get-AzStorageAccount -DefaultProfile $AzureContext -ResourceGroupName $resourceGroupName -Name $storageAccountName | Select-Object -ExpandProperty EnableSftp

    $Status = $SFTPStatus -replace 'True', 'Enabled' -replace 'False', 'Disabled'

    Write-Output -InputObject ('SFTP for {0} currently has SFTP set to: {1} after update.' -f $storageAccountName, $Status)
