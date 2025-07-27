# create-docker-image-and-local-container.ps1

. .\source.ps1  # Dot-source the variables file
$targetPath = Join-Path $PSScriptRoot $PROJECT_FOLDER

$originalDir = Get-Location
try {
    Set-Location "${PSScriptRoot}\${PROJECT_FOLDER}"
    dotnet publish -c Release -o "./$PUBLISH_OUTPUT"
    docker build -t $IMAGE_NAME .
    docker run -p "${HOST_PORT}:${CONTAINER_PORT}" --name $CONTAINER_NAME $IMAGE_NAME
    # Wait for the container to start (optional, but recommended)
    #Start-Sleep -Seconds 5

    #docker exec $CONTAINER_NAME func keys set $FUNCTION_NAME $KEY_NAME --value $KEY_VALUE
}
catch {
    Write-Error "Script failed: $_"
}
finally {
    Set-Location $originalDir
}