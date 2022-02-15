#requires -Version 3.0 -Modules Az.Sql
$AzureSQLServers = Get-AzSqlServer

$results = @()
ForEach ($server in $AzureSQLServers)


{
  $SQLServer = Get-AzSqlServer -ServerName $server.ServerName -ResourceGroupName $server.ResourceGroupName

  $results += [pscustomobject]@{
    ServerName          = $SQLServer.ServerName
    ResourceGroup       = $SQLServer.ResourceGroupName
    PublicNetworkAccess = $SQLServer.PublicNetworkAccess
  }
}

$results
