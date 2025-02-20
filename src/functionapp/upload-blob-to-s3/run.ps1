param($QueueItem)

$QueueItem | ForEach-Object -Parallel {
    $item = $_

    Write-Information "Creating download folder..."
    $folderPath = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
    New-Item -ItemType Directory -Path $folderPath -Force

    Write-Information "Downloading blob from Azure Blob Storage..."
    $blobUrl = $item.data.url
    $fileName = $blobUrl.Split("/")[-1]
    $filePath = Join-Path $folderPath $fileName
    $parameters = @{
        AbsoluteUri = $blobUrl
        Destination = $filePath
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