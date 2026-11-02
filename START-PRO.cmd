@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0PC-Tuner-Pro.ps1"
set "PC_TUNER_EXIT=%ERRORLEVEL%"
if not "%PC_TUNER_EXIT%"=="0" (
echo Không mở được ứng dụng. Xem lỗi phía trên rồi nhấn phím bất kỳ để đóng.
pause >nul
)
exit /b %PC_TUNER_EXIT%
