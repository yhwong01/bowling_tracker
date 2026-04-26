Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-LatestChildDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ParentPath,

        [Parameter(Mandatory = $true)]
        [string]$Filter
    )

    if (-not (Test-Path -LiteralPath $ParentPath)) {
        throw "Missing directory: $ParentPath"
    }

    $directory = Get-ChildItem -LiteralPath $ParentPath -Directory -Filter $Filter |
        Sort-Object Name -Descending |
        Select-Object -First 1

    if (-not $directory) {
        throw "No matching directory found in $ParentPath for filter '$Filter'."
    }

    return $directory.FullName
}

function Get-SwiftWindowsEnvironment {
    $swiftRoot = Join-Path $env:LOCALAPPDATA "Programs\\Swift"
    $toolchainRoot = Get-LatestChildDirectory -ParentPath (Join-Path $swiftRoot "Toolchains") -Filter "*"
    $runtimeRoot = Get-LatestChildDirectory -ParentPath (Join-Path $swiftRoot "Runtimes") -Filter "*"
    $platformRoot = Get-LatestChildDirectory -ParentPath (Join-Path $swiftRoot "Platforms") -Filter "*"

    $toolchainBin = Join-Path $toolchainRoot "usr\\bin"
    $runtimeBin = Join-Path $runtimeRoot "usr\\bin"
    $sdkRoot = Join-Path $platformRoot "Windows.platform\\Developer\\SDKs\\Windows.sdk"
    $vsDevCmd = "C:\\Program Files\\Microsoft Visual Studio\\2022\\Community\\Common7\\Tools\\VsDevCmd.bat"

    foreach ($requiredPath in @($toolchainBin, $runtimeBin, $sdkRoot, $vsDevCmd)) {
        if (-not (Test-Path -LiteralPath $requiredPath)) {
            throw "Required Swift/Visual Studio path was not found: $requiredPath"
        }
    }

    return @{
        ToolchainBin = $toolchainBin
        RuntimeBin = $runtimeBin
        SDKRoot = $sdkRoot
        VsDevCmd = $vsDevCmd
    }
}

function Invoke-SwiftWindowsCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SwiftSubcommand
    )

    $environment = Get-SwiftWindowsEnvironment

    $env:PATH = "$($environment.RuntimeBin);$($environment.ToolchainBin);$env:PATH"
    $env:SDKROOT = $environment.SDKRoot

    $command = "`"$($environment.VsDevCmd)`" -no_logo -arch=amd64 -host_arch=amd64 && swift $SwiftSubcommand"
    & cmd.exe /c $command

    if ($LASTEXITCODE -ne 0) {
        throw "swift $SwiftSubcommand failed with exit code $LASTEXITCODE."
    }
}
