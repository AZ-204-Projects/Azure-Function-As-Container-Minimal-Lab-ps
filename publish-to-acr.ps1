
. .\source.ps1  # reference the variables

# 1. Create Resource Group (idempotent)
az group create --name $RG_NAME --location $LOCATION

# 2. Create ACR (idempotent)
az acr create --resource-group $RG_NAME --name $ACR_NAME --sku Basic

# 3. Login to ACR (idempotent)
az acr login --name $ACR_NAME

# 4. Tag Docker Image (idempotent, but check existence for clarity)
$imageExists = docker images -q $IMAGE_NAME
if (-not $imageExists) {
    Write-Error "Local image $IMAGE_NAME not found. Build it before running this script."
    exit 1
}
docker tag $IMAGE_NAME $FULL_IMAGE_NAME

# 5. Push Image (idempotent: Docker skips unchanged layers)
docker push $FULL_IMAGE_NAME
