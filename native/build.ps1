param([string]$Compiler = 'zig')
$ErrorActionPreference = 'Stop'
$nativeRoot = $PSScriptRoot
$output = Join-Path $nativeRoot 'bin\dot_wars_native.windows.x86_64.v13.dll'
New-Item -ItemType Directory -Path (Split-Path -Parent $output) -Force | Out-Null
$arguments = @('cc', '-std=c11', '-O3', '-Wall', '-Wextra', '-Wno-cast-function-type-mismatch', '-target', 'x86_64-windows-gnu', '-shared', '-o', $output, (Join-Path $nativeRoot 'dot_wars_native.c'))
& $Compiler @arguments
if ($LASTEXITCODE -ne 0) { throw 'Native build failed' }
Write-Output $output
