[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PackageDirectory,

    [Parameter(Mandatory = $true)]
    [string]$Version,

    [string[]]$TargetFrameworks = @('net8.0', 'net10.0'),

    [string]$DotNetCommand = 'dotnet'
)

$ErrorActionPreference = 'Stop'
$workspaceRoot = [System.IO.Path]::GetFullPath((Get-Location).Path) + [System.IO.Path]::DirectorySeparatorChar
$packageRoot = [System.IO.Path]::GetFullPath((Join-Path $workspaceRoot $PackageDirectory))
$consumerRoot = [System.IO.Path]::GetFullPath((Join-Path $workspaceRoot 'artifacts/package-consumer'))
$expectedPackages = @(
    'IdemShield.AspNetCore',
    'IdemShield.Redis',
    'IdemShield.SqlServer'
)
$repositoryUrl = 'https://github.com/Shivansh-Gaur2/IdemShield.NET'
$exactCoreVersion = "[$Version]"

if (-not (Test-Path -LiteralPath $packageRoot -PathType Container)) {
    throw "Package directory does not exist: $packageRoot"
}
if (-not $consumerRoot.StartsWith($workspaceRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Consumer workspace must stay inside the repository: $consumerRoot"
}

foreach ($packageId in $expectedPackages) {
    $packagePath = Join-Path $packageRoot "$packageId.$Version.nupkg"
    $symbolPath = Join-Path $packageRoot "$packageId.$Version.snupkg"
    if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) {
        throw "Missing package: $packagePath"
    }
    if (-not (Test-Path -LiteralPath $symbolPath -PathType Leaf)) {
        throw "Missing symbol package: $symbolPath"
    }

    $archive = [System.IO.Compression.ZipFile]::OpenRead($packagePath)
    try {
        $entries = $archive.Entries.FullName
        $requiredEntries = @('README.md', 'CHANGELOG.md') + @(
            foreach ($targetFramework in $TargetFrameworks) {
                "lib/$targetFramework/$packageId.dll"
                "lib/$targetFramework/$packageId.xml"
            }
        )
        foreach ($requiredEntry in $requiredEntries) {
            if ($entries -notcontains $requiredEntry) {
                throw "$packageId is missing '$requiredEntry'."
            }
        }

        $nuspecEntry = $archive.Entries | Where-Object { $_.FullName -like '*.nuspec' } | Select-Object -First 1
        if ($null -eq $nuspecEntry) {
            throw "$packageId does not contain a nuspec file."
        }
        $reader = [System.IO.StreamReader]::new($nuspecEntry.Open())
        try {
            [xml]$nuspec = $reader.ReadToEnd()
        }
        finally {
            $reader.Dispose()
        }

        if ($nuspec.package.metadata.id -ne $packageId) {
            throw "$packageId contains an unexpected package ID."
        }
        if ($nuspec.package.metadata.version -ne $Version) {
            throw "$packageId contains version '$($nuspec.package.metadata.version)' instead of '$Version'."
        }
        if ([string]::IsNullOrWhiteSpace($nuspec.package.metadata.title)) {
            throw "$packageId does not declare a package title."
        }
        if ($nuspec.package.metadata.authors -ne 'Shivansh Gaur') {
            throw "$packageId contains unexpected package authors."
        }
        if ([string]::IsNullOrWhiteSpace($nuspec.package.metadata.description)) {
            throw "$packageId does not declare a package description."
        }
        if ($nuspec.package.metadata.license.'#text' -ne 'MIT') {
            throw "$packageId does not declare the MIT license expression."
        }
        if ($nuspec.package.metadata.readme -ne 'README.md') {
            throw "$packageId does not declare README.md as its package readme."
        }
        if ($nuspec.package.metadata.projectUrl -ne $repositoryUrl) {
            throw "$packageId contains an unexpected project URL."
        }
        if ($nuspec.package.metadata.repository.url -ne $repositoryUrl) {
            throw "$packageId contains an unexpected repository URL."
        }
        if ([string]::IsNullOrWhiteSpace($nuspec.package.metadata.tags) -or
            $nuspec.package.metadata.tags -notmatch '(^|\s)idempotency(\s|$)') {
            throw "$packageId does not declare relevant package tags."
        }
        if ([string]::IsNullOrWhiteSpace($nuspec.package.metadata.releaseNotes)) {
            throw "$packageId does not declare release notes."
        }

        foreach ($targetFramework in $TargetFrameworks) {
            $dependencyGroup = @($nuspec.package.metadata.dependencies.group) |
                Where-Object { $_.targetFramework -eq $targetFramework }
            if (@($dependencyGroup).Count -ne 1) {
                throw "$packageId must contain one dependency group for $targetFramework."
            }

            $coreDependency = @($dependencyGroup.dependency) |
                Where-Object { $_.id -eq 'IdemShield.AspNetCore' }
            if ($packageId -eq 'IdemShield.AspNetCore' -and @($coreDependency).Count -ne 0) {
                throw "$packageId must not depend on itself for $targetFramework."
            }
            if ($packageId -ne 'IdemShield.AspNetCore' -and
                (@($coreDependency).Count -ne 1 -or $coreDependency.version -ne $exactCoreVersion)) {
                throw "$packageId must depend exactly on IdemShield.AspNetCore $Version for $targetFramework."
            }
        }
    }
    finally {
        $archive.Dispose()
    }

    $symbolArchive = [System.IO.Compression.ZipFile]::OpenRead($symbolPath)
    try {
        foreach ($targetFramework in $TargetFrameworks) {
            if ($symbolArchive.Entries.FullName -notcontains "lib/$targetFramework/$packageId.pdb") {
                throw "$packageId symbol package is missing 'lib/$targetFramework/$packageId.pdb'."
            }
        }
    }
    finally {
        $symbolArchive.Dispose()
    }
}

if (Test-Path -LiteralPath $consumerRoot) {
    Remove-Item -LiteralPath $consumerRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $consumerRoot | Out-Null

$project = @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFrameworks>$($TargetFrameworks -join ';')</TargetFrameworks>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
    <ManagePackageVersionsCentrally>false</ManagePackageVersionsCentrally>
  </PropertyGroup>
  <ItemGroup>
    <FrameworkReference Include="Microsoft.AspNetCore.App" />
    <PackageReference Include="IdemShield.AspNetCore" Version="$Version" />
    <PackageReference Include="IdemShield.Redis" Version="$Version" />
    <PackageReference Include="IdemShield.SqlServer" Version="$Version" />
  </ItemGroup>
</Project>
"@

$program = @'
using IdemShield.AspNetCore;
using IdemShield.Redis;
using IdemShield.SqlServer;
using Microsoft.Extensions.DependencyInjection;

var services = new ServiceCollection();
services.AddIdempotency();
services.UseRedisStore("localhost:6379");
services.UseSqlServerStore("Server=localhost;Database=IdemShield;Integrated Security=True;", options =>
{
    options.AutoCreateSchema = false;
    options.EnableCleanup = false;
});
'@

$nugetConfig = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="local-packages" value="$packageRoot" />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
</configuration>
"@

$projectPath = Join-Path $consumerRoot 'Consumer.csproj'
$programPath = Join-Path $consumerRoot 'Program.cs'
$nugetConfigPath = Join-Path $consumerRoot 'NuGet.config'
Set-Content -LiteralPath $projectPath -Value $project -Encoding utf8
Set-Content -LiteralPath $programPath -Value $program -Encoding utf8
Set-Content -LiteralPath $nugetConfigPath -Value $nugetConfig -Encoding utf8

& $DotNetCommand restore $projectPath --configfile $nugetConfigPath
if ($LASTEXITCODE -ne 0) {
    throw 'Consumer restore failed.'
}

& $DotNetCommand build $projectPath --configuration Release --no-restore
if ($LASTEXITCODE -ne 0) {
    throw 'Consumer build failed.'
}

Write-Host "Validated $($expectedPackages.Count) packages and compiled clean $($TargetFrameworks -join ' and ') consumer applications."
