# Build a mod.io runtime ZIP while keeping local dependencies in development builds
param([string]$Lua = 'lua54')

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $packageRoot
try {
    & $Lua tools/build.lua --release --out dist/modio
    if ($LASTEXITCODE -ne 0) { throw 'Release build failed' }

    $packageSource = (Resolve-Path -LiteralPath 'dist/modio/bankcleaner').Path
    $packageManifest = Get-Content -LiteralPath "$packageSource/plugin.json" -Raw | ConvertFrom-Json
    if ($packageManifest.requiredDependencies.bankcore -ne 6464293) { throw 'Missing mod.io dependency' }
    $packageFiles = Get-ChildItem -LiteralPath $packageSource -Recurse -File
    $packageZip = Join-Path $packageRoot "dist/bankcleaner-v$($packageManifest.version).zip"
    $packageTemporary = Join-Path $packageRoot ('dist/package-' + [guid]::NewGuid().ToString('N') + '.zip')

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $packageArchive = [System.IO.Compression.ZipFile]::Open($packageTemporary, 'Create')
    try {
        foreach ($packageFile in $packageFiles) {
            $packageRelative = $packageFile.FullName.Substring($packageSource.Length).TrimStart('\', '/').Replace('\', '/')
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $packageArchive, $packageFile.FullName, "bankcleaner/$packageRelative", 'Optimal') | Out-Null
        }
    } finally { $packageArchive.Dispose() }

    # Verify every archived file before replacing the previous ZIP
    $packageArchive = [System.IO.Compression.ZipFile]::OpenRead($packageTemporary)
    try {
        if ($packageArchive.Entries.Count -ne $packageFiles.Count) { throw 'ZIP file count mismatch' }
        foreach ($packageEntry in $packageArchive.Entries) {
            if ($packageEntry.FullName -notmatch '^bankcleaner/(main\.lua|plugin\.json|resources/.+\.lua)$') {
                throw "Unexpected ZIP entry: $($packageEntry.FullName)"
            }
            $packageInput = $packageEntry.Open()
            $packageHasher = [System.Security.Cryptography.SHA256]::Create()
            try {
                $packageHash = [System.BitConverter]::ToString($packageHasher.ComputeHash($packageInput)).Replace('-', '')
                $packageRelative = $packageEntry.FullName.Substring('bankcleaner/'.Length)
                if ($packageHash -ne (Get-FileHash -LiteralPath (Join-Path $packageSource $packageRelative)).Hash) {
                    throw "ZIP content mismatch: $packageRelative"
                }
            } finally {
                $packageInput.Dispose()
                $packageHasher.Dispose()
            }
        }
    } finally { $packageArchive.Dispose() }
    Move-Item -LiteralPath $packageTemporary -Destination $packageZip -Force
    Write-Output "Verified $($packageFiles.Count) runtime files with mod.io dependency 6464293: $packageZip"
} finally { Pop-Location }
