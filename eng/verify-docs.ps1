[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = [System.IO.Path]::GetFullPath((Get-Location).Path)
$trackedMarkdownFiles = @(& git ls-files '*.md')
$brokenLinks = [System.Collections.Generic.List[string]]::new()

foreach ($file in $trackedMarkdownFiles) {
    $content = Get-Content -Raw -LiteralPath $file
    $parent = Split-Path -Parent $file
    if ([string]::IsNullOrEmpty($parent)) {
        $parent = '.'
    }

    foreach ($match in [regex]::Matches($content, '\[[^\]]+\]\((?!https?://|mailto:|#)([^)#]+)(?:#[^)]*)?\)')) {
        $target = [Uri]::UnescapeDataString($match.Groups[1].Value)
        $resolvedTarget = [System.IO.Path]::GetFullPath((Join-Path $parent $target))
        if (-not $resolvedTarget.StartsWith($repositoryRoot, [StringComparison]::OrdinalIgnoreCase) -or
            -not (Test-Path -LiteralPath $resolvedTarget)) {
            $brokenLinks.Add("$file -> $target")
        }
    }
}

if ($brokenLinks.Count -gt 0) {
    throw "Broken local documentation links:$([Environment]::NewLine)$($brokenLinks -join [Environment]::NewLine)"
}

$readme = Get-Content -Raw -LiteralPath 'README.md'
foreach ($staleText in @(
    'not considered publicly released until',
    'after the `0.1.0` packages are published'
)) {
    if ($readme.Contains($staleText, [StringComparison]::OrdinalIgnoreCase)) {
        throw "README.md contains stale release text: $staleText"
    }
}

foreach ($packageId in @('IdemShield.AspNetCore', 'IdemShield.Redis', 'IdemShield.SqlServer')) {
    if (-not $readme.Contains("https://www.nuget.org/packages/$packageId", [StringComparison]::OrdinalIgnoreCase)) {
        throw "README.md must link directly to the $packageId NuGet package."
    }
}

Write-Host "Validated $($trackedMarkdownFiles.Count) tracked Markdown files and their local links."
