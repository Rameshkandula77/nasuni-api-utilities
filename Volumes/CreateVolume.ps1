#Creates Volume

#populate NMC hostname and credentials
$hostname = "host.domain.com"
 
#username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required ). Nasuni Native user accounts are also supported.
$username = "username"
$password = 'password'
 
#specify volume name
$volume_name = "insertVolumeName"
#specify Edge Appliance serial number
$filer_serial_number = "insertFilerSerial"
#cred uuid - lookup using List all cloud credentials endpoint - begins with "customer-"
$cred_uuid = "insert cred_uuid"
#provider name - Amazon S3, Azure
$provider_name = "Amazon S3"
#shortname - amazons3, azure, googles3
$shortname = "amazons3"
#location - AmazonS3 locations - Asia, Beijing, Canada, EU, Frankfurt, HongKong, London, Mumbai, Ningxia, Ohio, Oregon, Paris, Seoul, SouthAmerica, Stockholm, Sydney, Tokyo, UsWest
$location = "Ohio"
#permissions policy PUBLICMODE60 (PUBLIC), NTFS60 (NTFS Compatible), NTFSONLY710 (NTFS Exlusive)
$permissions_policy = "NTFSONLY710"
#authenticated access - false for public, true for AD
$authenticated_access = "true"
#policy - public (no auth), ads (active directory)
$policy = "ads"
#policy label - Publicly Available,  Active Directory
$policy_label = "Active Directory"
#Auto Provision Credentials - use existing cred or create new
$auto_provision_cred = "false"
#Key Name - specify existing encryption key Name if autoprovision = false, should match key name
$key_name = "insertExistingEncryptionKeyName"
#create default access point
$create_default_access_point = "true"
#case sensitive
$case_sensitive = "false"

#end variables
$credentials = '{"username":"' + $username + '","password":"' + $password + '"}'

#function for error
#Error Handling function - must appear in the script before it is referenced
function Failure {
    if ( $PSVersionTable.PSVersion.Major -lt 6) { #PowerShell 5 and earlier
    $global:result = $_.Exception.Response.GetResponseStream()
    $global:reader = New-Object System.IO.StreamReader($global:result)
    $global:responseBody = $global:reader.ReadToEnd();
    Write-Host -BackgroundColor:Black -ForegroundColor:Red "Status: A system exception was caught."
    Write-Host -BackgroundColor:Black -ForegroundColor:Red $global:responsebody
    Write-Host -BackgroundColor:Black -ForegroundColor:Red "The request body has been saved to `$global:helpme"($result)
    } else { #PowerShell 6 or higher lack support for GetResponseStream
$Message =  $_.ErrorDetails.Message;
Write-Host ("Message: "+ $Message)
}
}

#Request token and build connection headers
# Allow untrusted SSL certs
if ($PSVersionTable.PSEdition -eq 'Core') #PowerShell Core
{
	if ($PSDefaultParameterValues.Contains('Invoke-RestMethod:SkipCertificateCheck')) {}
	else {
		$PSDefaultParameterValues.Add('Invoke-RestMethod:SkipCertificateCheck', $true)
	}
}
else #other versions of PowerShell
{if ("TrustAllCertsPolicy" -as [type]) {} else {		
	
Add-Type -TypeDefinition @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
	public bool CheckValidationResult(
		ServicePoint srvPoint, X509Certificate certificate,
		WebRequest request, int certificateProblem) {
		return true;
	}
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object -TypeName TrustAllCertsPolicy

#set the correct TLS Type
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
 } }
 
#build JSON headers
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Accept", 'application/json')
$headers.Add("Content-Type", 'application/json')
 
#construct Uri
$url="https://"+$hostname+"/api/v1.2/auth/login/"
  
#Use credentials to request and store a session token from NMC for later use
$result = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $credentials
$token = $result.token
$headers.Add("Authorization","Token " + $token)
 
#Create the  volume
$url="https://"+$hostname+"/api/v1.2/volumes/"
 
 
#body for volume create
$body = @"
{
    "filer_serial_number": "$filer_serial_number",
    "provider": {
        "cred_uuid": "$cred_uuid",
        "name": "$provider_name",
        "shortname": "$shortname",
        "location": "$location"
    },
    "name": "$volume_name",
    "protocols": {
        "permissions_policy": "$permissions_policy",
        "protocols": [
            "CIFS"
        ]
    },
    "auth": {
        "authenticated_access": "$authenticated_access",
        "policy": "$policy",
        "policy_label": "$policy_label"
    },
    "options": {
        "auto_provision_cred": "$auto_provision_cred",
        "key_name": "$key_name",
        "create_default_access_point": "$create_default_access_point"
    },
    "case_sensitive": "$case_sensitive"
}
"@

#create the volume
try { $response=Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body} catch {Failure}
write-output $response | ConvertTo-Json
