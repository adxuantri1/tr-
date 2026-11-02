@echo off
setlocal
cd /d "%~dp0"
if not exist "%~dp0PC-Tuner-Pro.ps1" (
echo Khong thay PC-Tuner-Pro.ps1. Hay giai nen toan bo goi vao cung thu muc.
pause >nul
exit /b 1
)
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0PC-Tuner-Pro.ps1"
set "PC_TUNER_EXIT=%ERRORLEVEL%"
if not "%PC_TUNER_EXIT%"=="0" (
echo Khong mo duoc ung dung. Xem loi phia tren.
echo Nhan phim bat ky de dong.
pause >nul
)
exit /b %PC_TUNER_EXIT%
