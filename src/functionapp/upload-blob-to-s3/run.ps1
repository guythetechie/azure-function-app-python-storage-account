param($QueueItem)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$QueueItem | ForEach-Object {
    $item = $_
    Write-Information "Processing item: $($item.data.url)"

    Write-Information "Creating download folder..."
    $folderPath = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
    New-Item -ItemType Directory -Path $folderPath -Force | Out-Null

    Write-Information "Downloading blob from Azure Blob Storage..."
    $blobUri = [System.Uri]::new($item.data.url)
    $fileName = $blobUri.AbsolutePath.Split('/')[-1]
    $filePath = Join-Path $folderPath $fileName
    $parameters = @{
        Blob = $fileName
        Container = $blobUri.AbsolutePath.Split('/')[-2]
        Destination = $filePath
        Context = New-AzStorageContext -BlobEndpoint $blobUri.AbsoluteUri -UseConnectedAccount
    }
    Get-AzStorageBlobContent @parameters
    
    Write-Information "Uploading blob to S3..."
    $parameters = @{
        BucketName = $env:S3_BUCKET_NAME
        Key        = "$($env:S3_DIRECTORY_NAME)/$fileName"
        File       = $filePath
        AccessKey  = $env:S3_ACCESS_KEY
        SecretKey  = $env:S3_SECRET_KEY
    }
    Write-S3Object @parameters

    Write-Information "Deleting download folder..."
    Remove-Item -Path $folderPath -Recurse -Force
}