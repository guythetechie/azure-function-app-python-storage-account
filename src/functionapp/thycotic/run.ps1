using namespace System.Net

param($Request)

$ErrorActionPreference = 'Stop'

Write-Information "Extracting headers..."
$headers = @{}
@("Authorization", "Content-Type") | ForEach-Object {
    if ($Request.Headers.ContainsKey($_)) {
        $headers.Add($_, $Request.Headers[$_])
    }
}

$parameters = @{
    Uri                  = $Request.Headers["DestinationServer"]
    Method               = 'POST'
    SkipCertificateCheck = $true
    Body                 = $Request.Body
    Headers              = $headers
}
$response = Invoke-RestMethod @parameters

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $response
    })