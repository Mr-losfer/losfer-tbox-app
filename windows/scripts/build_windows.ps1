# Noqi — Windows 打包（推荐在 Windows 上执行，可嵌入图标与版本信息）
#   powershell -ExecutionPolicy Bypass -File scripts\build_windows.ps1
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

$version = "1.0.1"
$out = "dist\Noqi"

dotnet restore
dotnet publish -c Release -r win-x64 --self-contained true -p:EnableWindowsTargeting=true -o $out

# libVLC 包同时带 win-x64 / win-x86 两套内核，x64 发行版只需前者（省 ~96 MB）
if (Test-Path "$out\libvlc\win-x86") { Remove-Item "$out\libvlc\win-x86" -Recurse -Force }

Copy-Item "packaging\使用说明.txt" "$out\使用说明.txt" -Force

Write-Host "✓ $out\Noqi.exe" -ForegroundColor Green
Compress-Archive -Path "$out\*" -DestinationPath "dist\Noqi-Windows-x64-$version.zip" -Force
Write-Host "✓ dist\Noqi-Windows-x64-$version.zip" -ForegroundColor Green
