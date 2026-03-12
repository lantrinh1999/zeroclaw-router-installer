@echo off
chcp 65001 >nul 2>&1
REM =======================================================
REM ZeroClaw Quick Setup for Windows
REM =======================================================
REM Usage: setup.bat [device-ip] [-p port] [--only-binary]
REM Example: setup.bat 192.168.81.1
REM          setup.bat localhost -p 2222
REM          setup.bat 192.168.81.1 --only-binary
REM Supports: aarch64/OpenWrt, MIPS32r2/Entware
REM Requires: Windows 10+ (built-in SSH)

setlocal enabledelayedexpansion

REM Parse arguments: setup.bat [ip] [-p port] [--only-binary]
set ROUTER_IP=192.168.81.1
set SSH_PORT=22
set ONLY_BINARY=0
set VERIFY_PORT=8317

:parse_args
if "%~1"=="" goto :args_done
if /i "%~1"=="--only-binary" (
    set ONLY_BINARY=1
    shift
    goto :parse_args
)
if /i "%~1"=="-p" (
    set SSH_PORT=%~2
    shift
    shift
    goto :parse_args
)
set ROUTER_IP=%~1
shift
goto :parse_args

:args_done
set REMOTE_DIR=/tmp/zeroclaw-router-installer
set SSH_BASE=-p %SSH_PORT% -o StrictHostKeyChecking=no
set SCP_BASE=-P %SSH_PORT% -O -o StrictHostKeyChecking=no

echo.
echo =======================================================
echo  ZeroClaw Quick Setup - %ROUTER_IP% (port %SSH_PORT%)
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
ssh %SSH_BASE% root@%ROUTER_IP% "rm -rf %REMOTE_DIR%; mkdir -p %REMOTE_DIR%" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Cannot prepare remote staging
    exit /b 1
)

tar cf - -C . common.sh | ssh %SSH_BASE% root@%ROUTER_IP% "tar xf - -C %REMOTE_DIR%"
if errorlevel 1 (
    echo [ERROR] Cannot upload detector
    exit /b 1
)

ssh %SSH_BASE% root@%ROUTER_IP% "cd %REMOTE_DIR% && . ./common.sh >/dev/null 2>&1 && detect_platform >/dev/null 2>&1 && print_platform_exports" > %TEMP%\zc_detect.txt 2>&1
if errorlevel 1 (
    echo [ERROR] Platform detection failed
    exit /b 1
)

set ARCH=unknown
set BIN_ARCH=unknown
set OS_NAME=
set OS_TYPE=
set KERNEL=
set PID1_COMM=
set INIT_TYPE=
set SERVICE_BACKEND=
set INSTALL_LAYOUT=
set INSTALL_BIN_DIR=
set INSTALL_CLIPROXY_DIR=
set EXEC_MODE=
set ENTWARE=
set INSTALLER=unknown
set RAM=
set DISK=
set RESULT=

for /f "usebackq tokens=1,* delims==" %%A in ("%TEMP%\zc_detect.txt") do (
    if /i "%%A"=="ARCH" set ARCH=%%B
    if /i "%%A"=="BIN_ARCH" set BIN_ARCH=%%B
    if /i "%%A"=="OS_TYPE" set OS_TYPE=%%B
    if /i "%%A"=="OS_NAME" set OS_NAME=%%B
    if /i "%%A"=="KERNEL" set KERNEL=%%B
    if /i "%%A"=="PID1_COMM" set PID1_COMM=%%B
    if /i "%%A"=="INIT_TYPE" set INIT_TYPE=%%B
    if /i "%%A"=="SERVICE_BACKEND" set SERVICE_BACKEND=%%B
    if /i "%%A"=="INSTALL_LAYOUT" set INSTALL_LAYOUT=%%B
    if /i "%%A"=="INSTALL_BIN_DIR" set INSTALL_BIN_DIR=%%B
    if /i "%%A"=="INSTALL_CLIPROXY_DIR" set INSTALL_CLIPROXY_DIR=%%B
    if /i "%%A"=="EXEC_MODE" set EXEC_MODE=%%B
    if /i "%%A"=="ENTWARE" set ENTWARE=%%B
    if /i "%%A"=="INSTALLER" set INSTALLER=%%B
    if /i "%%A"=="RAM" set RAM=%%B
    if /i "%%A"=="DISK" set DISK=%%B
    if /i "%%A"=="RESULT" set RESULT=%%B
)

echo.
echo --- Platform Detection ---
echo   Architecture:    %ARCH% (%BIN_ARCH%)
echo   OS:              %OS_NAME%
echo   OS Type:         %OS_TYPE%
echo   Kernel:          %KERNEL%
echo   PID 1:           %PID1_COMM%
echo   Init System:     %INIT_TYPE%
echo   Backend:         %SERVICE_BACKEND%
echo   Install Layout:  %INSTALL_LAYOUT%
echo   Install Bin:     %INSTALL_BIN_DIR%
echo   CLIProxy Dir:    %INSTALL_CLIPROXY_DIR%
echo   Execution Mode:  %EXEC_MODE%
echo   Entware:         %ENTWARE%
echo   RAM:             %RAM%
echo   Disk Free:       %DISK%
echo   Installer:       %INSTALLER%
echo.

for /f "usebackq delims=" %%L in (`findstr /B "FAIL" "%TEMP%\zc_detect.txt" 2^>nul`) do (
    echo   [FAIL] %%L
)

if "%BIN_ARCH%"=="unknown" (
    echo [ERROR] Unsupported architecture: %ARCH%
    del %TEMP%\zc_detect.txt >nul 2>&1
    exit /b 1
)
if "%RESULT%"=="FAIL" (
    echo.
    echo [ERROR] Device not compatible. Cannot install.
    del %TEMP%\zc_detect.txt >nul 2>&1
    exit /b 1
)
if "%INSTALLER%"=="unknown" (
    echo [ERROR] Cannot determine installer
    del %TEMP%\zc_detect.txt >nul 2>&1
    exit /b 1
)
if "%INSTALLER%"=="manual" (
    echo [WARN] Falling back to manual mode.
    echo   Services will be installed with start/stop scripts only.
    echo   Auto-start integration is not enabled in this mode.
    echo.
)

del %TEMP%\zc_detect.txt >nul 2>&1

REM Check binaries exist
if not exist "binaries\%BIN_ARCH%\zeroclaw" (
    echo [ERROR] Missing binaries\%BIN_ARCH%\zeroclaw
    exit /b 1
)
if not exist "binaries\%BIN_ARCH%\cli-proxy-api" (
    echo [ERROR] Missing binaries\%BIN_ARCH%\cli-proxy-api
    exit /b 1
)

echo [OK] Installer: %INSTALLER% (%BIN_ARCH%)
echo.

REM Confirm
set /p CONFIRM="  Continue with installation? [Y/n]: "
if /i "%CONFIRM%"=="n" (
    echo [ABORT] Installation cancelled.
    exit /b 0
)

if "%ONLY_BINARY%"=="1" (
    echo.
    echo [INFO] ONLY_BINARY mode: chi update binary va management.html
    echo   Config va data hien co se duoc giu nguyen.
    echo.
    goto :step2
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
curl -s --connect-timeout 10 --max-time 15 -X POST "https://api.telegram.org/bot%TG_TOKEN%/sendMessage" -d "chat_id=%TG_USERID%&text=ZeroClaw installer: Ket noi Telegram thanh cong." > %TEMP%\zc_tg_test.txt 2>&1
set TG_CURL_EXIT=!errorlevel!
findstr /C:"\"ok\":true" %TEMP%\zc_tg_test.txt >nul 2>&1
if errorlevel 1 (
    if not "!TG_CURL_EXIT!"=="0" (
        echo   [WARN] Telegram API khong phan hoi kip thoi ^(timeout/network^).
    )
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

:step2
REM Step 2: Upload (tar over SSH -- no scp needed on device)
echo.
echo [2/5] Uploading to device...
ssh %SSH_BASE% root@%ROUTER_IP% "rm -rf %REMOTE_DIR%; mkdir -p %REMOTE_DIR%"
if errorlevel 1 (
    echo [ERROR] Failed to prepare remote directory
    exit /b 1
)

echo       Uploading files...
if "%ONLY_BINARY%"=="1" (
    tar cf - -C . binaries/%BIN_ARCH% configs/cliproxy/static/management.html installers/%INSTALLER% common.sh | ssh %SSH_BASE% root@%ROUTER_IP% "tar xf - -C %REMOTE_DIR%"
) else (
    tar cf - -C . binaries\%BIN_ARCH% configs installers\%INSTALLER% common.sh | ssh %SSH_BASE% root@%ROUTER_IP% "tar xf - -C %REMOTE_DIR%"
)
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
echo [3/5] Running installer (%INSTALLER%)...
echo -------------------------------------
if "%ONLY_BINARY%"=="1" (
    ssh %SSH_BASE% root@%ROUTER_IP% "cd %REMOTE_DIR% && ONLY_BINARY=1 SKIP_CONFIRM=1 sh installers/%INSTALLER%/install.sh"
) else (
    ssh %SSH_BASE% root@%ROUTER_IP% "cd %REMOTE_DIR% && SKIP_CONFIRM=1 TELEGRAM_BOT_TOKEN='%TG_TOKEN%' TELEGRAM_USER_ID='%TG_USERID%' sh installers/%INSTALLER%/install.sh"
)
set INSTALL_RC=!errorlevel!
echo -------------------------------------
if not "!INSTALL_RC!"=="0" (
    echo [ERROR] Installer exited with code !INSTALL_RC!
    echo [INFO] Fetching install log from device...
    echo.
    ssh %SSH_BASE% root@%ROUTER_IP% "cat /tmp/zeroclaw-install.log 2>/dev/null"
    echo.
    echo [ERROR] Installation failed. Check the log above for details.
    exit /b 1
)

REM Step 4: Verify
echo.
echo [4/5] Verifying...
timeout /t 2 /nobreak >nul
if "%ONLY_BINARY%"=="1" (
    echo [INFO] ONLY_BINARY mode: bo qua provider sync de giu nguyen config hien co
    for /f "usebackq delims=" %%P in (`ssh %SSH_BASE% root@%ROUTER_IP% "cd %REMOTE_DIR% && . ./common.sh >/dev/null 2>&1 && detect_management_port" 2^>nul`) do set VERIFY_PORT=%%P
    if "!VERIFY_PORT!"=="" set VERIFY_PORT=8317
    echo !VERIFY_PORT! | findstr /R "^[0-9][0-9]*$" >nul || set VERIFY_PORT=8317
) else (
    ssh %SSH_BASE% root@%ROUTER_IP% "CONFIG=/root/.zeroclaw/config.toml; [ -f \"$CONFIG\" ] && sed -i 's|127.0.0.1:[0-9][0-9]*|127.0.0.1:8317|g' \"$CONFIG\""
    if errorlevel 1 (
        echo [WARN] Could not sync /root/.zeroclaw/config.toml to port 8317
    ) else (
        echo [OK] ZeroClaw provider synced to: http://127.0.0.1:8317/v1
    )
)
curl -s -o nul -w "HTTP Status: %%{http_code}" --connect-timeout 5 http://%ROUTER_IP%:!VERIFY_PORT!/management.html
echo.

REM Step 5: Cleanup staging files
echo.
echo [5/5] Cleaning staging files...
ssh %SSH_BASE% root@%ROUTER_IP% "rm -rf %REMOTE_DIR%" >nul 2>&1
if errorlevel 1 (
    echo [WARN] Could not remove remote staging directory: %REMOTE_DIR%
) else (
    echo [OK] Removed remote staging directory: %REMOTE_DIR%
)

REM Done
echo.
echo =======================================================
echo  Done! Open http://%ROUTER_IP%:!VERIFY_PORT!/management.html
echo  Installer: %INSTALLER% (%BIN_ARCH%)
if "%ONLY_BINARY%"=="1" echo  Mode: only-binary
echo =======================================================
echo.

endlocal
