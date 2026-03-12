# ZeroClaw Router Installer

Bộ cài đặt tự động **[ZeroClaw](https://github.com/zeroclaw-labs/zeroclaw)** + **[CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI)** lên router — biến router thành **AI agent** điều khiển qua **Telegram**.

- **ZeroClaw**: AI agent đa năng chạy 24/7 trên router, tự quản lý hệ thống, chẩn đoán mạng, nghiên cứu web
- **CLIProxyAPI**: Proxy chuyển đổi API ChatGPT Codex (miễn phí) thành OpenAI-compatible endpoint

## Features

- 🤖 **8 AI agents** tích hợp sẵn (giám sát hệ thống, phân tích log, chẩn đoán mạng, quản lý WiFi, ...)
- 🛠 **16 skills** cho OpenWrt (bandwidth monitor, DNS/adblock, port forward, firewall, speedtest, ...)
- 📱 **Điều khiển qua Telegram** — gửi tin nhắn, nhận kết quả
- 🌐 **Multi-platform**: OpenWrt, kWrt, ImmortalWrt, Buildroot, Entware
- 🏗 **Multi-arch**: aarch64 (ARM64), MIPS32r2
- 🔐 **Credential encryption**: Tự mã hóa config nhạy cảm sau cài đặt
- 📊 **Management Web UI**: Quản lý Codex accounts tại `http://<ip>:8317/management.html`

## Supported Platforms

| Platform    | Init System | Architecture      | OS                         | Status                |
| ----------- | ----------- | ----------------- | -------------------------- | --------------------- |
| **procd**   | procd       | aarch64 (ARM64)   | OpenWrt, kWrt, ImmortalWrt | ✅ Tested             |
| **entware** | SysV        | MIPS32r2 (mipsle) | Buildroot / Linux          | 🔧 Ready (cần binary) |
| **entware** | SysV        | aarch64 (ARM64)   | Linux / Buildroot          | 🔧 Ready              |

> **Detection thông minh**: Installer detect platform bằng cấu trúc hệ thống (`pidof procd` + `/etc/init.d` + `/etc/config`) thay vì tên OS — nên tự động hỗ trợ mọi firmware dựa trên procd.

## Yêu cầu

| Thông số     | Yêu cầu                            |
| ------------ | ---------------------------------- |
| **RAM**      | >= 512MB (khuyến nghị 1GB)         |
| **Disk**     | >= 100MB trống                     |
| **Shell**    | /bin/ash hoặc /bin/sh              |
| **Telegram** | Bot Token + User ID (**bắt buộc**) |

### Yêu cầu thêm cho Entware/Buildroot

- Kernel >= 3.4
- `/opt/` writable (mount USB/SD nếu cần)
- Entware sẽ tự cài nếu chưa có

## Cài đặt

### Quick Setup (1 lệnh)

**Mac / Linux:**

```bash
git clone https://github.com/lantrinh1999/zeroclaw-router-installer.git
cd zeroclaw-router-installer
sh setup.sh <device-ip>
```

**Windows (CMD):**

```cmd
git clone https://github.com/lantrinh1999/zeroclaw-router-installer.git
cd zeroclaw-router-installer
setup.bat <device-ip>
```

Script tự động:

1. SSH connect (nhập password **1 lần** — Mac/Linux dùng SSH multiplexing, Windows tự setup SSH key)
2. Detect platform (arch + OS + init system + RAM/disk)
3. Hiển thị kết quả, yêu cầu xác nhận
4. **Telegram setup** — nhập Bot Token + User ID, test gửi tin nhắn
5. Upload binaries + configs phù hợp
6. Chạy installer đúng platform
7. Verify (kiểm tra ports + HTTP access)
8. Lưu install log local (`last-install.log`) + remote (`/tmp/zeroclaw-install.log`)

<details>
<summary>Cài thủ công (nhiều bước)</summary>

```bash
# 1. Clone repo
git clone https://github.com/lantrinh1999/zeroclaw-router-installer.git
cd zeroclaw-router-installer

# 2. Copy lên device
ssh root@<device-ip> mkdir -p /tmp/zeroclaw-router-installer
scp -O -r * root@<device-ip>:/tmp/zeroclaw-router-installer/

# 3. SSH vào device và chạy installer phù hợp
ssh root@<device-ip>
cd /tmp/zeroclaw-router-installer

# procd (OpenWrt/kWrt/ImmortalWrt):
sh platforms/procd/install.sh

# Entware/Buildroot (MIPS/ARM):
sh platforms/entware/install.sh
```

</details>

## Telegram (bắt buộc)

ZeroClaw cần Telegram để gửi thông báo và nhận lệnh. Script sẽ hỏi:

1. **Bot Token** — tạo bot qua [@BotFather](https://t.me/BotFather)
2. **User ID** — lấy qua [@userinfobot](https://t.me/userinfobot)

Script tự gửi tin nhắn test trước khi cài. Nếu test thất bại, sẽ yêu cầu nhập lại.

## Sau khi cài

### Thêm Codex accounts (bắt buộc)

CLIProxyAPI cần tài khoản ChatGPT free để gọi API Codex miễn phí. **Càng nhiều tài khoản, càng ít bị rate-limit.** Khuyến nghị **50-100 tài khoản** để dùng 24/7 không gián đoạn.

1. Mở `http://<device-ip>:8317/management.html`
2. Đăng nhập bằng secret key (mặc định: `123456`)
3. Vào tab **OAuth Login**
4. Chọn **Codex OAuth Login**
5. Click **Open Link** → mở trang đăng nhập ChatGPT
6. Đăng nhập (hoặc đăng ký) tài khoản ChatGPT free
7. Sau khi đăng nhập, trình duyệt sẽ redirect tới URL dạng:
   ```
   http://localhost:1455/auth/callback?code=xxxxxxxx
   ```
8. **Copy toàn bộ URL** đó, quay lại Management UI
9. Dán vào ô **Callback URL** và nhấn **Submit**
10. Account sẽ được tự động thêm vào CLIProxyAPI ✅

> **Lặp lại** bước 4-10 cho mỗi tài khoản ChatGPT muốn thêm.

### CLIProxyAPI Management UI

Truy cập: `http://<device-ip>:8317/management.html`

**Đăng nhập:** Secret key mặc định là `123456` (cấu hình trong `/opt/cliproxyapi/config.yaml` > `remote-management.secret-key`).

## Kiến trúc mạng

```
[Telegram] ←→ [ZeroClaw :3080] ←→ [CLIProxyAPI]
                                        │
                              socat :8317 (IPv4)
                                        ↓
                              cli-proxy-api :8318 (IPv6)
                                        ↓
                              [ChatGPT Codex API]
```

- **ZeroClaw** (port 3080): AI agent, dùng provider `custom:http://127.0.0.1:8317/v1`
- **CLIProxyAPI** bind IPv6 `:::8318`, **socat** bridge IPv4:8317 → IPv6:8318
- API key nội bộ: `sk-1234567890` (local, không nhạy cảm)
- Không cần cấu hình thêm — tất cả pre-configured

## Services

| Service     | Port                      | procd                                          | Entware/SysV                                          |
| ----------- | ------------------------- | ---------------------------------------------- | ----------------------------------------------------- |
| ZeroClaw    | 3080                      | `/etc/init.d/zeroclaw start\|stop\|restart`    | `/opt/etc/init.d/S99zeroclaw start\|stop\|restart`    |
| CLIProxyAPI | 8317 (socat) / 8318 (api) | `/etc/init.d/cliproxyapi start\|stop\|restart` | `/opt/etc/init.d/S98cliproxyapi start\|stop\|restart` |

## Cấu trúc project

```
zeroclaw-router-installer/
├── setup.sh / setup.bat           # Host: detect + upload + install
├── teardown.sh / teardown.bat     # Host: detect + upload + uninstall
├── common.sh                      # Shared functions (logging, detection, services)
│
├── platforms/
│   ├── procd/                     # procd-based (OpenWrt, kWrt, ImmortalWrt)
│   │   ├── install.sh
│   │   ├── uninstall.sh
│   │   └── init-scripts/          # procd service scripts
│   └── entware/                   # Entware/Buildroot (MIPS32r2, aarch64)
│       ├── install.sh
│       ├── uninstall.sh
│       └── init-scripts/          # SysV init scripts
│
├── binaries/
│   ├── aarch64/                   # ARM64 binaries
│   └── mips32r2/                  # MIPS binaries
│
├── configs/
│   ├── zeroclaw/                  # ZeroClaw config + workspace + skills
│   └── cliproxy/                  # CLIProxyAPI config + auth + UI
│
├── build.sh / build.bat           # Cross-compile (Docker-based)
└── source/                        # Auto-cloned source (gitignored)
```

## Cấu trúc cài đặt (trên device)

### procd (OpenWrt/kWrt/ImmortalWrt)

```
/usr/bin/zeroclaw                    # Binary ZeroClaw
/root/.zeroclaw/
├── config.toml                      # Config chính (8 agents, Telegram, ...)
└── workspace/
    ├── *.md                         # Workspace files (IDENTITY, MEMORY, TOOLS, ...)
    └── skills/*/SKILL.md            # 16 skills

/opt/cliproxyapi/
├── cli-proxy-api                    # Binary CLIProxyAPI
├── config.yaml                      # Config (port 8318, round-robin)
├── auth/*.json                      # Codex credentials
└── static/management.html           # Web UI

/etc/init.d/
├── zeroclaw                         # procd init script (START=99)
└── cliproxyapi                      # procd init script (START=98, + socat bridge)
```

### Entware/Buildroot

```
/opt/bin/zeroclaw                    # Binary ZeroClaw
/root/.zeroclaw/                     # Config (giống procd)

/opt/cliproxyapi/                    # CLIProxyAPI (giống procd)

/opt/etc/init.d/
├── S99zeroclaw                      # SysV init script
└── S98cliproxyapi                   # SysV init script

/opt/var/log/
├── zeroclaw.log                     # ZeroClaw logs
└── cliproxyapi.log                  # CLIProxyAPI logs
```

## Build Binaries

```bash
# Interactive menu — chọn kiến trúc, tự build
sh build.sh          # Mac/Linux
build.bat            # Windows

# Hoặc chỉ định trực tiếp
sh build.sh aarch64   # Build cho ARM64
sh build.sh mips32r2  # Build cho MIPS32r2
sh build.sh all       # Build tất cả
```

Build script tự động:

- Clone source từ GitHub nếu chưa có (vào `source/`, gitignored)
- Build qua Docker (recommended) hoặc native cross-compile
- Output vào `binaries/<arch>/`

**Cần:** Docker Desktop. Override source paths: `ZEROCLAW_SRC`, `CLIPROXY_SRC`.

## Gỡ cài đặt

**Mac / Linux:**

```bash
sh teardown.sh <device-ip>
```

**Windows (CMD):**

```cmd
teardown.bat <device-ip>
```

Script tự động detect platform, backup config (tùy chọn), stop services, xoá toàn bộ files.

<details>
<summary>Gỡ thủ công</summary>

**procd (OpenWrt/kWrt/ImmortalWrt):**

```bash
ssh root@<device-ip>
/etc/init.d/zeroclaw stop && /etc/init.d/zeroclaw disable
/etc/init.d/cliproxyapi stop && /etc/init.d/cliproxyapi disable
killall zeroclaw cli-proxy-api socat 2>/dev/null
rm -f /usr/bin/zeroclaw
rm -rf /opt/cliproxyapi /root/.zeroclaw
rm -f /etc/init.d/zeroclaw /etc/init.d/cliproxyapi
```

**Entware/Buildroot:**

```bash
ssh root@<device-ip>
/opt/etc/init.d/S99zeroclaw stop
/opt/etc/init.d/S98cliproxyapi stop
killall zeroclaw cli-proxy-api socat 2>/dev/null
rm -f /opt/bin/zeroclaw
rm -rf /opt/cliproxyapi /root/.zeroclaw
rm -f /opt/etc/init.d/S99zeroclaw /opt/etc/init.d/S98cliproxyapi
```

</details>

## Demo

https://github.com/lantrinh1999/zeroclaw-router-installer/raw/main/video.mp4
