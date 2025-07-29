# create-docker-image-and-local-container.ps1

. .\source.ps1  # Dot-source the variables file
$targetPath = Join-Path $PSScriptRoot $PROJECT_FOLDER

$originalDir = Get-Location
try {
    Set-Location "${PSScriptRoot}\${PROJECT_FOLDER}"

    Write-Host "docker build -t $IMAGE_NAME:v2 ."
    Write-Host "docker run -p ${HOST_PORT_V2}:${CONTAINER_PORT} --name $CONTAINER_NAME $IMAGE_NAME:v2"

    dotnet publish -c Release -o "./$PUBLISH_OUTPUT"
    docker build -t $IMAGE_NAME:v2 .                                    
    docker run -p "${HOST_PORT_V2}:${CONTAINER_PORT}" --name $CONTAINER_NAME $IMAGE_NAME:v2
}
catch {
    Write-Error "Script failed: $_"
}
finally {
    Set-Location $originalDir
}