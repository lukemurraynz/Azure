# Stop an existing firewall

$FWName = 'az_fw_01'
$RGName = 'firewall_prod_rg'

$azfw = Get-AzFirewall -Name "$FWName" -ResourceGroupName $RGName
$azfw.Deallocate()
Set-AzFirewall -AzureFirewall $azfw

# Start a firewall

$azfw = Get-AzFirewall -Name "$FWName" -ResourceGroupName "$RGName"
$azfw.Allocate()

Set-AzFirewall -AzureFirewall $azfw
