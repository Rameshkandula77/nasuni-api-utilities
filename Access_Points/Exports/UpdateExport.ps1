#Update Existing NFS Export
 
#populate NMC hostname and credentials
$hostname = "nmc.coan.com"
  
#username for AD accounts supports both UPN (user@domain.com) and DOMAIN\\samaccountname formats (two backslashes required). Nasuni Native user accounts are also supported.
$username = "username"
$password = 'password'

#specify Nasuni volume guid and filer serial number
$filer_serial = "InsertFilerSerial"
$volume_guid = "InsertVolumeGuid"

#export id - obtain using the list exports API endpoint or the ExportAllNFSExportsToCSV script
$export_id = "InsertExportID"
#export comment
$comment = "InsertComment"
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

#build credentials
$credentials = '{"username":"' + $username + '","password":"' + $password + '"}'


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
$loginUrl="https://"+$hostname+"/api/v1.2/auth/login/"
  
#Use credentials to request and store a session token from NMC for later use
$result = Invoke-RestMethod -Uri $loginUrl -Method Post -Headers $headers -Body $credentials
$token = $result.token
$headers.Add("Authorization","Token " + $token)

#Build json body for export update
$updateBody = @"
{
	"comment": "$comment",
    "readonly": "$readonly",
    "hostspec": "$hostspec",
    "access_mode": "$accessMode",
    "perf_mode": "$perfMode",
	"sec_options": [
        "$secOptions"
    ]
}
"@
 
#Update the export
$UpdateExportURL="https://"+$hostname+"/api/v1.1/volumes/" + $volume_guid + "/filers/" + $filer_serial + "/exports/" + $export_id + "/"
$response=Invoke-RestMethod -Uri $UpdateExportURL -Headers $headers -Method Patch  -Body $UpdateBody
write-output $response | ConvertTo-Json

	


