# Azure-Function-As-Container-Minimal-Lab-ps
Azure-Function-As-Container-Minimal-Lab-ps
# Minimal "Hello World" Azure Function Deployed as a Container

This guide will walk you through creating a minimal Azure Function ("Hello World"), containerizing it, and deploying it to Azure.

---

## Prerequisites

- **Azure CLI** ([Install Guide](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli))
- **Docker** ([Install Guide](https://www.docker.com/get-started))
- **.NET SDK** (for C# example) ([Install Guide](https://dotnet.microsoft.com/download))
- **Azure subscription**  
- **Git** (optional, for code versioning)

### 1. Create a `source.ps1` file for shared variables - modify variable contents as needed

```powershell name=source.ps1
# source.ps1

$RG_NAME         = "az-204-container-traffic-lab-rg"
$LOCATION        = "westus"
$STORAGE_NAME    = "containerstorage0727am"
$PLAN_NAME       = "container-app-plan"
$PROJECT_FOLDER  = "ContainerTrafficFunctionProj"
$FUNCTION_APP_NAME   = "container-traffic-func-app"
$FUNCTION_NAME   = "ContainerTrafficFunction"
$PUBLISH_OUTPUT  = "publish_output"
$IMAGE_NAME      = "container-traffic-func-img"
$CONTAINER_NAME  = "container-traffic-func-name"
$HOST_PORT       = 7075
$CONTAINER_PORT  = 80

# ACR-specific
$ACR_NAME        = "containertrafficreg0727am"
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
Write-Host "Plan Name: $PLAN_NAME"
Write-Host "Project Folder: $PROJECT_FOLDER"
Write-Host "Function App Name: $FUNCTION_APP_NAME"
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


```

### 2. Application Setup

#### Create a script to scaffold a new Azure Function (.NET) with an HTTP Trigger (`init-function.ps1`) and run it.

```powershell name=init-function.ps1
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
```
#### Run the script
.\init-function.ps1




### 3. Docker Setup and Run Locally

#### Create a script to create the Docker image and the Docker container locally and run the Docker container locally (`create-docker-image-and-local-container.ps1`) and run it.

```powershell name=create-docker-image-and-local-container.ps1
# create-docker-image-and-local-container.ps1

. .\source.ps1  # Dot-source the variables file
$targetPath = Join-Path $PSScriptRoot $PROJECT_FOLDER

$originalDir = Get-Location
try {
    Set-Location "${PSScriptRoot}\${PROJECT_FOLDER}"
    dotnet publish -c Release -o "./$PUBLISH_OUTPUT"
    docker build -t $IMAGE_NAME .
    docker run -p "${HOST_PORT}:${CONTAINER_PORT}" --name $CONTAINER_NAME $IMAGE_NAME
}
catch {
    Write-Error "Script failed: $_"
}
finally {
    Set-Location $originalDir
}
```
#### Run the script
.\create-docker-image-and-local-container.ps1

local Docker Desktop hosted api can be tested at: http://localhost:7075/api/ContainerTrafficFunction


### 4. Resource Group, ACR, push, 

#### Create a script to create a Azure Resource Group, and ACR and push the image from Docker Desktop to the ACR container (`publish-to-acr.ps1`) and run it.

```powershell name=publish-to-acr.ps1

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

```
#### Run the script
.\publish-to-acr.ps1




### 5. Resource Group, ACR, push, 

#### Create a script to create a Azure Resource Group, and ACR and push the image from Docker Desktop to the ACR container (`publish-to-acr.ps1`) and run it.

```powershell name=create-function-app-configure-show.ps1

. .\source.ps1  # Reference your variable file

# 1. Enable ACR admin (idempotent)
az acr update -n $ACR_NAME --admin-enabled true

# 2. Create Storage Account (idempotent)
az storage account create --name $STORAGE_NAME --location $LOCATION --resource-group $RG_NAME --sku Standard_LRS

# 3. Create Function App Plan
az functionapp plan create `
  --name $PLAN_NAME `
  --resource-group $RG_NAME `
  --location $LOCATION `
  --number-of-workers 1 `
  --sku EP1 `
  --is-linux

# 4. Create (or update) Function App 
az functionapp create `
  --name $FUNCTION_APP_NAME `
  --storage-account $STORAGE_NAME `
  --resource-group $RG_NAME `
  --plan $PLAN_NAME `
  --image $FULL_IMAGE_NAME `
  --functions-version 4 `
  --os-type Linux `
  --runtime custom

# 5. Configure ACR authentication for Function App
az functionapp config container set `
  --name $FUNCTION_APP_NAME `
  --resource-group $RG_NAME `
  --image $FULL_IMAGE_NAME `
  --registry-username $(az acr credential show -n $ACR_NAME --query username -o tsv) `
  --registry-password $(az acr credential show -n $ACR_NAME --query passwords[0].value -o tsv)

# 6. Show function and key in log or terminal
   Start-Sleep -Seconds 5
   az functionapp show --name $FUNCTION_APP_NAME --resource-group $RG_NAME --query defaultHostName -o tsv
   az functionapp function keys list --function-name $FUNCTION_NAME --name $FUNCTION_APP_NAME --resource-group $RG_NAME


```
#### Run the script
.\create-function-app-configure-show.ps1

**Best Practice:**  
- Never commit secrets or keys to source control.
- Rotate keys periodically and use Azure Key Vault for production usage.

### 5. Test API from browser 

```
https://container-traffic-func-app.azurewebsites.net/api/ContainerTrafficFunction?code=<the code>&name=<some text>
```

---

## Done!  
You now have a minimal "Hello World" Azure Function deployed as a container.




