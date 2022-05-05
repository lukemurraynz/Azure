#requires -Version 3.0 -Modules Az.Accounts, Az.Resources
<#
    .SYNOPSIS
    PowerShell Azure Automation Runbook for Starting/Stopping Virtual Machines. 
    .AUTHOR
    Luke Murray (https://github.com/lukemurraynz/)
    .VERSION
    1.0 - 28/04/22 - script versioned to '1.0'.
    .DESCRIPTION
    1. The script first checks if today is a holiday by making a call to the Abstract API.
    The Abstract API returns a JSON object containing the holiday name and (optional) description.
    The script checks if the name property is null. If it is not null, the script displays a message indicating that today is a holiday.
    If the name property is null, the script displays a message indicating that today is not a holiday.
    2. The script then checks if the virtual machine is running or not. If it is running, the script will stop the virtual machine.
    If it is not running, the script will start the virtual machine, depending on the Shutdown tag value
#>

Param(
  [Parameter(Mandatory = $true)]
  [String]
  $TagName,
  [Parameter(Mandatory = $true)]
     
  [String]
  $TagValue,
  [Parameter(Mandatory = $true)]
  [Boolean]
  $Shutdown
)

$CountryCode = 'NZ'
$Date = Get-Date
$API = Get-AutomationVariable -Name AbstractApiKey
$Holiday = Invoke-WebRequest -Uri ('https://holidays.abstractapi.com/v1/?api_key={0}&country={1}&year={2}&month={3}&day={4}' -f $API, $CountryCode, $Date.Year, $Date.Month, $Date.Day)

$Holidays = $Holiday.Content
$Holidays = $Holidays | ConvertFrom-Json

IF ($null -ne $Holidays.name) 
{
  Write-Output -InputObject ("Today is a holiday. The Holiday today is: {0}. The Azure Virtual Desktop machine won't be started." -f $Holidays.name)
}
ELSE 
{
  Write-Output -Message 'No holiday today. The Virtual Machine will be started.'

  # Ensures you do not inherit an AzContext in your runbook
  Disable-AzContextAutosave -Scope Process
  # Connect to Azure with system-assigned managed identity (Azure Automation account, which has been given VM Start permissions)
  $AzureContext = (Connect-AzAccount -Identity).context
  Write-Output -InputObject $AzureContext
  # set and store context
  $AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext
  Write-Output -InputObject $AzureContext

  $vms = Get-AzResource -TagName $TagName -TagValue $TagValue | Where-Object -FilterScript {
    $_.ResourceType -like 'Microsoft.Compute/virtualMachines' 
  }

  Foreach ($vm in $vms) 
  {
    if ($Shutdown -eq $true) 
    {
      Write-Output -InputObject "Stopping $($vm.Name)"        
      Stop-AzVM -Name $vm.Name -ResourceGroupName $vm.ResourceGroupName -Force
    }
    else 
    {
      Write-Output -InputObject "Starting $($vm.Name)"        
      Start-AzVM -Name $vm.Name -ResourceGroupName $vm.ResourceGroupName
    }
  }
}
