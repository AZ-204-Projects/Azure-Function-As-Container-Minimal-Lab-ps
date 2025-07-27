# source.ps1

$RG_NAME         = "az-204-container-traffic-lab-rg"
$LOCATION        = "westus"
$STORAGE_NAME    = "containerstorage0726am"
$PROJECT_FOLDER  = "ContainerTrafficFunctionProj"
$FUNCTION_NAME   = "ContainerTrafficFunction"
$PUBLISH_OUTPUT  = "publish_output"
$IMAGE_NAME      = "container-traffic-func-img"
$CONTAINER_NAME  = "container-traffic-func-name"
$HOST_PORT       = 7075
$CONTAINER_PORT  = 80
$KEY_NAME        = "dev-key"
$KEY_VALUE       = "supersecretkey"

# ACR-specific
$ACR_NAME        = "container-traffic-reg"
$ACR_LOGIN_SVR   = "$ACR_NAME.azurecr.io"
$IMAGE_TAG       = "v1.0.0"
$FULL_IMAGE_NAME = "${ACR_LOGIN_SVR}/${IMAGE_NAME}:${IMAGE_TAG}"

# Try to get subscription ID from environment variable, otherwise fetch from Azure CLI
if ($env:AZURE_SUBSCRIPTION_ID) {
    $SUBSCRIPTION_ID = $env:AZURE_SUBSCRIPTION_ID
} else {
    $SUBSCRIPTION_ID = (az account show --query id -o tsv)
}

Write-Host "Resource Group: $RG_NAME"
Write-Host "Location: $LOCATION"
Write-Host "Storage Account: $STORAGE_NAME"
Write-Host "Project Folder: $PROJECT_FOLDER"
Write-Host "Function Name: $FUNCTION_NAME"
Write-Host "Publish Output Folder: $PUBLISH_OUTPUT"
Write-Host "Image Name: $IMAGE_NAME"
Write-Host "Container Name: $CONTAINER_NAME"       
Write-Host "Host Port: $HOST_PORT"
Write-Host "Container Port: $CONTAINER_PORT"
Write-Host "Subscription ID: $SUBSCRIPTION_ID"
Write-Host "ACR Name: $ACR_NAME"
Write-Host "ACR Login Server: $ACR_LOGIN_SVR"
Write-Host "Full Image Name: $FULL_IMAGE_NAME"
