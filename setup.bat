@echo off
chcp 65001 >nul 2>&1
REM =======================================================
REM ZeroClaw Quick Setup for Windows
REM =======================================================
REM Usage: setup.bat [device-ip]
REM Example: setup.bat 192.168.81.1
REM Supports: aarch64/OpenWrt, MIPS32r2/Entware
REM Requires: Windows 10+ (built-in SSH)

setlocal enabledelayedexpansion

set ROUTER_IP=%1
if "%ROUTER_IP%"=="" set ROUTER_IP=192.168.81.1
set REMOTE_DIR=/tmp/zeroclaw-router-installer
set SSH_BASE=-o StrictHostKeyChecking=no

echo.
echo =======================================================
echo  ZeroClaw Quick Setup - %ROUTER_IP%
echo =======================================================
echo.

REM Step 0: Setup SSH key auth (nhap password 1 lan, lan sau khong can)
echo [0/5] Setting up SSH connection...

REM Check if passwordless auth already works
ssh %SSH_BASE% -o BatchMode=yes root@%ROUTER_IP% "echo ok" >nul 2>&1
if not errorlevel 1 (
    echo [OK] SSH key da duoc cai - khong can nhap password
    goto :step1
)

REM Generate SSH key if needed
if not exist "%USERPROFILE%\.ssh\id_rsa.pub" (
    echo   Generating SSH key...
    ssh-keygen -t rsa -b 2048 -f "%USERPROFILE%\.ssh\id_rsa" -N "" >nul 2>&1
    if errorlevel 1 (
        echo [WARN] Khong tao duoc SSH key, se phai nhap password moi buoc
        goto :step1
    )
)

REM Install SSH key on router (nhap password 1 lan duy nhat)
echo   Cai SSH key len router (nhap password 1 lan)...
set /p SSH_KEY=<"%USERPROFILE%\.ssh\id_rsa.pub"
ssh %SSH_BASE% root@%ROUTER_IP% "mkdir -p /etc/dropbear ~/.ssh 2>/dev/null; echo '!SSH_KEY!' >> /etc/dropbear/authorized_keys 2>/dev/null; echo '!SSH_KEY!' >> ~/.ssh/authorized_keys 2>/dev/null; chmod 600 /etc/dropbear/authorized_keys ~/.ssh/authorized_keys 2>/dev/null; chmod 700 /etc/dropbear ~/.ssh 2>/dev/null"
if errorlevel 1 (
    echo [WARN] SSH key setup failed, se phai nhap password moi buoc
    goto :step1
)

REM Verify key was installed
ssh %SSH_BASE% -o BatchMode=yes root@%ROUTER_IP% "echo ok" >nul 2>&1
if errorlevel 1 (
    echo [WARN] SSH key khong hoat dong, se phai nhap password moi buoc
) else (
    echo [OK] SSH key installed - khong can nhap password nua!
    echo      ^(Lan chay tiep theo cung khong can nhap password^)
)

:step1
echo.

REM Step 1: Platform detection
echo [1/5] Detecting platform...
ssh %SSH_BASE% root@%ROUTER_IP% "uname -m && uname -r && (pidof procd >/dev/null 2>&1 && [ -d /etc/init.d ] && [ -d /etc/config ] && echo PROCD=yes || echo PROCD=no) && ([ -x /opt/bin/opkg ] && echo ENTWARE=yes || echo ENTWARE=no)" > %TEMP%\zc_detect.txt 2>&1
if errorlevel 1 (
    echo [ERROR] Platform detection failed
    exit /b 1
)

REM Parse arch from first line
set /p ARCH=<%TEMP%\zc_detect.txt

REM Determine platform
set PLATFORM=unknown
set BIN_ARCH=unknown

findstr /C:"aarch64" %TEMP%\zc_detect.txt >nul 2>&1
if not errorlevel 1 (
    set BIN_ARCH=aarch64
    findstr /C:"PROCD=yes" %TEMP%\zc_detect.txt >nul 2>&1
    if not errorlevel 1 (
        set PLATFORM=procd
    ) else (
        set PLATFORM=entware
    )
)

findstr /C:"mips" %TEMP%\zc_detect.txt >nul 2>&1
if not errorlevel 1 (
    set BIN_ARCH=mips32r2
    set PLATFORM=entware
)

del %TEMP%\zc_detect.txt

echo   Architecture: %ARCH% (%BIN_ARCH%)
echo   Platform:     %PLATFORM%

if "%BIN_ARCH%"=="unknown" (
    echo [ERROR] Unsupported architecture: %ARCH%
    exit /b 1
)
if "%PLATFORM%"=="unknown" (
    echo [ERROR] Cannot determine platform
    exit /b 1
)

REM Check binaries exist
if not exist "binaries\%BIN_ARCH%\zeroclaw" (
    echo [ERROR] Missing binaries\%BIN_ARCH%\zeroclaw
    exit /b 1
)
if not exist "binaries\%BIN_ARCH%\cli-proxy-api" (
    echo [ERROR] Missing binaries\%BIN_ARCH%\cli-proxy-api
    exit /b 1
)

echo [OK] Platform: %PLATFORM% (%BIN_ARCH%)
echo.

REM Confirm
set /p CONFIRM="  Continue with installation? [Y/n]: "
if /i "%CONFIRM%"=="n" (
    echo [ABORT] Installation cancelled.
    exit /b 0
)

REM --- Telegram Config (mandatory) ---
echo.
echo [INFO] Telegram Bot Token va User ID la bat buoc.
echo   ZeroClaw can Telegram de gui thong bao va nhan lenh.
echo.

:telegram_loop
set /p TG_TOKEN="  Telegram Bot Token: "
if "%TG_TOKEN%"=="" (
    echo   [WARN] Bot Token la bat buoc. Vui long nhap lai.
    goto :telegram_loop
)

:telegram_uid_loop
set /p TG_USERID="  Telegram User ID (numeric): "
if "%TG_USERID%"=="" (
    echo   [WARN] User ID la bat buoc. Vui long nhap lai.
    goto :telegram_uid_loop
)

REM Test Telegram API
echo   [INFO] Dang gui tin nhan test qua Telegram...
curl -s -X POST "https://api.telegram.org/bot%TG_TOKEN%/sendMessage" -d "chat_id=%TG_USERID%&text=ZeroClaw installer: Ket noi Telegram thanh cong." > %TEMP%\zc_tg_test.txt 2>&1
findstr /C:"\"ok\":true" %TEMP%\zc_tg_test.txt >nul 2>&1
if errorlevel 1 (
    echo   [FAIL] Telegram test that bai. Kiem tra lai Bot Token va User ID.
    del %TEMP%\zc_tg_test.txt >nul 2>&1
    set /p TG_RETRY="  Nhap lai? [Y/n]: "
    if /i "!TG_RETRY!"=="n" (
        echo [ERROR] Telegram la bat buoc. Huy cai dat.
        exit /b 1
    )
    goto :telegram_loop
)
del %TEMP%\zc_tg_test.txt >nul 2>&1
echo   [OK] Telegram test thanh cong!
set /p TG_CONFIRM="  Ban da nhan duoc tin nhan test? [Y/n]: "
if /i "%TG_CONFIRM%"=="n" (
    echo   [WARN] Vui long kiem tra lai Bot Token va User ID.
    goto :telegram_loop
)
echo.

REM Step 2: Upload
echo.
echo [2/5] Uploading to device...
ssh %SSH_BASE% root@%ROUTER_IP% "rm -rf %REMOTE_DIR%; mkdir -p %REMOTE_DIR%/binaries/%BIN_ARCH% %REMOTE_DIR%/platforms/%PLATFORM%"
if errorlevel 1 (
    echo [ERROR] Failed to prepare remote directory
    exit /b 1
)

echo       Uploading files...
scp -O %SSH_BASE% -r binaries\%BIN_ARCH%\* root@%ROUTER_IP%:%REMOTE_DIR%/binaries/%BIN_ARCH%/
scp -O %SSH_BASE% -r configs root@%ROUTER_IP%:%REMOTE_DIR%/
scp -O %SSH_BASE% -r platforms\%PLATFORM%\* root@%ROUTER_IP%:%REMOTE_DIR%/platforms/%PLATFORM%/
scp -O %SSH_BASE% common.sh root@%ROUTER_IP%:%REMOTE_DIR%/
if errorlevel 1 (
    echo [ERROR] Upload failed
    exit /b 1
)
echo [OK] Upload complete

REM Fix Windows line endings (CRLF -> LF) on all shell scripts
echo       Fixing line endings...
ssh %SSH_BASE% root@%ROUTER_IP% "cd %REMOTE_DIR% && find . -type f \( -name '*.sh' -o -name '*.yaml' -o -name '*.conf' -o -name '*.yml' \) -exec sed -i 's/\r$//' {} + && find . -path '*/init-scripts/*' -type f -exec sed -i 's/\r$//' {} +"
echo [OK] Line endings fixed

REM Step 3: Install
echo.
echo [3/5] Running installer (%PLATFORM%)...
echo -------------------------------------
ssh %SSH_BASE% root@%ROUTER_IP% "cd %REMOTE_DIR% && SKIP_CONFIRM=1 TELEGRAM_BOT_TOKEN='%TG_TOKEN%' TELEGRAM_USER_ID='%TG_USERID%' sh platforms/%PLATFORM%/install.sh"
echo -------------------------------------

REM Step 4: Verify
echo.
echo [4/5] Verifying...
timeout /t 2 /nobreak >nul
curl -s -o nul -w "HTTP Status: %%{http_code}" --connect-timeout 5 http://%ROUTER_IP%:8317/management.html
echo.

REM Step 5: Done
echo.
echo =======================================================
echo  Done! Open http://%ROUTER_IP%:8317/management.html
echo  Platform: %PLATFORM% (%BIN_ARCH%)
echo =======================================================
echo.

endlocal
