. .\source.ps1  # Reference your variable file

az functionapp config container show `
  --name $FUNCTION_APP_NAME `
  --resource-group $RG_NAME 
