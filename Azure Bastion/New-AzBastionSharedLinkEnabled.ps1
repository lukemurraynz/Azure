function New-AzBastionSharedLinkEnabled {
    <#
      .SYNOPSIS
      Creates an Azure Bastion resource with shared link enabled, on an already existing Azure Virtual Network.
    #>
    [CmdletBinding()]
    param
    (
      [Parameter(Mandatory = $false, Position = 0)]
      [System.String]
      $RGName = "BastionTest",
      
      [Parameter(Mandatory = $false, Position = 1)]
      [System.String]
      $VNetName = 'vnet-aue-dev',
      
      [Parameter(Mandatory = $false, Position = 2)]
      [System.String]
      $addressPrefix = '10.2.1.0/26',
      
      [Parameter(Mandatory = $false, Position = 3)]
      [System.String]
      $region = 'AustraliaEast',
      
      [Parameter(Mandatory = $false, Position = 4)]
      [System.String]
      $BastionPubIPName = 'VNet1-ip',
      
      [Parameter(Mandatory = $false, Position = 5)]
      [Object]
      $BastionResourceName = "$VNetName-bastion"
    )
    
    # Set variable values for Resource Group name, Virtual Network name, address prefix, region, and bastion-related resources.
  
    # Connect to Azure using Get-AzAccount cmdlet.
    Connect-AzAccount
    
    # Use Get-AzSubscription cmdlet to get all the subscriptions that the account has access to and allow the user to choose one using Out-GridView.
    Get-AzSubscription | Out-GridView -PassThru | Select-AzSubscription
    $token = (Get-AzAccessToken).Token
    $subscription = Get-AzContext | Select-Object Subscription
    
    # Use Get-AzVirtualNetwork cmdlet to get the virtual network object and then use Add-AzVirtualNetworkSubnetConfig cmdlet to create a new subnet for Azure Bastion service. Finally, use Set-AzVirtualNetwork cmdlet to update the virtual network configuration.
    $VNET = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName 
    Add-AzVirtualNetworkSubnetConfig -VirtualNetwork $VNET -Name "AzureBastionSubnet" -AddressPrefix $addressPrefix | Set-AzVirtualNetwork
    $VNET = Get-AzVirtualNetwork -ResourceGroupName $RGName -Name $VNetName 
    
    # Note: If there is an error message, it could indicate that the address prefix for the new subnet overlaps with existing address ranges or is too small.
    
    # Use New-AzPublicIpAddress cmdlet to create a new public IP address resource for the Bastion service.
    $publicip = New-AzPublicIpAddress -ResourceGroupName $RGName -name $BastionPubIPName -location $region -AllocationMethod Static -Sku Standard
    $publicip = Get-AzPublicIpAddress -ResourceGroupName $RGName -Name $BastionPubIPName
    # Use New-AzBastion cmdlet to create a new Azure Bastion resource with the specified configuration, including the virtual network and public IP address resources created earlier.
    New-AzBastion -ResourceGroupName $RGName -Name $BastionResourceName -PublicIpAddressRgName $publicip.ResourceGroupName -PublicIpAddressName $publicip.Name  -VirtualNetwork $VNET -Sku 'Standard' 
    
    #Enable Shareable links for VMs in Azure Bastion.
    $BastionSubnet = Get-AzVirtualNetworkSubnetConfig -Name 'AzureBastionSubnet' -VirtualNetwork $VNET
    
    $Body = [PSCustomObject]@{
      location   = $region
      properties = @{
        enableShareableLink = "true"
        ipConfigurations    = @(
          @{
            name       = "bastionHostIpConfiguration"
            properties = @{
              subnet          = @{
                id = $BastionSubnet.id
              }
              publicIPAddress = @{
                id = $publicip.Id
              }
            }
          }
        )
      }
      
    }  | ConvertTo-Json -Depth 6
    
    $params = @{
      Uri         = "https://management.azure.com/subscriptions/" + $subscription.Subscription.Id + 
      "/resourceGroups/$($RGName)/providers/Microsoft.Network/bastionHosts/$($BastionResourceName)?api-version=2022-07-01"
      Headers     = @{ 'Authorization' = "Bearer $token" }
      Method      = 'Put'
      Body        = $body
      ContentType = 'application/json'
    }
    
    # Invoke the REST API and store the response
    Invoke-RestMethod @Params
  }
  
  