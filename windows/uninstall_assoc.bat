@echo off
echo PaperPal - 卸载 PDF 文件关联
echo ========================================
echo.

:: 请求管理员权限
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo 移除 ProgID...
reg delete "HKCR\PaperPal.PDF" /f >nul 2>&1

echo 移除 .pdf 扩展名关联...
reg delete "HKCR\.pdf\OpenWithProgids" /v "PaperPal.PDF" /f >nul 2>&1

echo 完成！PDF 文件关联已移除。
pause
