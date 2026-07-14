@echo off
setlocal enabledelayedexpansion

echo PaperPal - PDF 文件关联安装
echo ========================================
echo.
echo 此脚本将 .pdf 文件关联到 PaperPal
echo.
echo 请确保 PaperPal.exe 已安装到最终目录
echo.

:: 获取当前脚本所在目录
set "SCRIPT_DIR=%~dp0"
set "EXE_PATH=%SCRIPT_DIR%PaperPal.exe"

:: 检查 EXE 是否存在
if not exist "%EXE_PATH%" (
    echo [错误] 未找到 PaperPal.exe
    echo 请将此脚本与 PaperPal.exe 放在同一目录后重试
    pause
    exit /b 1
)

echo PaperPal 路径: %EXE_PATH%
echo.

:: 请求管理员权限
echo [1/3] 请求管理员权限...
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo 需要管理员权限来修改注册表
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: 注册 ProgID
echo [2/3] 注册 ProgID...
reg add "HKCR\PaperPal.PDF\shell\open\command" /ve /t REG_SZ /d "\"%EXE_PATH%\" \"%%1\"" /f
reg add "HKCR\PaperPal.PDF\DefaultIcon" /ve /t REG_SZ /d "\"%EXE_PATH%\"" /f
reg add "HKCR\PaperPal.PDF" /ve /t REG_SZ /d "PaperPal Document" /f

:: 关联 .pdf 扩展名
echo [3/3] 关联 .pdf 扩展名...
reg add "HKCR\.pdf\OpenWithProgids" /v "PaperPal.PDF" /t REG_SZ /d "" /f

:: 刷新图标缓存
ie4uinit.exe -show >nul 2>&1

echo.
echo ========================================
echo 完成！.pdf 文件现已关联到 PaperPal。
echo 现在可以右键 PDF 文件 -> 打开方式 -> PaperPal
echo ========================================
pause
