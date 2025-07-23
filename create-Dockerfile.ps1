# Save the original directory
$originalDir = Get-Location

try {
    # Change to the target project directory
    Set-Location "$PSScriptRoot\HelloFunctionProj"

    # Define Dockerfile content
    $dockerFileContent = @"
FROM mcr.microsoft.com/azure-functions/dotnet-isolated:4-dotnet8
WORKDIR /home/site/wwwroot
COPY . .
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