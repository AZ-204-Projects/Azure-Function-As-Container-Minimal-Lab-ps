# Azure-Function-As-Container-Minimal-Lab-ps

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

$RG_NAME         = "az-204-func-container-staging-rg"
$LOCATION        = "westus"
$STORAGE_NAME    = "containerstorage0729am"  # put something unique here
$PLAN_NAME       = "container-app-plan"
$PROJECT_FOLDER  = "ContainerFunctionProj"
$FUNCTION_APP_NAME = "acr-func-app"
$FUNCTION_NAME   = "ContainerFunction"
$PUBLISH_OUTPUT  = "publish_output"
$IMAGE_TAG       = "v2.0.0"  #change for new version
$IMAGE_NAME      = "container-func-img"
$CONTAINER_NAME  = "container-func-name${IMAGE_TAG}"
$HOST_PORT       = 7075  # used in local Docker Desktop 
$CONTAINER_PORT  = 80    # used in local Docker Desktop 

# ACR-specific
$ACR_NAME        = "containerreg0729am"  # put something unique here
$ACR_LOGIN_SVR   = "$ACR_NAME.azurecr.io"
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

#### Create a script to scaffold a new Azure Function (.NET Core) with an HTTP Trigger (`init-function.ps1`) and run it.

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

> **Note:** If you want to test your Docker-hosted container with an Azure Function, you'll need to temporarily change the `AuthorizationLevel` to `"Anonymous"` for local Docker testing.  
> Then revert it to `"Function"` and run the script again to restore a secure state for ACR testing.  If you do change the `AuthorizationLevel` to `"Anonymous"` and then need to revert it and re-run the create-docker-image-and-local-container.ps1 script, I suggest you delete both the container and the image in Docker Desktop before re-running the script.
> Yes, this is cumbersome — at this time, all known alternatives have other consequences.  
> You can alternatively **skip** testing the function in local Docker hosting.
>
> **Original (for ACR):**  
> `[HttpTrigger(AuthorizationLevel.Function, "get", "post", Route = null)] HttpRequest req`
>
> **Temporary (for local Docker):**  
> `[HttpTrigger(AuthorizationLevel.Anonymous, "get", "post", Route = null)] HttpRequest req`
         
         
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

Local Docker Desktop hosted api can be tested at (only if AuthorizationLevel set to "Anonymous"): http://localhost:7075/api/ContainerFunction

> **Note:** If `AuthorizationLevel` is NOT set to `"Anonymous"` then "HTTP ERROR 401" for Unauthorized is the correct and expected response.  Good job!  Continue with the next step!  But... at this point, my VS Code terminal is usually locked by the Docker Desktop hosting process.  There are two easy solutions: (1) use Docker Desktop to stop the container (you do not need it!) or (2) open another terminal in VS Code.  The advertised "Press Ctrl+C to shut down" never works for me.


### 4. Resource Group, ACR, push, 

#### Create a script to create a Azure Resource Group, and ACR and push the image from Docker Desktop to the ACR container (`publish-to-acr.ps1`) and run it.

```powershell name=publish-to-acr.ps1

. .\source.ps1  # reference the variables

# Create Resource Group (idempotent)
az group create --name $RG_NAME --location $LOCATION

# Create ACR (idempotent)
az acr create --resource-group $RG_NAME --name $ACR_NAME --sku Basic

# Login to ACR (idempotent)
az acr login --name $ACR_NAME

# Tag Docker Image (idempotent, but check existence for clarity)
$imageExists = docker images -q $IMAGE_NAME
if (-not $imageExists) {
    Write-Error "Local image $IMAGE_NAME not found. Build it before running this script."
    exit 1
}
docker tag $IMAGE_NAME $FULL_IMAGE_NAME

# Push Image (idempotent: Docker skips unchanged layers)
docker push $FULL_IMAGE_NAME

```
#### Run the script
.\publish-to-acr.ps1


### 5. Resource Group, ACR, push, 

#### Create a script to create a Azure Resource Group, and ACR and push the image from Docker Desktop to the ACR container (`publish-to-acr.ps1`) and run it.

```powershell name=create-function-app-configure-show.ps1

. .\source.ps1  # Reference your variable file

# Enable ACR admin (idempotent)
az acr update -n $ACR_NAME --admin-enabled true

# Create Storage Account (idempotent)
az storage account create --name $STORAGE_NAME --location $LOCATION --resource-group $RG_NAME --sku Standard_LRS

# Create Function App Plan
az functionapp plan create `
  --name $PLAN_NAME `
  --resource-group $RG_NAME `
  --location $LOCATION `
  --number-of-workers 1 `
  --sku EP1 `
  --is-linux

# Create (or update) Function App 
az functionapp create `
  --name $FUNCTION_APP_NAME `
  --storage-account $STORAGE_NAME `
  --resource-group $RG_NAME `
  --plan $PLAN_NAME `
  --image $FULL_IMAGE_NAME `
  --functions-version 4 `
  --os-type Linux `
  --runtime custom

# Configure ACR authentication for Function App
az functionapp config container set `
  --name $FUNCTION_APP_NAME `
  --resource-group $RG_NAME `
  --image $FULL_IMAGE_NAME `
  --registry-username $(az acr credential show -n $ACR_NAME --query username -o tsv) `
  --registry-password $(az acr credential show -n $ACR_NAME --query passwords[0].value -o tsv)

# Show function and key in log or terminal
   Start-Sleep -Seconds 5
   az functionapp show --name $FUNCTION_APP_NAME --resource-group $RG_NAME --query defaultHostName -o tsv
   az functionapp function keys list --function-name $FUNCTION_NAME --name $FUNCTION_APP_NAME --resource-group $RG_NAME

```
#### Run the script
.\create-function-app-configure-show.ps1

**Best Practice:**  
- Never commit secrets or keys to source control.
- Rotate keys periodically and use Azure Key Vault for production usage.

### 6. Test API from browser 

```
https://container-traffic-func-app.azurewebsites.net/api/ContainerTrafficFunction?code=<the code>&name=<some text>
```

---

## Done with deploying first version!  
You now have a minimal "Hello World" Azure Function deployed as a container.



## Deploying New Versions and Using Staging Slots

The next steps are to make some changes to the Azure Function (to simulate new features) and push to ACR with a new version number.

Take note of how much work the IMAGE_TAG var and the other vars in source.ps1 and idempotency are doing here. We get to reuse most of our scripts with no change in the update process !

### 7. Update and push a new version

- Make code changes to the Azure Function (could be as simple as changing a returned string to contain the new version number).
- Update `IMAGE_TAG` in `source.ps1` (e.g., from `"v2.0.0"` to `"v2.0.1"`).
- Re-run:
  - `.\create-docker-image-and-local-container.ps1`
  - `.\publish-to-acr.ps1`

Your Azure Container Registry (ACR) now contains both image versions (check in the portal container registry page under Services/Repositories ):
- `v2.0.0` (previous)
- `v2.0.1` (latest)

### 8. Create and Run a script to create a staging slot and deploy the new version


```powershell name=create-staging-slot-configure-show.ps1

. .\source.ps1  # Reference your variable file

# Enable ACR admin (idempotent)
az acr update -n $ACR_NAME --admin-enabled true

# Create staging slot if it doesn't exist (idempotent)
az functionapp deployment slot create `
  --name $FUNCTION_APP_NAME `
  --resource-group $RG_NAME `
  --slot staging

# Configure ACR authentication and container image for the staging slot
az functionapp config container set `
  --name $FUNCTION_APP_NAME `
  --resource-group $RG_NAME `
  --slot staging `
  --image $FULL_IMAGE_NAME `
  --registry-username $(az acr credential show -n $ACR_NAME --query username -o tsv) `
  --registry-password $(az acr credential show -n $ACR_NAME --query passwords[0].value -o tsv)

# Show function hostname and function keys for the staging slot
Start-Sleep -Seconds 5
az functionapp show --name $FUNCTION_APP_NAME --resource-group $RG_NAME --slot staging --query defaultHostName -o tsv
az functionapp function keys list --function-name $FUNCTION_NAME --name $FUNCTION_APP_NAME --resource-group $RG_NAME --slot staging

```
#### Run the script
.\create-staging-slot-configure-show.ps1

### 9. Test the staging slot and prod slot

- Invoke your function at:  
  `https://<functionappname>-staging.azurewebsites.net/api/ContainerFunction?...`
- Validate all new functionality.

- Invoke your old function at:  
  `https://<functionappname>.azurewebsites.net/api/ContainerFunction?...`
- Validate all old functionality (it is still here).


### 10. Create and Run the script to Swap staging to production

```powershell
. .\source.ps1  # Reference your variable file

az functionapp deployment slot swap `
  --name $FUNCTION_APP_NAME `
  --resource-group $RG_NAME `
  --slot staging

```
#### Run the script
.\slot-swap.ps1 

- This promotes the staging slot (with v2.0.1) to production.
- The previous production version is now in the staging slot (easy rollback).

### 11. Test the staging slot and prod slot

- Invoke your function at:  
  `https://<functionappname>-staging.azurewebsites.net/api/ContainerFunction?...`
- Validate all new functionality.  (prod v2.0.0 should be back here again!)

- Invoke your function at:  
  `https://<functionappname>.azurewebsites.net/api/ContainerFunction?...`
- Validate all old functionality. (new version 2.0.1 should be here now)


### 12. Rollback to previous version (if needed)

Just run .\slot-swap.ps1 again and test the endpoints again.

