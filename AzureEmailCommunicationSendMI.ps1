param (
    [Parameter(Mandatory=$false)]
    [string]$ClientId = 'bc012f8f-58d1-43a5-9383-bb4d104ffe27',
    
    [Parameter(Mandatory=$false)]
    [string]$EmailRecipient = "example@example.com",
    
    [Parameter(Mandatory=$false)]
    [string]$SenderAddress = 'DoNotReply@af595a23-f54a-4cdc-bffa-fa3ef54eb1c1.azurecomm.net',
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceID = 'https://communication.azure.com',
    
    [Parameter(Mandatory=$false)]
    [string]$CommunicationEndpointUrl = "commserviceslukeuserassignedtest.australia.communication.azure.com"
)

$emailSubject = "Important: Server Maintenance Notification"
$emailBody = @"
<html>
<body>
<p>Dear User,</p>
<p>This is to inform you that a <b><i>server maintenance is scheduled for the next week</i></b>.</p>
<p>The servers will be down from 10:00 PM to 2:00 AM.</p>
<p>Please save your work and log off during this period to avoid any data loss.</p>
<p>If you have any questions or concerns, please contact our IT Support team.</p>
<p>Thank you for your understanding and cooperation.</p>
<p>Best Regards,</p>
<p>IT Support Team</p>
</body>
</html>
"@

if ($emailBody -ne "") {
    Write-Output "Email body is not empty. Proceeding with email sending process."

    if ($ClientId) {
        Write-Output "Client ID: $ClientId exists. Using User Assigned Managed Identity..."
        $Uri = "$($env:IDENTITY_ENDPOINT)?api-version=2018-02-01&resource=$ResourceID&client_id=$ClientId"
    } else {
        Write-Output "Client ID: $ClientId does not exist. Using System Assigned Managed Identity..."
        $Uri = "$($env:IDENTITY_ENDPOINT)?api-version=2018-02-01&resource=$ResourceID"
    }

    # Function to get access token
    try {
        # Invoke a GET request to the identity endpoint to get the access token
        $AzToken = Invoke-WebRequest -Uri $Uri -Method GET -Headers @{ Metadata = "true" } -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json | Select-Object -ExpandProperty access_token
        # Print the obtained access token
        Write-Output "Access Token: $AzToken"
    }
    catch {
        # If there's an error, print the error message and response details
        Write-Error "Failed to get access token: $_"
        Write-Output "Response Status Code: $($_.Exception.Response.StatusCode.Value__)"
        Write-Output "Response Status Description: $($_.Exception.Response.StatusDescription)"
        Write-Output "Response Content: $($_.Exception.Response.GetResponseStream() | %{ $_.ReadToEnd() })"
        return
    }

    # Construct the URI for the email sending endpoint
    $uri = "https://$CommunicationEndpointUrl/emails:send?api-version=2023-03-31"

    # Define the headers for the REST API call
    # Include the content type and the obtained access token in the Authorization header
    $headers = @{
        "Content-Type"  = "application/json"
        "Authorization" = "Bearer $AzToken"
    }

    # Function to send email
    function Send-Email {
        param (
            [string]$Uri,
            [hashtable]$Headers,
            [hashtable]$Body
        )
        try {
            Write-Output "Sending email..."
            Write-Output "URI: $Uri"
                Write-Output "Headers: $(ConvertTo-Json $Headers -Depth 10)"
            Write-Output "Body: $(ConvertTo-Json $Body -Depth 10)"
            $response = Invoke-RestMethod -Uri $Uri -Method Post -Headers $Headers -Body ($Body | ConvertTo-Json -Depth 10) -UseBasicParsing
            Write-Output "Email sent successfully. Response: $response"
            return $response
        }
        catch {
            Write-Error "Failed to send email: $_"
            Write-Output "Exception Message: $($_.Exception.Message)"
            Write-Output "Exception StackTrace: $($_.Exception.StackTrace)"
            throw
        }
    }

    $apiResponse = @{
        headers = @{
            id = (New-Guid).Guid
        }
        senderAddress = $SenderAddress
        content = @{
            subject = $emailSubject
            html    = $emailBody
        }
        recipients = @{
            to = @(
                @{
                    address     = $EmailRecipient
                    displayName = $EmailRecipient
                }
            )
        }
        replyTo = @(
            @{
                address     = "example@contoso.com"
                displayName = "Contoso"
            }
        )
        userEngagementTrackingDisabled = $true
    }

    Send-Email -Uri $uri -Headers $headers -Body $apiResponse

}
