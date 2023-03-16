function New-AzBastionShareableLink {
  <#
    .SYNOPSIS
      Creates an Azure Bastion shareable link.
  #>
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory = $false, Position = 0)]
    [System.String]
    $BastionResourceName = 'net-aue-dev-bastion',
    
    [Parameter(Mandatory = $false, Position = 1)]
    [System.String]
    $RGName = "BastionTest",
    
    [Parameter(Mandatory = $false, Position = 1)]
    [System.String]
    $VMRGName = "BastionTest",

    [Parameter(Mandatory = $false, Position = 2)]
    [System.String]
    $VMname = "2022ServerVM-2"
  )
  
  # Connect to Azure using Get-AzAccount
  Connect-AzAccount
  
  # Get all subscriptions that the account has access to
  Get-AzSubscription | Out-GridView -PassThru | Select-AzSubscription
  
  $subscription = Get-AzContext | Select-Object Subscription
  # Get the access token for the authenticated user
  $token = (Get-AzAccessToken).Token
  
  $ID = Get-AzVM -ResourceGroupName $VMRGName -Name $VMName | Select-Object Id -ExpandProperty id
  
  $body = @{
    
    vms = @(
      @{
        vm = @{
          id = $ID.Id
        }
      }
    )
    
  }  | ConvertTo-Json -Depth 3
  
  
  #creates the shareable link for the VM
  $params = @{
    Uri         = "https://management.azure.com/subscriptions/" + $subscription.Subscription.Id + 
    "/resourceGroups/$RGName/providers/Microsoft.Network/bastionHosts/$BastionResourceName/createShareableLinks?api-version=2022-07-01"
    Headers     = @{ 'Authorization' = "Bearer $token" }
    Method      = 'POST'
    Body        = $body
    ContentType = 'application/json'
  }
  
  # Invoke the REST API and store the response
  Invoke-RestMethod @Params
  
  Start-Sleep -Seconds 10

  #Gets the shareable link for the VM
    
 $params = @{
    Uri         = "https://management.azure.com/subscriptions/" + $subscription.Subscription.Id + 
    "/resourceGroups/$($RGName)/providers/Microsoft.Network/bastionHosts/$BastionResourceName/getShareableLinks?api-version=2022-09-01"
    Headers     = @{ 'Authorization' = "Bearer $token" }
    Method      = 'POST'
    # Body        = $body
    ContentType = 'application/json'
  }
  
  # Invoke the REST API and store the response
  $ShareableLink = Invoke-RestMethod @Params
  Write-Output $ShareableLink.value.bsl 
}

