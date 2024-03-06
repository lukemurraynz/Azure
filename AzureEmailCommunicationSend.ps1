# Define the Service Principal credentials and email addresses

# The Service Principal's Application (client) ID
# This is a unique identifier for the app, assigned by Entra ID. Replace to match your environment.
$SPNAppId = '069893df-a389-4a2a-99aa-d035265cfbb7'

# The Service Principal's secret
# This is like a password for the app, used for authentication. Replace to match your environment.
$SPNSecretValue = 'fc6652c483d4475a9c59cc1d81b6d45a'

# The Entra ID tenant ID
# This is the unique identifier for the Entra ID tenancy instance where the app is registered. Replace to match your environment.
$SPNTenantId = '49e37426-fba3-4995-b563-0355b5d6fc60'

# The sender's email address
# This is the email address that will appear in the "From" field of the email
$senderAddress = 'itservicedesk@959df321-6092-41e7-8414-e7b4ea05da2b.azurecomm.net'

# The recipient's email address
# This is the email address where the email will be sent
$recipientAddress = 'recipientemail@test.com'

# The URI for the Azure Communication Services API
$communicationendpointurl = "azcommservices1.australia.communication.azure.com"

# Function to get the access token from Entra ID
function Get-AccessToken {    
    # Define the parameters for the REST API call
    $params = @{
        Uri    = "https://login.microsoftonline.com/$($SPNTenantId)/oauth2/v2.0/token"
        Method = "POST"
        Body   = @{
            client_id     = $SPNAppId
            client_secret = $SPNSecretValue
            grant_type    = "client_credentials"
            scope         = "https://communication.azure.com/.default"
        }
    }

    # Call the REST API and get the access token
    $token = Invoke-RestMethod @params
    return $token.access_token
}

# Define the URI for the Azure Communication Services API

$uri = "https://$communicationendpointurl/emails:send?api-version=2023-03-31"

# Define the headers for the REST API call
$headers = @{
    "Content-Type"  = "application/json"
    "Authorization" = "Bearer $(Get-AccessToken)"
}

# Define the body for the REST API call
# Define the body for the REST API call
# This includes the email headers, sender address, content, recipients, attachments, reply-to addresses, and tracking settings

$apiResponse = @{
    # The headers of the email, including a unique ID generated by New-Guid
    headers                        = @{
        id = (New-Guid).Guid
    }
    # The sender's email address
    senderAddress                  = $senderAddress 
    # The content of the email, including the subject, plain text body, and HTML body
    content                        = @{
        subject   = "Contoso Email Test"
        plainText = "This is a test email from Contoso. If you received this, our test was successful."
        html      = "<html><head><title>Contoso Email Test</title></head><body><h1>This is a test email from Contoso.</h1><p>If you received this, our test was successful.</p></body></html>"
    }
    # The recipients of the email, including the "to", "cc", and "bcc" addresses
    recipients                     = @{
        to  = @(
            @{
                address     = $recipientAddress
                displayName = $recipientAddress
            },
            @{
                address     = "Jane.Doe@contoso.com"
                displayName = "Jane Doe"
            }
        )
        cc  = @(
            @{
                address     = 'wendy.smith@contoso.com'
                displayName = 'Wendy Smith'
            },
            @{
                address     = "jimmy.johns@contoso.com"
                displayName = "Jimmy Johns"
            }
        )
        bcc = @(
            @{
                address     = "bob.jones@contoso.com"
                displayName = "Bob Jones"
            },
            @{
                address     = "alice.johnson@contoso.com"
                displayName = "Alice Johnson"
            }
        )
    }
    # The attachments to the email, including the name, content type, and content in Base64
    attachments                    = @(
        @{
            name            = "Attachment.txt"
            contentType     = "application/txt"
            contentInBase64 = "TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQ="
        }

    )
    # The reply-to addresses for the email
    replyTo                        = @(
        @{
            address     = "contoso-support@contoso.com"
            displayName = "Contoso Support"
        }
    )
    # A flag to disable user engagement tracking
    userEngagementTrackingDisabled = $true
}

# Convert the PowerShell object to JSON
# The -Depth parameter is set to 10 to ensure all levels of the object are converted
$body = $apiResponse | ConvertTo-Json -Depth 10

# Send the email
try {
    $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body -UseBasicParsing
    $response
}
catch {
    Write-Error $_.Exception.Message
}