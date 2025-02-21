using namespace System.Net

param($Request)

$ErrorActionPreference = 'Stop'

$pair = "$($Request.Headers["username"]):$($Request.Headers["password"])"
$credentials = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
$parameters = @{
    Uri                  = $Request.Headers["DestinationServer"]
    Method               = 'GET'
    SkipCertificateCheck = $true
    Headers              = @{
        Authorization = "Basic $credentials"
    }
}
$response = Invoke-RestMethod @parameters

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $response
    })