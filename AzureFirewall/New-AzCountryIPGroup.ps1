function New-AzCountryIPGroup {
    <#
.SYNOPSIS
Creates an Azure IP group, with the IP address ranges for various countrues.
The code does the following:
1. It downloads the IP address ranges for the country specified.
2. It checks if the IP Group already exists, if it does, it adds the IP addresses to the existing IP Group.
3. If the total number of IP addresses is less than 5000, it will add the IP addresses to the existing IP Group.
4. If the total number of IP addresses is over 5000, it will create a new IP Group, with the same name as the existing IP Group, and it will add the IP addresses to the new IP Group.
5. If the new IP Group is over 5000, it will create a new IP Group, with the same name as the existing IP Group, and it will add the IP addresses to the new IP Group.
6. It will continue to create new IP Groups until all of the IP addresses are added.

The code can be used to create IP Groups for multiple countries, and if the number of IP addresses is over 5000, it will create multiple IP Groups, with the same name, but with a counter after the name, so that it will be unique.
.EXAMPLE
New-AzCountryIPGroup
New-AzCountryIPGroup -CountryCode NZ -IPGroupName IP -IPGroupRGName NetworkRG -IPGroupLocation AustraliaEast
.AUTHOR
Luke Murray - https://luke.geek.nz/

    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]
        $CountryCode,
        [Parameter(Mandatory = $true, Position = 1)]
        [Object]
        $IPGroupName,
        [Parameter(Mandatory = $true, Position = 2)]
        [System.String]
        $IPGroupRGName,
        [Parameter(Mandatory = $true, Position = 3)]
        [System.String]
        $IPGroupLocation
    )
    
    
    $IPBlocks = Invoke-WebRequest -Uri ('https://www.ipdeny.com/ipblocks/data/aggregated/{0}-aggregated.zone' -f $CountryCode.ToLower()) 
    #Exports the IPBlock content from the HTML request, into a String
    $IPBlock = $IPBlocks.Content 
    #Spilts each IP block, into a seperate object
    $ipaddressranges = $IPBlock -split '\s+' -replace '\r?\n\r?', ''  | Where-Object { $_ -ne '' }

    $Group = Get-AzIpGroup -Name $IPGroupName -ResourceGroupName $IPGroupRGName 

    if ($ipaddressranges.Length -lt 5000) {

        If ($null -eq $Group) {
            Write-Host  "Group doesn't exist, creating a new IP Group called $IPGroupName in the following Azure Resource Group $IPGroupRGName and location $IPGroupLocation"
            $Group = New-AzIpGroup -Name $IPGroupName -ResourceGroupName $IPGroupRGName -Location $IPGroupLocation -Tag @{Country = $CountryCode } -Verbose
        
            If ($null -eq $Group) {
                New-AzResourceGroup -Name $IPGroupRGName -Location $IPGroupLocation -Tag @{Country = $CountryCode } 
                $Group = New-AzIpGroup -Name $IPGroupName -ResourceGroupName $IPGroupRGName -Location $IPGroupLocation -Tag @{Country = $CountryCode } -Verbose

            }
        
            ForEach ($ip in $ipaddressranges) {
                $Group.IpAddresses.Add($ip) 
                Write-Host  "Adding $ip to $IPGroupName."
            }
        
            $Group | Set-AzIPGroup -Verbose
        
        }

        else {
            Write-Host "Group already exists called:$IPGroupName in the following Azure Resource Group $IPGroupRGName and location $IPGroupLocation. Adding IPs to the group... Please note that this script doesn't check already existing IP addresses, if identical IP addresses exist, it will overrite it, if IP addresses outside of the Country List exist, it will remain in the IP Group - but there is no checking, if there is pre-equisting IP addresses in the IP Group that will raise the Group Limit above 5000. I recommend keeping the Country IP group seperate."
            $Group = Get-AzIpGroup -Name $IPGroupName -ResourceGroupName $IPGroupRGName 
        
        
            ForEach ($ip in $ipaddressranges) {
                $Group.IpAddresses.Add($ip) 
                Write-Host "Adding $ip to $IPGroupName"
            }
        
            $Group | Set-AzIPGroup -Verbose
        }
    }
    
    else {

        Write-Host "Azure IP Groups only support IPAddresses of up-to 5000 (the country you have specified is: "$ipaddressranges.Length"), also please make sure the country code matches https://www.ipdeny.com/ipblocks/data/aggregated/"

        $counter = [pscustomobject] @{ Value = 0 }
        $groupSize = 5000
        $groups = $ipaddressranges | Group-Object -Property { [math]::Floor($counter.Value++ / $groupSize) }
        $counter = 0
        ForEach ($group in $groups) {
            $countup = $counter + 1
        
            $azipgroup = Get-AzIpGroup -Name "$IPGroupName$countup" -ResourceGroupName $IPGroupRGName -Verbose 
        
        
            If ($null -eq $azipgroup) {
                $countup = $counter + 1
                Write-Host  "$IPGroupName$countup doesn't exist. Creating... $IPGroupName$countup in the following Resource Group $IPGroupRGName and location $IPGroupLocation." 
                $azipgroup = New-AzIpGroup -Name "$IPGroupName$countup" -ResourceGroupName $IPGroupRGName -Location $IPGroupLocation -Tag @{Country = $CountryCode } -Verbose -Force
                $ipgroup = $group.Group
                ForEach ($IP in $ipgroup) {
                    $azipgroup.IpAddresses.Add($IP)
                    Write-Host "Adding $ip to $IPGroupName" 
                }

                $azipgroup | Set-AzIPGroup -Verbose
                $counter++

            }
            else {
                $ipgroup = $group.Group
                ForEach ($IP in $ipgroup) {
                    $azipgroup.IpAddresses.Add($IP)
                    Write-Host "Adding $ip to $IPGroupName" 
                }

                $azipgroup | Set-AzIPGroup -Verbose
                $counter++
            }
        }

    }
}
