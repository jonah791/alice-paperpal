# PaperPal 环境搭建脚本 (Windows)
# 首次使用前运行此脚本安装所需依赖

$ErrorActionPreference = "Stop"

Write-Host "═" * 50
Write-Host "PaperPal 环境搭建"
Write-Host "═" * 50

# 1. 检查 Flutter
$flutterPath = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterPath) {
    Write-Host "[1/3] Flutter SDK 未安装，正在下载..."
    
    $flutterZip = "$env:TEMP\flutter_windows_3.29.2-stable.zip"
    $flutterUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.29.2-stable.zip"
    $extractDir = "$env:USERPROFILE\flutter"
    
    if (-not (Test-Path $flutterZip)) {
        Write-Host "  下载 Flutter SDK (~1GB)，请耐心等待..."
        Invoke-WebRequest -Uri $flutterUrl -OutFile $flutterZip
    }
    
    Write-Host "  解压中..."
    Expand-Archive -Path $flutterZip -DestinationPath $extractDir -Force
    
    # 添加到 PATH
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $flutterBin = "$extractDir\flutter\bin"
    if ($userPath -notlike "*$flutterBin*") {
        [Environment]::SetEnvironmentVariable("Path", "$userPath;$flutterBin", "User")
        $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
    }
    
    Write-Host "  Flutter SDK 安装完成"
} else {
    Write-Host "[1/3] Flutter SDK 已安装: $($flutterPath.Source)"
}

# 2. Flutter 自检
Write-Host "[2/3] 运行 flutter doctor..."
flutter doctor

# 3. 安装依赖
Write-Host "[3/3] 安装项目依赖..."
flutter pub get

Write-Host "═" * 50
Write-Host "搭建完成！运行以下命令构建："
Write-Host "  flutter build windows --release"
Write-Host "或运行开发模式："
Write-Host "  flutter run -d windows"
Write-Host "═" * 50
