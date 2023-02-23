# Connect to Azure using Get-AzAccount
Connect-AzAccount

# Set the region to 'Australia East'
$region = 'Australia East'

# Get all subscriptions that the account has access to
$subscriptions = Get-AzSubscription | Select-Object -ExpandProperty SubscriptionId

# Get the access token for the authenticated user
$token = (Get-AzAccessToken).Token

# Check if AvailabilityZonePeering feature is enabled and enable it if it's not
$azFeature = Get-AzProviderFeature -ProviderNamespace Microsoft.Resources -FeatureName AvailabilityZonePeering
if (!$azFeature.RegistrationState.Equals("Registered")) {
    do {
        Register-AzProviderFeature -FeatureName AvailabilityZonePeering -ProviderNamespace Microsoft.Resources
        Start-Sleep -Seconds 5
        $azFeature = Get-AzProviderFeature -ProviderNamespace Microsoft.Resources -FeatureName AvailabilityZonePeering
    } until ($azFeature.RegistrationState.Equals("Registered"))
    Write-Host "The AvailabilityZonePeering feature has been enabled."
}
else {
    Write-Host "The AvailabilityZonePeering feature is already enabled."
}

# Define the request body for the REST API call
$body = @{
    subscriptionIds = $subscriptions | ForEach-Object { 'subscriptions/' + $_ }
    location        = $region
} | ConvertTo-Json

# Define the request parameters for the REST API call
$params = @{
    Uri         = "https://management.azure.com/subscriptions/" + $subscriptions[1] + 
    "/providers/Microsoft.Resources/checkZonePeers/?api-version=2020-01-01"
    Headers     = @{ 'Authorization' = "Bearer $token" }
    Method      = 'POST'
    Body        = $body
    ContentType = 'application/json'
}

# Invoke the REST API and store the response
$availabilityZonePeers = Invoke-RestMethod @Params

# Initialize an empty array for the output
$output = @()

# Loop through each availability zone and its associated peers and add them to the output array
foreach ($i in $availabilityZonePeers.availabilityZonePeers.availabilityZone) {
    foreach ($zone in $availabilityZonePeers.availabilityZonePeers[$i - 1].peers ) {
        $output += New-Object PSObject -Property @{
            Zone           = $i
            MatchesZone    = $zone.availabilityZone
            SubscriptionId = $zone.subscriptionId
        }
    }
    $output += ""
}

# Output the results
$output | Format-Table
