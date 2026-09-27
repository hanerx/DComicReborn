[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,

    [string]$BuildDirectory = 'build/windows/x64/runner/Release',

    [string]$OutputDirectory = 'build/windows/packages',

    [string]$IsccPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = (Get-Location).ProviderPath

function Get-AbsolutePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $Path))
}

function Invoke-CheckedNativeCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string[]]$ArgumentList
    )

    $output = & $FilePath @ArgumentList 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        $details = ($output | Out-String).Trim()
        if ($details) {
            throw "Command '$FilePath' failed with exit code $exitCode.`n$details"
        }

        throw "Command '$FilePath' failed with exit code $exitCode."
    }

    return $output
}

function Find-Iscc {
    param(
        [string]$ExplicitPath
    )

    if ($ExplicitPath) {
        $resolvedExplicitPath = Get-AbsolutePath $ExplicitPath
        if (-not (Test-Path -LiteralPath $resolvedExplicitPath -PathType Leaf)) {
            throw "Inno Setup compiler was not found at '$resolvedExplicitPath'."
        }

        return (Get-Item -LiteralPath $resolvedExplicitPath).FullName
    }

    $pathCommand = Get-Command -Name 'ISCC.exe' -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($pathCommand) {
        return $pathCommand.Source
    }

    $programFilesX86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    if ($programFilesX86) {
        $knownPath = Join-Path $programFilesX86 'Inno Setup 6\ISCC.exe'
        if (Test-Path -LiteralPath $knownPath -PathType Leaf) {
            return (Get-Item -LiteralPath $knownPath).FullName
        }
    }

    throw 'Inno Setup 6 compiler (ISCC.exe) was not found. Pass -IsccPath, add it to PATH, or install it under Program Files (x86).'
}

function Find-VcRuntimeDirectories {
    $programFilesX86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    if (-not $programFilesX86) {
        throw 'ProgramFiles(x86) is not defined; Visual Studio runtime discovery is unavailable.'
    }

    $vswherePath = Join-Path $programFilesX86 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path -LiteralPath $vswherePath -PathType Leaf)) {
        throw "Visual Studio locator was not found at '$vswherePath'."
    }

    $installations = @(
        Invoke-CheckedNativeCommand -FilePath $vswherePath -ArgumentList @(
            '-all',
            '-prerelease',
            '-products', '*',
            '-sort',
            '-property', 'installationPath'
        ) | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ }
    )

    if ($installations.Count -eq 0) {
        throw 'vswhere did not find an installed Visual Studio instance.'
    }

    foreach ($installation in $installations) {
        $redistRoot = Join-Path $installation 'VC\Redist\MSVC'
        if (-not (Test-Path -LiteralPath $redistRoot -PathType Container)) {
            continue
        }

        $versionNames = @()
        $defaultVersionFile = Join-Path $installation 'VC\Auxiliary\Build\Microsoft.VCRedistVersion.default.txt'
        if (Test-Path -LiteralPath $defaultVersionFile -PathType Leaf) {
            $defaultVersion = (Get-Content -LiteralPath $defaultVersionFile -Raw).Trim()
            if ($defaultVersion) {
                $versionNames += $defaultVersion
            }
        }

        $versionNames += @(
            Get-ChildItem -LiteralPath $redistRoot -Directory |
                Sort-Object -Property Name -Descending |
                Select-Object -ExpandProperty Name
        )

        foreach ($redistVersion in @($versionNames | Select-Object -Unique)) {
            $x64Directory = Join-Path (Join-Path $redistRoot $redistVersion) 'x64'
            if (-not (Test-Path -LiteralPath $x64Directory -PathType Container)) {
                continue
            }

            $crtDirectories = @(
                Get-ChildItem -LiteralPath $x64Directory -Directory |
                    Where-Object { $_.Name -like 'Microsoft.VC*.CRT' }
            )
            if ($crtDirectories.Count -gt 0) {
                return $crtDirectories
            }
        }
    }

    throw 'No app-local x64 Microsoft.VC*.CRT runtime directory was found in the installed Visual Studio instances.'
}

$buildPath = Get-AbsolutePath $BuildDirectory
$outputPath = Get-AbsolutePath $OutputDirectory
$installerScriptPath = Join-Path $repositoryRoot 'windows\installer\dcomic.iss'

if (-not (Test-Path -LiteralPath $buildPath -PathType Container)) {
    throw "Windows Release bundle was not found at '$buildPath'."
}

$requiredFiles = @(
    'dcomic.exe',
    'flutter_windows.dll',
    'sqlite3.dll'
)
foreach ($requiredFile in $requiredFiles) {
    $requiredPath = Join-Path $buildPath $requiredFile
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Windows Release bundle is incomplete: '$requiredPath' is missing."
    }
}

$flutterAssetsPath = Join-Path $buildPath 'data\flutter_assets'
if (-not (Test-Path -LiteralPath $flutterAssetsPath -PathType Container)) {
    throw "Windows Release bundle is incomplete: '$flutterAssetsPath' is missing."
}

if (-not (Test-Path -LiteralPath $installerScriptPath -PathType Leaf)) {
    throw "Inno Setup script was not found at '$installerScriptPath'."
}

$iscc = Find-Iscc -ExplicitPath $IsccPath
$crtDirectories = @(Find-VcRuntimeDirectories)
$crtDlls = @(
    $crtDirectories | ForEach-Object {
        Get-ChildItem -LiteralPath $_.FullName -File -Filter '*.dll'
    }
)
if ($crtDlls.Count -eq 0) {
    throw 'The discovered x64 Microsoft Visual C++ runtime directories contain no DLLs.'
}

[System.IO.Directory]::CreateDirectory($outputPath) | Out-Null

$portableName = "dcomic-$Version-windows-x64-portable.zip"
$setupBaseName = "dcomic-$Version-windows-x64-setup"
$portablePath = Join-Path $outputPath $portableName
$setupPath = Join-Path $outputPath "$setupBaseName.exe"
$stagePath = Join-Path $outputPath ('.dcomic-windows-stage-' + [Guid]::NewGuid().ToString('N'))
$stageCreated = $false

try {
    if (Test-Path -LiteralPath $stagePath) {
        throw "Refusing to use an existing staging directory: '$stagePath'."
    }

    [System.IO.Directory]::CreateDirectory($stagePath) | Out-Null
    $stageCreated = $true

    # Ship the Flutter runtime bundle, not linker outputs or local test data.
    Get-ChildItem -LiteralPath $buildPath -File |
        Where-Object { $_.Extension.ToLowerInvariant() -in @('.exe', '.dll') } |
        Copy-Item -Destination $stagePath -Force
    Copy-Item -LiteralPath (Join-Path $buildPath 'data') -Destination $stagePath -Recurse -Force

    foreach ($crtDll in $crtDlls) {
        Copy-Item -LiteralPath $crtDll.FullName -Destination $stagePath -Force
    }

    foreach ($artifactPath in @($portablePath, $setupPath)) {
        if (Test-Path -LiteralPath $artifactPath -PathType Leaf) {
            Remove-Item -LiteralPath $artifactPath -Force
        }
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory(
        $stagePath,
        $portablePath,
        [System.IO.Compression.CompressionLevel]::Optimal,
        $false
    )

    Invoke-CheckedNativeCommand -FilePath $iscc -ArgumentList @(
        "/DAppVersion=$Version",
        "/DSourceDir=$stagePath",
        "/DOutputDir=$outputPath",
        "/DOutputBaseName=$setupBaseName",
        $installerScriptPath
    ) | ForEach-Object { Write-Host $_ }

    if (-not (Test-Path -LiteralPath $portablePath -PathType Leaf)) {
        throw "Portable archive was not created at '$portablePath'."
    }
    if (-not (Test-Path -LiteralPath $setupPath -PathType Leaf)) {
        throw "Installer was not created at '$setupPath'."
    }

    Write-Output $portablePath
    Write-Output $setupPath
}
catch {
    foreach ($artifactPath in @($portablePath, $setupPath)) {
        if (Test-Path -LiteralPath $artifactPath -PathType Leaf) {
            Remove-Item -LiteralPath $artifactPath -Force
        }
    }

    throw
}
finally {
    if ($stageCreated -and (Test-Path -LiteralPath $stagePath -PathType Container)) {
        Remove-Item -LiteralPath $stagePath -Recurse -Force
    }
}
