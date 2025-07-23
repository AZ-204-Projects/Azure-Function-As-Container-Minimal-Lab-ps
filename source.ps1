# source.ps1

$RG_NAME      = "az-204-function-container-lab-rg"
$LOCATION     = "westus"
$FUNC_NAME    = "HelloWorld"
$IMAGE_NAME   = "hello-func"
$ACR_NAME     = "hello-acr"
$STORAGE_NAME = "functioncontainerstorage0823am"

# Try to get subscription ID from environment variable, otherwise fetch from Azure CLI
if ($env:AZURE_SUBSCRIPTION_ID) {
    $SUBSCRIPTION_ID = $env:AZURE_SUBSCRIPTION_ID
} else {
    $SUBSCRIPTION_ID = (az account show --query id -o tsv)
}

Write-Host "Resource Group:  $RG_NAME"
Write-Host "Location:        $LOCATION"
Write-Host "Function Name:   $FUNC_NAME"
Write-Host "Image Name:      $IMAGE_NAME"
Write-Host "ARC Name:        $ACR_NAME"
Write-Host "Storage Account: $STORAGE_NAME"
Write-Host "Subscription ID: $SUBSCRIPTION_ID"