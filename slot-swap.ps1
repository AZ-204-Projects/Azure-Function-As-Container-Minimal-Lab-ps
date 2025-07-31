. .\source.ps1  # Reference your variable file

az functionapp deployment slot swap `
  --name $FUNCTION_APP_NAME `
  --resource-group $RG_NAME `
  --slot staging
