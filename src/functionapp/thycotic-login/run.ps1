using namespace System.Net

param($Request)

Write-Information "Getting token from Thycotic server..."
$parameters = @{
    Uri = $Request.Body.serverUrl
    Method = 'POST'
    SkipCertificateCheck = $true
    Body = @{
        username = $Request.Body.username
        password = $Request.Body.password
        grant_type = 'password'
    }
}
$token = Invoke-RestMethod @parameters

Write-Information "Returning token to client..."
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $token
    })