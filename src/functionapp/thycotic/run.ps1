using namespace System.Net

param($Request)

$parameters = @{
    Uri                  = $Request.Headers["DestinationServer"]
    Method               = 'POST'
    SkipCertificateCheck = $true
    Body                 = $Request.Body
    Headers              = [hashtable]$Request.Headers
}
$response = Invoke-RestMethod @parameters

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $response
    })