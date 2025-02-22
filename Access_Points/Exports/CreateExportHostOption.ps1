#Add a new host option to an existing Nasuni NFS Export

#populate NMC hostname and credentials
$hostname = "host.domain.com"
 
#username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required ). Nasuni Native user accounts are also supported.
$username = "username"
$password = 'password'

#specify Nasuni volume guid and filer serial number
$filer_serial = "InsertFilerSerial"
$volume_guid = "InsertVolumeGuid"

#specify host option information
#exportID - obtain using the list exports API endpoint or the ExportAllNFSExportsToCSV script
$export_id = "insertExportID"
#enable read only access for the export: true/false - default value is "false"
$readonly = "false"
#define the default hostspec for the export, the same as allowed hosts in the UI
$hostspec = "*"
#access mode: root_squash (default), no_root_squash (All Users Permitted),all_squash (Anonymize All Users)
$accessMode = "root_squash"
#set the perf mode: sync (default), async (Asynchronous Replies), no_wdelay (No Write Delay) 
$perfMode = "sync"
#configure security options: sys (default), krb5 (Authentication), krb5i (Integrity Protection), krb5p (Privacy Protection)
$secOptions = "sys"

#end variables
#build credentials for later use
$credentials = '{"username":"' + $username + '","password":"' + $password + '"}'

#function for error
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
$url="https://"+$hostname+"/api/v1.1/auth/login/"
  
#Use credentials to request and store a session token from NMC for later use
$result = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $credentials
$token = $result.token
$headers.Add("Authorization","Token " + $token)
 
#Create the host option
#set the create host options URL
$createHostOptionsUrl="https://"+$hostname+"/api/v1.1/volumes/" + $volume_guid + "/filers/" + $filer_serial + "/exports/" + $export_id + "/nfs_host_options/"
 
#body for host option create
$body = @"
{
    "readonly": "$readonly",
    "hostspec": "$hostspec",
    "access_mode": "$accessMode",
    "perf_mode": "$perfMode",
	"sec_options": [
        "$secOptions"
    ]
}
"@

#create the host option
try { $response=Invoke-RestMethod -Uri $createHostOptionsUrl -Method Post -Headers $headers -Body $body} catch {Failure}
write-output $response | ConvertTo-Json
