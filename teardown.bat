@echo off
chcp 65001 >nul 2>&1
REM =======================================================
REM ZeroClaw Uninstaller for Windows
REM =======================================================
REM Usage: teardown.bat [device-ip] [-p port]
REM Example: teardown.bat 192.168.81.1
REM          teardown.bat localhost -p 2222

setlocal enabledelayedexpansion

REM Parse arguments: teardown.bat [ip] [-p port]
set ROUTER_IP=192.168.81.1
set SSH_PORT=22

:parse_args
if "%~1"=="" goto :args_done
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
set REMOTE_DIR=/tmp/zeroclaw-uninstaller
set SSH_BASE=-p %SSH_PORT% -o StrictHostKeyChecking=no
set SCP_BASE=-P %SSH_PORT% -O -o StrictHostKeyChecking=no

echo.
echo =======================================================
echo  ZeroClaw Uninstaller - %ROUTER_IP% (port %SSH_PORT%)
echo =======================================================
echo.

REM Step 0: Setup SSH key auth (nhap password 1 lan, lan sau khong can)
echo [0/3] Setting up SSH connection...

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

REM Step 1: Detect platform
echo [1/3] Detecting platform...
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

ssh %SSH_BASE% root@%ROUTER_IP% "cd %REMOTE_DIR% && . ./common.sh >/dev/null 2>&1 && detect_platform >/dev/null 2>&1 && print_platform_exports" > %TEMP%\zc_platform.txt 2>&1
if errorlevel 1 (
    echo [ERROR] SSH connection failed
    exit /b 1
)

set ARCH=unknown
set BIN_ARCH=unknown
set INIT_TYPE=
set EXEC_MODE=
set INSTALLER=unknown
set RESULT=

for /f "usebackq tokens=1,* delims==" %%A in ("%TEMP%\zc_platform.txt") do (
    if /i "%%A"=="ARCH" set ARCH=%%B
    if /i "%%A"=="BIN_ARCH" set BIN_ARCH=%%B
    if /i "%%A"=="INIT_TYPE" set INIT_TYPE=%%B
    if /i "%%A"=="EXEC_MODE" set EXEC_MODE=%%B
    if /i "%%A"=="INSTALLER" set INSTALLER=%%B
    if /i "%%A"=="RESULT" set RESULT=%%B
)

echo   Installer: %INSTALLER% (%ARCH%, init=%INIT_TYPE%, mode=%EXEC_MODE%)

if "%RESULT%"=="FAIL" (
    del %TEMP%\zc_platform.txt >nul 2>&1
    echo [ERROR] Device not compatible. Cannot uninstall safely.
    exit /b 1
)
if "%INSTALLER%"=="unknown" (
    del %TEMP%\zc_platform.txt >nul 2>&1
    echo [ERROR] Cannot detect installer
    exit /b 1
)
del %TEMP%\zc_platform.txt >nul 2>&1

REM Step 2: Upload
echo.
echo [2/3] Uploading uninstaller...
ssh %SSH_BASE% root@%ROUTER_IP% "rm -rf %REMOTE_DIR%; mkdir -p %REMOTE_DIR%/installers/%INSTALLER%"
scp %SCP_BASE% common.sh root@%ROUTER_IP%:%REMOTE_DIR%/
scp %SCP_BASE% installers\%INSTALLER%\uninstall.sh root@%ROUTER_IP%:%REMOTE_DIR%/installers/%INSTALLER%/
if errorlevel 1 (
    echo [ERROR] Upload failed
    exit /b 1
)
echo [OK] Uploaded

REM Step 3: Run
echo.
echo [3/3] Running uninstaller...
echo -------------------------------------
ssh %SSH_BASE% root@%ROUTER_IP% "cd %REMOTE_DIR% && sh installers/%INSTALLER%/uninstall.sh"
echo -------------------------------------
echo.

endlocal
