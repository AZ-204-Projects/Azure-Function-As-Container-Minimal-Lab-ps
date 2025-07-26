$originalDir = Get-Location

try {
    # Change to the target project directory
    Set-Location "$PSScriptRoot\HelloFunctionProj"

    # Publish the .NET function project
    dotnet publish -c Release -o ./publish

    # Define Dockerfile content that copies published output
    $dockerFileContent = @"
FROM mcr.microsoft.com/azure-functions/dotnet-isolated:4
WORKDIR /home/site/wwwroot
COPY publish/ .
"@

    # Create or overwrite Dockerfile
    Set-Content -Path "Dockerfile" -Value $dockerFileContent -Encoding UTF8

    # Build the Docker image
    docker build -t hello-func .

    # Run the Docker container
    docker run -p 8080:80 hello-func
}
catch {
    Write-Error "An error occurred: $_"
}
finally {
    # Restore the original directory
    Set-Location $originalDir
}