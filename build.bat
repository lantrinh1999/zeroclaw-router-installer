@echo off
chcp 65001 >nul 2>&1
REM =======================================================
REM ZeroClaw + CLIProxyAPI Cross-Compile Build Script
REM =======================================================
REM Chạy trên Windows. Cần Docker Desktop + Git.
REM Source code tự clone vào source/ nếu chưa có.
REM
REM Usage:
REM   build.bat                  - Interactive menu
REM   build.bat aarch64          - Build cho aarch64
REM   build.bat mips32r2         - Build cho MIPS32r2
REM   build.bat all              - Build tất cả

setlocal enabledelayedexpansion

set SCRIPT_DIR=%~dp0
set OUTPUT_DIR=%SCRIPT_DIR%binaries
set SOURCE_DIR=%SCRIPT_DIR%source

REM -- GitHub Repos ----------------------------------
set ZEROCLAW_REPO=https://github.com/zeroclaw-labs/zeroclaw.git
set CLIPROXY_REPO=https://github.com/router-for-me/CLIProxyAPI.git

set ZEROCLAW_SRC=%SOURCE_DIR%\zeroclaw
set CLIPROXY_SRC=%SOURCE_DIR%\CLIProxyAPI

if "%CARGO_PROFILE%"=="" set CARGO_PROFILE=release

REM -- Check Docker ----------------------------------
docker --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker not found. Install Docker Desktop.
    exit /b 1
)

REM -- Parse args or show menu -------------------------
if "%1"=="" goto :menu
if "%1"=="aarch64" ( call :ensure_source & goto :build_aarch64 )
if "%1"=="mips32r2" ( call :ensure_source & goto :build_mips32r2 )
if "%1"=="all" ( call :ensure_source & goto :build_all )
if "%1"=="--help" goto :help
if "%1"=="-h" goto :help
echo [ERROR] Unknown architecture: %1
goto :help

:menu
echo.
echo =======================================================
echo  ZeroClaw Build Tool
echo =======================================================
echo.
echo  Source code: %SOURCE_DIR%\
if exist "%ZEROCLAW_SRC%\Cargo.toml" (echo    ZeroClaw:    found) else (echo    ZeroClaw:    not found - will clone)
if exist "%CLIPROXY_SRC%" (echo    CLIProxyAPI: found) else (echo    CLIProxyAPI: not found - will clone)
echo.
echo  Available architectures:
echo    1) aarch64   - ARM64 (OpenWrt routers, RPi 4+)
echo    2) mips32r2  - MIPS32r2 LE (Creality K1, MIPS routers)
echo    3) all       - Build tat ca
echo    q) Quit
echo.
set /p CHOICE="  Chon kien truc [1/2/3/q]: "

if "%CHOICE%"=="1" ( call :ensure_source & goto :build_aarch64 )
if "%CHOICE%"=="2" ( call :ensure_source & goto :build_mips32r2 )
if "%CHOICE%"=="3" ( call :ensure_source & goto :build_all )
if "%CHOICE%"=="q" goto :quit
echo [ERROR] Invalid choice
goto :menu

REM -- Source Management -----------------------------
:ensure_source
if not exist "%SOURCE_DIR%" mkdir "%SOURCE_DIR%"
echo.
goto :eof

REM -- Build targets ---------------------------------
:build_aarch64
set ARCH=aarch64
set RUST_TARGET=aarch64-unknown-linux-musl
set GO_ARCH=arm64
set GO_EXTRA=
call :do_build
goto :summary

:build_mips32r2
set ARCH=mips32r2
set RUST_TARGET=mipsel-unknown-linux-musl
set GO_ARCH=mipsle
set GO_EXTRA=GOMIPS=softfloat
call :do_build
goto :summary

:build_all
call :build_aarch64
call :build_mips32r2
goto :summary

:do_build
echo.
echo -- Building %ARCH% (target: %RUST_TARGET%) --
set ARCH_OUT=%OUTPUT_DIR%\%ARCH%
if not exist "%ARCH_OUT%" mkdir "%ARCH_OUT%"

REM Build ZeroClaw (Rust)
if exist "%ZEROCLAW_SRC%\Cargo.toml" (
    echo [INFO] Building ZeroClaw ^(%ARCH%^)...
    docker run --rm -v "%ZEROCLAW_SRC%:/app" -v "%ARCH_OUT%:/output" -w /app --platform linux/amd64 rust:1.93-slim sh -c "apt-get update -qq && apt-get install -y -qq musl-tools pkg-config >/dev/null 2>&1 && rustup target add %RUST_TARGET% 2>/dev/null && cargo build --profile %CARGO_PROFILE% --target %RUST_TARGET% --locked 2>&1 && cp target/%RUST_TARGET%/%CARGO_PROFILE%/zeroclaw /output/zeroclaw && strip /output/zeroclaw 2>/dev/null; echo Done"
    echo [OK] zeroclaw built
) else (
    echo [WARN] ZeroClaw source not found
)

REM Build CLIProxyAPI (Go)
if exist "%CLIPROXY_SRC%\go.mod" (
    echo [INFO] Building CLIProxyAPI ^(%ARCH%^) - Go...
    docker run --rm -v "%CLIPROXY_SRC%:/app" -v "%ARCH_OUT%:/output" -w /app --platform linux/amd64 golang:1.23-alpine sh -c "CGO_ENABLED=0 GOOS=linux GOARCH=%GO_ARCH% %GO_EXTRA% go build -ldflags='-s -w' -o /output/cli-proxy-api . 2>&1; echo Done"
    echo [OK] cli-proxy-api built
) else if exist "%CLIPROXY_SRC%\Cargo.toml" (
    echo [INFO] Building CLIProxyAPI ^(%ARCH%^) - Rust...
    docker run --rm -v "%CLIPROXY_SRC%:/app" -v "%ARCH_OUT%:/output" -w /app --platform linux/amd64 rust:1.93-slim sh -c "apt-get update -qq && apt-get install -y -qq musl-tools pkg-config >/dev/null 2>&1 && rustup target add %RUST_TARGET% 2>/dev/null && cargo build --profile %CARGO_PROFILE% --target %RUST_TARGET% --locked 2>&1 && cp target/%RUST_TARGET%/%CARGO_PROFILE%/cli-proxy-api /output/cli-proxy-api 2>/dev/null; strip /output/cli-proxy-api 2>/dev/null; echo Done"
    echo [OK] cli-proxy-api built
) else (
    echo [WARN] CLIProxyAPI source not found
)

REM Copy configs (management.html, config.yaml, auth)
set CONFIGS_SRC=%SCRIPT_DIR%configs
if exist "%CONFIGS_SRC%" (
    echo [INFO] Copying configs to %ARCH_OUT%\configs\...
    if not exist "%ARCH_OUT%\configs\cliproxy\static" mkdir "%ARCH_OUT%\configs\cliproxy\static"
    if exist "%CONFIGS_SRC%\cliproxy\config.yaml" copy /Y "%CONFIGS_SRC%\cliproxy\config.yaml" "%ARCH_OUT%\configs\cliproxy\" >nul 2>&1
    if exist "%CONFIGS_SRC%\cliproxy\auth" xcopy /E /I /Y "%CONFIGS_SRC%\cliproxy\auth" "%ARCH_OUT%\configs\cliproxy\auth" >nul 2>&1
    if exist "%CONFIGS_SRC%\cliproxy\static\management.html" (
        copy /Y "%CONFIGS_SRC%\cliproxy\static\management.html" "%ARCH_OUT%\configs\cliproxy\static\" >nul 2>&1
        echo [OK] management.html copied
    ) else (
        echo [WARN] management.html not found in %CONFIGS_SRC%\cliproxy\static\
    )
    if exist "%CONFIGS_SRC%\zeroclaw" xcopy /E /I /Y "%CONFIGS_SRC%\zeroclaw" "%ARCH_OUT%\configs\zeroclaw" >nul 2>&1
) else (
    echo [WARN] Configs directory not found at %CONFIGS_SRC%
)
goto :eof

:summary
echo.
echo =======================================================
echo  Build Summary
echo =======================================================
echo.
for %%a in (aarch64 mips32r2) do (
    echo  %%a:
    if exist "%OUTPUT_DIR%\%%a\zeroclaw" (echo    zeroclaw:        OK) else (echo    zeroclaw:        not built)
    if exist "%OUTPUT_DIR%\%%a\cli-proxy-api" (echo    cli-proxy-api:   OK) else (echo    cli-proxy-api:   not built)
    if exist "%OUTPUT_DIR%\%%a\configs\cliproxy\static\management.html" (echo    management.html: OK) else (echo    management.html: not copied)
    echo.
)
goto :quit

:help
echo Usage: build.bat [architecture]
echo.
echo Architectures:
echo   aarch64   ARM64 (OpenWrt routers)
echo   mips32r2  MIPS32r2 LE (Creality K1)
echo   all       Build all architectures
echo.
echo Source code auto-cloned into source\ (gitignored):
echo   ZeroClaw:    %ZEROCLAW_REPO%
echo   CLIProxyAPI: %CLIPROXY_REPO%

:quit
endlocal
