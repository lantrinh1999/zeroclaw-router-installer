@echo off
chcp 65001 >nul 2>&1
REM =======================================================
REM ZeroClaw Uninstaller for Windows
REM =======================================================
REM Usage: teardown.bat [device-ip]
REM Example: teardown.bat 192.168.81.1

setlocal enabledelayedexpansion

set ROUTER_IP=%1
if "%ROUTER_IP%"=="" set ROUTER_IP=192.168.81.1
set REMOTE_DIR=/tmp/zeroclaw-uninstaller
set SSH_BASE=-o StrictHostKeyChecking=no

echo.
echo =======================================================
echo  ZeroClaw Uninstaller - %ROUTER_IP%
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
ssh %SSH_BASE% root@%ROUTER_IP% "uname -m; (pidof procd >/dev/null 2>&1 && [ -d /etc/init.d ] && [ -d /etc/config ] && echo PLATFORM=procd || ([ -x /opt/bin/opkg ] && echo PLATFORM=entware || echo PLATFORM=unknown))" > %TEMP%\zc_platform.txt 2>&1
if errorlevel 1 (
    echo [ERROR] SSH connection failed
    exit /b 1
)

set PLATFORM=unknown
findstr /C:"PLATFORM=procd" %TEMP%\zc_platform.txt >nul 2>&1
if not errorlevel 1 set PLATFORM=procd

findstr /C:"PLATFORM=entware" %TEMP%\zc_platform.txt >nul 2>&1
if not errorlevel 1 set PLATFORM=entware

del %TEMP%\zc_platform.txt
echo   Platform: %PLATFORM%

if "%PLATFORM%"=="unknown" (
    echo [ERROR] Cannot detect platform
    exit /b 1
)

REM Step 2: Upload
echo.
echo [2/3] Uploading uninstaller...
ssh %SSH_BASE% root@%ROUTER_IP% "rm -rf %REMOTE_DIR%; mkdir -p %REMOTE_DIR%/platforms/%PLATFORM%"
scp -O %SSH_BASE% common.sh root@%ROUTER_IP%:%REMOTE_DIR%/
scp -O %SSH_BASE% platforms\%PLATFORM%\uninstall.sh root@%ROUTER_IP%:%REMOTE_DIR%/platforms/%PLATFORM%/
if errorlevel 1 (
    echo [ERROR] Upload failed
    exit /b 1
)
echo [OK] Uploaded

REM Step 3: Run
echo.
echo [3/3] Running uninstaller...
echo -------------------------------------
ssh %SSH_BASE% root@%ROUTER_IP% "cd %REMOTE_DIR% && sh platforms/%PLATFORM%/uninstall.sh"
echo -------------------------------------
echo.

endlocal
