# init-function.ps1
func init HelloFunctionProj --worker-runtime dotnet --target-framework net8.0

$originalDir = Get-Location
try {
    Set-Location "$PSScriptRoot\HelloFunctionProj"
   func new --name HelloFunction --template "HTTP trigger"
}
catch {
    Write-Error "Script failed: $_"
}
finally {
    Set-Location $originalDir
}