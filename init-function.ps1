# init-function.ps1

. .\source.ps1  # Dot-source the variables file
$targetPath = Join-Path $PSScriptRoot $PROJECT_FOLDER
if (Test-Path $targetPath) {
    Write-Error "The project folder '$targetPath' already exists. Please clean up (delete or rename) before running this script again."
    exit 1
}


func init "$PROJECT_FOLDER" --worker-runtime dotnet --target-framework net8.0

$originalDir = Get-Location
try {
    Set-Location "${PSScriptRoot}\${PROJECT_FOLDER}"
   func new --name "$FUNCTION_NAME" --template "HTTP trigger"



       # Define Dockerfile content
    $dockerFileContent = @"
FROM mcr.microsoft.com/azure-functions/dotnet-isolated:4 AS base
WORKDIR /home/site/wwwroot
COPY ./$PUBLISH_OUTPUT ./
"@

    # Create or overwrite Dockerfile
    Set-Content -Path "Dockerfile" -Value $dockerFileContent -Encoding UTF8
}
catch {
    Write-Error "Script failed: $_"
}
finally {
    Set-Location $originalDir
}