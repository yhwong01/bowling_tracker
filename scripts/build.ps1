Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. "$PSScriptRoot\\common.ps1"

Invoke-SwiftWindowsCommand -SwiftSubcommand "build"
