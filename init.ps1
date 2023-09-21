# Add the following line at the beginning of the script to set the error action preference.
$ErrorActionPreference = "Stop"

# Define the path to the current folder
$currentFolder = Get-Location

# Combine the current folder path with the .git folder name to get the full path
$gitFolderPath = Join-Path -Path $currentFolder -ChildPath ".git"

# Check if the .git folder already exists
if (Test-Path -Path $gitFolderPath -PathType Container) {
    Write-Host "The .git folder already exists in the current folder."
}
else {
    # .git folder does not exist, create it
    git init
    Write-Host "The .git folder has been created in the current folder."
}

# Get the name of the current directory
$currentDirectory = Get-Item (Get-Location).Path | Select-Object -ExpandProperty Name
$rootDirectory = $currentDirectory

# Define the solution name based on the current directory name
$solutionName = $currentDirectory

# Create the solution
dotnet new sln -n $solutionName

# Define project names, their respective types, directories, and references
$projects = @{
    "Application"    = @{
        "Type"       = "classlib"
        "Directory"  = "src\Application"
        "References" = @("src\Domain\Domain.csproj")
        "Args"       = ""
    }
    "Domain"         = @{
        "Type"       = "classlib"
        "Directory"  = "src\Domain"
        "References" = @()
        "Args"       = ""
    }
    "Infrastructure" = @{
        "Type"       = "classlib"
        "Directory"  = "src\Infrastructure"
        "References" = @("src\Domain\Domain.csproj")
        "Args"       = ""
    }
    "Presentation"   = @{
        "Type"       = "classlib"
        "Directory"  = "src\Presentation"
        "References" = @("src\Application\Application.csproj")
        "Args"       = ""
    }
    "Web"            = @{
        "Type"       = "webapi"
        "Directory"  = "src\Web"
        "References" = @("src\Presentation\Presentation.csproj", "src\Infrastructure\Infrastructure.csproj")
        "Args"       = "-minimal"
    }
    "Tests"          = @{
        "Type"       = "xunit"
        "Directory"  = "tests"
        "References" = @("src\Web\Web.csproj")
        "Args"       = ""
    }
}

# Create and add projects to the solution
foreach ($projectName in $projects.Keys) {
    $projectType = $projects[$projectName]["Type"]
    $projectDirectory = $projects[$projectName]["Directory"]
    $createArgs = $projects[$projectName]["Args"]

    # Create the project
    dotnet new $projectType -n $projectName -o $projectDirectory

    Write-Host "Created $projectName ($projectType)."
}

foreach ($projectName in $projects.Keys) {
    $projectDirectory = $projects[$projectName]["Directory"]
 
    # Add the project to the solution
    dotnet sln add $projectDirectory\$projectName.csproj

    Write-Host "added $projectName ($projectType) to the solution."
}

foreach ($projectName in $projects.Keys) {
    $projectDirectory = $projects[$projectName]["Directory"]
 
    # Add project references
    foreach ($reference in $projects[$projectName]["References"]) {
        dotnet add $projectDirectory\$projectName.csproj reference $reference
    }

    Write-Host "added $projectName ($projectType) to the solution."
}

# Display a message with the solution file location
Write-Host "Solution created at: $rootDirectory\$solutionName.sln"

# Install NuGet packages in each project
$nugetPackages = @{
    "Application"    = @("MediatR", "FluentValidation.DependencyInjectionExtensions")
    "Domain"         = @("Microsoft.EntityFrameworkCore")
    "Infrastructure" = @("Microsoft.Extensions.DependencyInjection.Abstractions")
    "Presentation"   = @("Carter", "Microsoft.Extensions.DependencyInjection.Abstractions")
    "Web"            = @("Serilog.AspNetCore")
    "Tests"          = @("FluentAssertions")
}

foreach ($projectName in $nugetPackages.Keys) {
    $projectDirectory = $projects[$projectName]["Directory"]
    
    # Install NuGet packages for the project
    foreach ($packageName in $nugetPackages[$projectName]) {
        dotnet add $projectDirectory\$projectName.csproj package $packageName
        Write-Host "Installed $packageName in $projectName project."
    }
}

$webProjectPath = "src\Web\Web.csproj"

# Define the name of the Tests project
$testsProjectName = "Tests"

# Define the content to add to the Web project's .csproj file
$internalsVisibleToContent = @"
  <ItemGroup>
    <InternalsVisibleTo Include="$testsProjectName">
      <AssemblyOriginatorKeyFile>Key.snk</AssemblyOriginatorKeyFile>
    </InternalsVisibleTo>
  </ItemGroup>
"@

# Define the content to be replaced
$replacementContent = @"
$internalsVisibleToContent
</Project>
"@

# Read the content of the Web.csproj file
$webProjectContent = Get-Content -Path $webProjectPath -Raw

# Replace the </Project> tag with the $replacementContent
$webProjectContent = $webProjectContent -replace '</Project>', $replacementContent

# Write the modified content back to the Web.csproj file
$webProjectContent | Set-Content -Path $webProjectPath

Write-Host "Added InternalsVisibleTo for $testsProjectName in Web.csproj."

$programPath = "src\Web\Program.cs"

$serilogContent = @"
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((context, configuration) => 
    configuration.ReadFrom.Configuration(context.Configuration));

"@

$replacementOf = @"
var builder = WebApplication.CreateBuilder(args);
"@

# Read the content of the Web.csproj file
$programContent = Get-Content -Path $programPath -Raw

# Replace the </Project> tag with the $replacementContent
$programContent = $programContent -replace $replacementOf, $serilogContent

# Write the modified content back to the Web.csproj file
$programContent | Set-Content -Path $programPath

Write-Host "Added Serilog to $programPath"