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

