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
$STORAGE_NAME    = "containerstorage0726am"

$PROJECT_FOLDER  = "ContainerTrafficFunctionProj"
$FUNCTION_NAME   = "ContainerTrafficFunction"
$PUBLISH_OUTPUT  = "publish_output"
$IMAGE_NAME      = "container-traffic-func-img"
$CONTAINER_NAME  = "container-traffic-func-name"
$HOST_PORT       = 7071
$CONTAINER_PORT  = 80

# ACR-specific
$ACR_NAME        = "container-traffic-reg"
$ACR_LOGIN_SVR   = "$ACR_NAME.azurecr.io"
$IMAGE_TAG       = "v1.0.0"
$FULL_IMAGE_NAME = "$ACR_LOGIN_SVR/$IMAGE_NAME:$IMAGE_TAG"

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

#Write-Host "Queue Name: $QUEUE_NAME"
#Write-Host "Topic Name: $TOPIC_NAME"

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







### 2. Add Dockerfile

#### Create script to Scaffold a Dockerfile (`create_Dockerfile.ps1`) and run it.

```powershell name=create_Dockerfile.ps1
# Save the original directory
$originalDir = Get-Location

try {
    # Change to the target project directory
    Set-Location "$PSScriptRoot\HelloFunctionProj"

    # Define Dockerfile content
    $dockerFileContent = @"
FROM mcr.microsoft.com/azure-functions/dotnet-isolated:4 AS base
WORKDIR /home/site/wwwroot
COPY ./publish_output ./
"@

    # Create or overwrite Dockerfile
    Set-Content -Path "Dockerfile" -Value $dockerFileContent -Encoding UTF8
}
catch {
    Write-Error "An error occurred: $_"
}
finally {
    # Restore the original directory
    Set-Location $originalDir
}
```
#### Run the script
.\create-Dockerfile.ps1

---









a

## 1. Create a Minimal Azure Function
b
```bash
# Create and enter a new folder
mkdir hello-func && cd hello-func

# Initialize a new Azure Functions project (C# example)
func init --worker-runtime dotnet --target-framework net6.0

# Add a new HTTP-triggered function
func new --template "HTTP trigger" --name HelloWorld
```

Edit the generated `HelloWorld.cs` to print "Hello World":

```csharp
[Function("HelloWorld")]
public static HttpResponseData Run(
    [HttpTrigger(AuthorizationLevel.Function, "get", "post")] HttpRequestData req,
    FunctionContext executionContext)
{
    var response = req.CreateResponse(HttpStatusCode.OK);
    response.WriteString("Hello World");
    return response;
}
```

---

## 2. Add a Dockerfile

Create a file named `Dockerfile` in the project root:

```dockerfile
FROM mcr.microsoft.com/azure-functions/dotnet:4-appservice
WORKDIR /home/site/wwwroot
COPY . .
```

---

## 3. Build and Test the Container Locally

```bash
# Build the Docker image
docker build -t hello-func .

# Run the container locally
docker run -p 8080:80 hello-func

# Test in your browser or with curl
curl http://localhost:8080/api/HelloWorld
```

---

## 4. Push the Image to Azure Container Registry (ACR)

```bash
# Log in to Azure
az login

# Create a resource group (if needed)
az group create --name myResourceGroup --location eastus

# Create an Azure Container Registry
az acr create --resource-group myResourceGroup --name myacr12345 --sku Basic

# Log in to ACR
az acr login --name myacr12345

# Tag your image for ACR
docker tag hello-func myacr12345.azurecr.io/hello-func:v1

# Push the image
docker push myacr12345.azurecr.io/hello-func:v1
```

---

## 5. Deploy the Containerized Function to Azure

```bash
# Create a storage account (required by Azure Functions)
az storage account create --name mystorage12345 --location eastus --resource-group myResourceGroup --sku Standard_LRS

# Create the function app using the custom container
az functionapp create I am running a few minutes late; my previous meeting is running over.



  --resource-group myResourceGroup \
  --name myhellofuncapp \
  --storage-account mystorage12345 \
  --plan myAppServicePlan \
  --deployment-container-image-name myacr12345.azurecr.io/hello-func:v1 \
  --functions-version 4 \
  --os-type Linux

# (Optional) Configure the function app to use ACR credentials
az functionapp config container set \
  --name myhellofuncapp \
  --resource-group myResourceGroup \
  --docker-registry-server-url https://myacr12345.azurecr.io \
  --docker-registry-server-user <ACR_USERNAME> \
  --docker-registry-server-password <ACR_PASSWORD>
```

Find your function's URL in the Azure Portal or by running:

```bash
az functionapp show --name myhellofuncapp --resource-group myResourceGroup --query defaultHostName
# Then: curl https://<defaultHostName>/api/HelloWorld
```

---

## Done!  
You now have a minimal "Hello World" Azure Function deployed as a container.
