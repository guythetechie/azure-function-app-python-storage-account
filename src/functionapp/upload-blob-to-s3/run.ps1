param($QueueItem)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$QueueItem | ForEach-Object {
    $item = $_
    Write-Information "Processing item: $($item.data.url)"

    Write-Information "Downloading blob from Azure Blob Storage..."
    $blobUri = [System.Uri]::new($item.data.url)
    $blobPath = $blobUri.AbsolutePath.Split('/')[2..($blobUri.AbsolutePath.Split('/').Length)] -join '/'
    $file = New-TemporaryFile
    $blobEndpoint = $blobUri.GetLeftPart([System.UriPartial]::Authority)
    $parameters = @{
        Blob = $blobPath
        Container = $blobUri.AbsolutePath.Split('/')[1]
        Destination = $file.FullName
        Context = New-AzStorageContext -BlobEndpoint $blobEndpoint -UseConnectedAccount
        Force = $true   
    }
    Get-AzStorageBlobContent @parameters
    
    Write-Information "Uploading blob to S3..."
    $parameters = @{
        BucketName = $env:S3_BUCKET_NAME
        Key        = "$($env:S3_DIRECTORY_NAME)/$blobPath"
        File       = $file.FullName
        AccessKey  = $env:S3_ACCESS_KEY
        SecretKey  = $env:S3_SECRET_KEY
    }
    Write-S3Object @parameters

    Write-Information "Deleting file..."
    Remove-Item -Path $file.FullName
}