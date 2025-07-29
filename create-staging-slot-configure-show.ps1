. .\source.ps1  # Reference your variable file

az acr update -n $ACR_NAME --admin-enabled true

# 1. Create staging slot if it doesn't exist (idempotent)
az functionapp deployment slot create `
  --name $FUNCTION_APP_NAME `
  --resource-group $RG_NAME `
  --slot staging

# 2. Configure ACR authentication and container image for the staging slot
az functionapp config container set `
  --name $FUNCTION_APP_NAME `
  --resource-group $RG_NAME `
  --slot staging `
  --image $FULL_IMAGE_NAME `
  --registry-username $(az acr credential show -n $ACR_NAME --query username -o tsv) `
  --registry-password $(az acr credential show -n $ACR_NAME --query passwords[0].value -o tsv)

# 3. Show function hostname and function keys for the staging slot
Start-Sleep -Seconds 5
az functionapp show --name $FUNCTION_APP_NAME --resource-group $RG_NAME --slot staging --query defaultHostName -o tsv
az functionapp function keys list --function-name $FUNCTION_NAME --name $FUNCTION_APP_NAME --resource-group $RG_NAME --slot staging

# 4. Set traffic routing (idempotent)
az functionapp deployment slot traffic-routing set `
  --name $FUNCTION_APP_NAME `
  --resource-group $RG_NAME `
  --distribution "staging=$STAGE_PERCENT"
  