# Azure-Function-As-Container-Minimal-Lab-ps

## Deploying Azure Functions as Containers: Professional Minimal Lab with Slot Swapping

This guide demonstrates a professional, best-practice approach for creating, containerizing, and deploying a minimal Azure Function, then updating it using deployment slots and Azure Container Registry (ACR).  
Its goals:
- Showcase robust, repeatable deployment patterns on GitHub.
- Enable cost-effective management of Azure resources, allowing confident deletion and recreation.
- Support learning and preparation for the AZ-204 certification.

---

## Prerequisites

Before starting, ensure you have the following tools installed:

- **Azure CLI** ([Installation Guide](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli))
- **Docker** ([Installation Guide](https://www.docker.com/get-started))
- **.NET SDK** for C# examples ([Installation Guide](https://dotnet.microsoft.com/download))
- **An active Azure subscription**
- **Git** (recommended for source control)

---

## Step 1: Centralize Variables for Repeatability

Create a `source.ps1` file containing all environment variables. Update values as needed for your environment.

> Centralizing variables promotes maintainability and repeatable automation.

```powershell name=source.ps1
# source.ps1

# All configuration variables in one place
$RG_NAME         = "az-204-func-container-staging-rg"
$LOCATION        = "westus"
$STORAGE_NAME    = "containerstorage0729am"  # Unique value recommended
$PLAN_NAME       = "container-app-plan"
$PROJECT_FOLDER  = "ContainerFunctionProj"
$FUNCTION_APP_NAME = "acr-func-app"
$FUNCTION_NAME   = "ContainerFunction"
$PUBLISH_OUTPUT  = "publish_output"
$IMAGE_TAG       = "v2.0.0"  # Update for each new version
$IMAGE_NAME      = "container-func-img"
$CONTAINER_NAME  = "container-func-name${IMAGE_TAG}"
$HOST_PORT       = 7075      # For local Docker testing
$CONTAINER_PORT  = 80        # For local Docker testing

# ACR-specific
$ACR_NAME        = "containerreg0729am"  # Unique value recommended
$ACR_LOGIN_SVR   = "$ACR_NAME.azurecr.io"
$FULL_IMAGE_NAME = "${ACR_LOGIN_SVR}/${IMAGE_NAME}:${IMAGE_TAG}"

# Subscription ID handling
if ($env:AZURE_SUBSCRIPTION_ID) {
    $SUBSCRIPTION_ID = $env:AZURE_SUBSCRIPTION_ID
} else {
    $SUBSCRIPTION_ID = (az account show --query id -o tsv)
}

# Output configuration for transparency and troubleshooting
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

---

## Step 2: Scaffold a Minimal Azure Function with HTTP Trigger

Use the provided script to initialize your function application.

```powershell name=init-function.ps1
# init-function.ps1

. .\source.ps1
$targetPath = Join-Path $PSScriptRoot $PROJECT_FOLDER
if (Test-Path $targetPath) {
    Write-Error "The project folder '$targetPath' already exists. Clean up before proceeding."
    exit 1
}

func init "$PROJECT_FOLDER" --worker-runtime dotnet --target-framework net8.0

$originalDir = Get-Location
try {
    Set-Location "${PSScriptRoot}\${PROJECT_FOLDER}"
    func new --name "$FUNCTION_NAME" --template "HTTP trigger"

    # Define Dockerfile
    $dockerFileContent = @"
FROM mcr.microsoft.com/azure-functions/dotnet-isolated:4 AS base
WORKDIR /home/site/wwwroot
COPY ./$PUBLISH_OUTPUT ./
"@
    Set-Content -Path "Dockerfile" -Value $dockerFileContent -Encoding UTF8
}
catch {
    Write-Error "Script failed: $_"
}
finally {
    Set-Location $originalDir
}
```

> **Run:**  
> `.\init-function.ps1`

---

## Step 3: Build and Test Locally with Docker

Containerize your function and run it locally.

```powershell name=create-docker-image-and-local-container.ps1
# create-docker-image-and-local-container.ps1

. .\source.ps1
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

> **Run:**  
> `.\create-docker-image-and-local-container.ps1`

**Local Testing Notes:**  
- For local API testing, set `AuthorizationLevel` to `"Anonymous"` in your function's attribute.  
- For production, revert to `"Function"` to enforce security.
- If your terminal is locked by Docker, stop the container via Docker Desktop or open a new terminal.

---

## Step 4: Provision Resources and Push Image to Azure Container Registry (ACR)

Automate resource creation and image publishing.

```powershell name=publish-to-acr.ps1
. .\source.ps1

az group create --name $RG_NAME --location $LOCATION
az acr create --resource-group $RG_NAME --name $ACR_NAME --sku Basic
az acr login --name $ACR_NAME

$imageExists = docker images -q $IMAGE_NAME
if (-not $imageExists) {
    Write-Error "Local image $IMAGE_NAME not found. Build before continuing."
    exit 1
}
docker tag $IMAGE_NAME $FULL_IMAGE_NAME
docker push $FULL_IMAGE_NAME
```

> **Run:**  
> `.\publish-to-acr.ps1`

---

## Step 5: Configure and Deploy Azure Function from Container Image

Automate deployment and configuration.

```powershell name=create-function-app-configure-show.ps1
. .\source.ps1

az acr update -n $ACR_NAME --admin-enabled true
az storage account create --name $STORAGE_NAME --location $LOCATION --resource-group $RG_NAME --sku Standard_LRS

az functionapp plan create `
  --name $PLAN_NAME `
  --resource-group $RG_NAME `
  --location $LOCATION `
  --number-of-workers 1 `
  --sku EP1 `
  --is-linux

az functionapp create `
  --name $FUNCTION_APP_NAME `
  --storage-account $STORAGE_NAME `
  --resource-group $RG_NAME `
  --plan $PLAN_NAME `
  --image $FULL_IMAGE_NAME `
  --functions-version 4 `
  --os-type Linux `
  --runtime custom

az functionapp config container set `
  --name $FUNCTION_APP_NAME `
  --resource-group $RG_NAME `
  --image $FULL_IMAGE_NAME `
  --registry-username $(az acr credential show -n $ACR_NAME --query username -o tsv) `
  --registry-password $(az acr credential show -n $ACR_NAME --query passwords[0].value -o tsv)

Start-Sleep -Seconds 5
az functionapp show --name $FUNCTION_APP_NAME --resource-group $RG_NAME --query defaultHostName -o tsv
az functionapp function keys list --function-name $FUNCTION_NAME --name $FUNCTION_APP_NAME --resource-group $RG_NAME
```

> **Run:**  
> `.\create-function-app-configure-show.ps1`

**Security Best Practices:**  
- Never commit secrets or keys to source control.
- Rotate keys regularly and use Azure Key Vault in production.

---

## Step 6: Test the Deployed Function

Access your function using the provided hostname and function key:

```
https://<function-app-host>.azurewebsites.net/api/ContainerFunction?code=<key>&name=<value>
```

---

## Step 7: Upgrading and Slot Deployment for Zero-Downtime Releases

To release a new version:

1. Update your function code (e.g., change the returned string/version).
2. Update `IMAGE_TAG` in `source.ps1` (e.g., `"v2.0.0"` → `"v2.0.1"`).
3. Re-run:
   - `.\create-docker-image-and-local-container.ps1`
   - `.\publish-to-acr.ps1`

Both versions are now available in ACR for deployment.

---

## Step 8: Create a Staging Slot and Deploy the New Version

Use slot deployment to enable safe upgrades and instant rollbacks.

```powershell name=create-staging-slot-configure-show.ps1
. .\source.ps1

az acr update -n $ACR_NAME --admin-enabled true

az functionapp deployment slot create `
  --name $FUNCTION_APP_NAME `
  --resource-group $RG_NAME `
  --slot staging

az functionapp config container set `
  --name $FUNCTION_APP_NAME `
  --resource-group $RG_NAME `
  --slot staging `
  --image $FULL_IMAGE_NAME `
  --registry-username $(az acr credential show -n $ACR_NAME --query username -o tsv) `
  --registry-password $(az acr credential show -n $ACR_NAME --query passwords[0].value -o tsv)

Start-Sleep -Seconds 5
az functionapp show --name $FUNCTION_APP_NAME --resource-group $RG_NAME --slot staging --query defaultHostName -o tsv
az functionapp function keys list --function-name $FUNCTION_NAME --name $FUNCTION_APP_NAME --resource-group $RG_NAME --slot staging
```

> **Run:**  
> `.\create-staging-slot-configure-show.ps1`

---

## Step 9: Validate Both Staging and Production Slots

- Test new functionality at  
  `https://<function-app-host>-staging.azurewebsites.net/api/ContainerFunction?...`
- Confirm production remains unchanged at  
  `https://<function-app-host>.azurewebsites.net/api/ContainerFunction?...`

---

## Step 10: Swap Staging and Production for Seamless Releases

Promote the new version with zero downtime and instant rollback capability.

```powershell name=slot-swap.ps1
. .\source.ps1

az functionapp deployment slot swap `
  --name $FUNCTION_APP_NAME `
  --resource-group $RG_NAME `
  --slot staging
```

> **Run:**  
> `.\slot-swap.ps1`

---

## Step 11: Test After Swap

- Staging slot now hosts the previous production version (easy rollback).
- Production slot now serves your latest deployment.

---

## Step 12: Rollback (if required)

Simply rerun the slot swap script to revert to the prior version.

---

## Professional Best Practices Demonstrated

- **Idempotent scripts:** All deployment actions can be safely repeated.
- **Variable centralization:** Promotes consistency and repeatability.
- **Containerization:** Enables rapid deployment, scaling, and rollback.
- **Slot deployment:** Zero downtime, safe release, instant rollback.
- **Security:** No secrets in source control; keys managed securely.
- **Documentation:** Clear, step-wise, and actionable instructions aligned with Azure and GitHub best practices.

---

## Summary

You have now implemented a robust process for building, containerizing, deploying, and managing Azure Functions using modern DevOps practices. This approach supports both cost-effective cloud management and practical learning for AZ-204.

---
