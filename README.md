# ZeroClaw Router Installer

Bộ cài đặt tự động **[ZeroClaw](https://github.com/zeroclaw-labs/zeroclaw)** + **[CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI)** lên router hoặc thiết bị Linux nhúng, biến thiết bị thành **AI agent** điều khiển qua **Telegram**.

- **ZeroClaw**: AI agent chạy 24/7, tự quản lý hệ thống, chẩn đoán mạng, nghiên cứu web
- **CLIProxyAPI**: Proxy chuyển đổi ChatGPT Codex thành OpenAI-compatible endpoint

## Features

- 🤖 Nhiều AI agents tích hợp sẵn cho vận hành router
- 🛠 **17 skills** cho OpenWrt (bandwidth monitor, DNS/adblock, port forward, firewall, speedtest, ...)
- 📱 Điều khiển qua Telegram, có bước test Bot Token + User ID trước khi cài
- 🌐 Detect runtime capabilities để chọn installer phù hợp, không phụ thuộc tên firmware
- 🔀 Hỗ trợ 3 installer strategies: `procd`, `entware`, `manual`
- 🔐 Tự mã hóa config nhạy cảm sau khi cài
- 📊 Management Web UI tại `http://<ip>:8317/management.html`

## Supported Installers

| Installer   | Service backend       | Architecture      | Hệ điều hành / môi trường                                           | Status                                    |
| ----------- | --------------------- | ----------------- | ------------------------------------------------------------------- | ----------------------------------------- |
| **procd**   | procd managed service | aarch64           | OpenWrt, kWrt, ImmortalWrt và firmware dùng procd                   | ✅ Tested                                 |
| **entware** | Entware SysV          | aarch64, MIPS32r2 | Linux / Buildroot có `/opt/etc/init.d`                              | ✅ Ready khi backend Entware đã hiện diện |
| **manual**  | start/stop scripts    | aarch64, MIPS32r2 | Linux / Buildroot / môi trường không có backend service được hỗ trợ | ✅ Fallback, không auto-start             |

> **Detection thông minh**: installer đọc kiến trúc, PID 1, init system, install layout writable và RAM/disk để tự chọn `procd`, `entware` hoặc `manual`.
>
> Mapping hiện tại trong code:
>
> - có `procd` backend -> `installers/procd`
> - có Entware SysV backend (`/opt/etc/init.d`) -> `installers/entware`
> - không có backend được hỗ trợ nhưng vẫn có layout writable -> `installers/manual`
> - thiếu binary tương thích hoặc thiếu RAM/disk -> fail

> **Binary note**: repo hiện có sẵn `binaries/aarch64/`. Thư mục `binaries/mips32r2/` mới là placeholder/tài liệu, nên nếu target MIPS thì cần build trước bằng `sh build.sh mips32r2` hoặc `build.bat`.

## Yêu cầu

| Thông số         | Yêu cầu                                       |
| ---------------- | --------------------------------------------- |
| **RAM**          | >= 256MB (khuyến nghị 512MB hoặc 1GB)         |
| **Disk**         | >= 100MB trống                                |
| **Architecture** | binary targets hiện có: `aarch64`, `mips32r2` |
| **Shell**        | `/bin/ash` hoặc `/bin/sh`                     |
| **Telegram**     | Bot Token + User ID (**bắt buộc**)            |

Detector hiện map:

- `uname -m = aarch64` hoặc `arm64` -> `binaries/aarch64`
- `uname -m = mips`, `mipsel`, `mips64`, hoặc `mips64el` -> `binaries/mips32r2`

### Yêu cầu thêm theo installer

- **Entware**: kernel >= 3.4, `/opt/` writable, và để auto-select từ `setup.sh` / `setup.bat` thì backend Entware phải đã hiện diện (`/opt/etc/init.d`). Nếu chỉ có `/opt/` writable nhưng chưa có backend này, detector sẽ chọn `manual`.
- **Bootstrap Entware thủ công**: nếu muốn script tự cài Entware khi máy chưa có backend Entware, chạy trực tiếp `installers/entware/install.sh` trên device.
- **Manual**: cần ít nhất một trong các path writable: `/opt/bin`, `/usr/local/bin`, hoặc `/usr/bin`. Đây là fallback cho các hệ có thể chạy binary nhưng repo chưa có managed backend native.

## Cài đặt

### Quick Setup (khuyến nghị)

**Mac / Linux**

```bash
git clone https://github.com/lantrinh1999/zeroclaw-router-installer.git
cd zeroclaw-router-installer
sh setup.sh <device-ip>
```

**Windows (CMD)**

```cmd
git clone https://github.com/lantrinh1999/zeroclaw-router-installer.git
cd zeroclaw-router-installer
setup.bat <device-ip>
```

`setup.sh` và `setup.bat` sẽ:

1. SSH vào device
2. Upload `common.sh` để detect runtime từ xa
3. Tự chọn `installers/procd`, `installers/entware`, hoặc `installers/manual`
4. Hỏi Telegram Bot Token + User ID, gửi test message
5. Upload binary + config đúng kiến trúc
6. Chạy installer đúng strategy
7. Verify Management UI

Khác biệt giữa hai host scripts:

- `setup.sh` reuse SSH session và sau khi install sẽ sync lại `config.toml` của ZeroClaw về `127.0.0.1:8317`
- `setup.bat` dùng cùng detector và cũng ép lại `config.toml` về `127.0.0.1:8317` ở bước verify

> **Lưu ý Windows:** `setup.bat` cần Windows 10+ có `ssh`, `scp`, `tar`, và `curl`.

<details>
<summary>Cài trực tiếp trên device</summary>

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

# OpenWrt / procd
sh installers/procd/install.sh

# Entware SysV
sh installers/entware/install.sh

# Fallback cho hệ không có backend service tương thích
sh installers/manual/install.sh
```

</details>

## Telegram (bắt buộc)

ZeroClaw cần Telegram để gửi thông báo và nhận lệnh. Installer sẽ hỏi:

1. **Bot Token**: tạo bot qua [@BotFather](https://t.me/BotFather)
2. **User ID**: lấy qua [@userinfobot](https://t.me/userinfobot)

Script sẽ gửi tin nhắn test trước khi tiếp tục. Nếu test thất bại, installer sẽ yêu cầu nhập lại.

## Sau khi cài

### Mở Management UI

Ưu tiên dùng URL mà installer vừa in ra ở cuối quá trình cài.

Nếu mở thủ công:

1. Mở `http://<device-ip>:8317/management.html`

### Thêm Codex accounts

CLIProxyAPI cần tài khoản ChatGPT free để gọi Codex. Càng nhiều tài khoản thì càng ít bị rate-limit. Khuyến nghị 50-100 tài khoản nếu muốn chạy 24/7 liên tục.

1. Mở Management UI
2. Đăng nhập bằng secret key mặc định: `123456`
3. Vào tab **OAuth Login**
4. Chọn **Codex OAuth Login**
5. Nhấn **Open Link**
6. Đăng nhập tài khoản ChatGPT free
7. Khi trình duyệt redirect sang URL dạng:
   ```text
   http://localhost:1455/auth/callback?code=xxxxxxxx
   ```
8. Copy toàn bộ URL đó
9. Quay lại Management UI, dán vào ô **Callback URL**
10. Nhấn **Submit** để thêm account

### Secret key và config CLIProxyAPI

- Secret key mặc định: `123456`
- Port nội bộ/public: `8317`

`config.yaml` thường nằm ở:

- `/opt/cliproxyapi/config.yaml` với `procd`, `entware`, hoặc `manual` dùng `/opt/bin`
- `/usr/local/lib/zeroclaw/cliproxyapi/config.yaml` với `manual` dùng `/usr/local/bin`
- `/usr/lib/zeroclaw/cliproxyapi/config.yaml` với `manual` dùng `/usr/bin`

## Kiến trúc mạng

```text
[Telegram] <-> [ZeroClaw :3080]
                  |
                  +-> custom:http://127.0.0.1:8317/v1
                               |
                        [CLIProxyAPI :8317]
                               |
                        /management.html
```

- **ZeroClaw** luôn được installer rewrite sang provider `custom:http://127.0.0.1:8317/v1`
- **CLIProxyAPI** luôn lắng nghe trên `8317`
- Toàn bộ runtime local chỉ dùng một cổng `8317`

## Services và lệnh hữu ích

| Installer   | ZeroClaw                                                  | CLIProxyAPI                                                  | Logs                                                                |
| ----------- | --------------------------------------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------------- |
| **procd**   | `/etc/init.d/zeroclaw start\|stop\|restart`               | `/etc/init.d/cliproxyapi start\|stop\|restart`               | `logread \| grep zeroclaw`, `logread \| grep cli-proxy`             |
| **entware** | `/opt/etc/init.d/S99zeroclaw start\|stop\|restart`        | `/opt/etc/init.d/S98cliproxyapi start\|stop\|restart`        | `cat /opt/var/log/zeroclaw.log`, `cat /opt/var/log/cliproxyapi.log` |
| **manual**  | `<install-bin-dir>/zeroclaw-service start\|stop\|restart` | `<install-bin-dir>/cliproxyapi-service start\|stop\|restart` | `cat <log-dir>/zeroclaw.log`, `cat <log-dir>/cliproxyapi.log`       |

`<install-bin-dir>` là một trong: `/opt/bin`, `/usr/local/bin`, `/usr/bin`.

## Cấu trúc project

```text
zeroclaw-router-installer/
├── setup.sh / setup.bat           # Host installer
├── teardown.sh / teardown.bat     # Host uninstaller
├── common.sh                      # Shared detection, logging, verification
│
├── installers/
│   ├── procd/                     # OpenWrt / procd
│   ├── entware/                   # Entware SysV
│   └── manual/                    # Fallback mode với service scripts
│
├── binaries/
│   ├── aarch64/
│   └── mips32r2/
│
├── configs/
│   ├── zeroclaw/                  # ZeroClaw config + workspace + skills
│   └── cliproxy/                  # CLIProxyAPI config + auth + static UI
│
├── build.sh / build.bat           # Cross-compile helper
└── source/                        # Source repos (gitignored)
```

## Cấu trúc cài đặt trên device

### procd

```text
/usr/bin/zeroclaw
/root/.zeroclaw/
/opt/cliproxyapi/
/etc/init.d/zeroclaw
/etc/init.d/cliproxyapi
```

### entware

```text
/opt/bin/zeroclaw
/root/.zeroclaw/
/opt/cliproxyapi/
/opt/etc/init.d/S99zeroclaw
/opt/etc/init.d/S98cliproxyapi
/opt/var/log/zeroclaw.log
/opt/var/log/cliproxyapi.log
```

### manual

```text
<install-bin-dir>/zeroclaw
/root/.zeroclaw/
<install-cliproxy-dir>/cli-proxy-api
<install-cliproxy-dir>/config.yaml
<install-bin-dir>/zeroclaw-service
<install-bin-dir>/cliproxyapi-service
<log-dir>/zeroclaw.log
<log-dir>/cliproxyapi.log
```

Giá trị detect được:

- `<install-bin-dir>`: `/opt/bin`, `/usr/local/bin`, hoặc `/usr/bin`
- `<install-cliproxy-dir>`: `/opt/cliproxyapi`, `/usr/local/lib/zeroclaw/cliproxyapi`, hoặc `/usr/lib/zeroclaw/cliproxyapi`
- `<log-dir>`: path writable đầu tiên trong `/var/log`, `/opt/var/log`, `/tmp`

## Build binaries

```bash
# Interactive menu
sh build.sh          # Mac/Linux
build.bat            # Windows

# Hoặc chỉ định kiến trúc
sh build.sh aarch64
sh build.sh mips32r2
sh build.sh all
```

Build script sẽ:

- clone source vào `source/` nếu chưa có
- build qua Docker hoặc native toolchain
- xuất binary vào `binaries/<arch>/`

Biến override: `ZEROCLAW_SRC`, `CLIPROXY_SRC`.

## Gỡ cài đặt

**Mac / Linux**

```bash
sh teardown.sh <device-ip>
```

**Windows (CMD)**

```cmd
teardown.bat <device-ip>
```

`teardown.sh` và `teardown.bat` sẽ detect installer hiện tại (`procd`, `entware`, `manual`), upload đúng uninstaller và cho phép backup config/memory trước khi gỡ.

> **Lưu ý Windows:** `teardown.bat` dùng cùng detector với `teardown.sh` và sẽ chọn đúng `installer` hiện tại. Nếu cần gỡ trực tiếp trên device, dùng `installers/manual/uninstall.sh` cho manual mode.

<details>
<summary>Gỡ trực tiếp trên device</summary>

**procd**

```bash
ssh root@<device-ip>
/etc/init.d/zeroclaw stop && /etc/init.d/zeroclaw disable
/etc/init.d/cliproxyapi stop && /etc/init.d/cliproxyapi disable
killall zeroclaw cli-proxy-api 2>/dev/null
rm -f /usr/bin/zeroclaw
rm -rf /opt/cliproxyapi /root/.zeroclaw
rm -f /etc/init.d/zeroclaw /etc/init.d/cliproxyapi
```

**entware**

```bash
ssh root@<device-ip>
/opt/etc/init.d/S99zeroclaw stop
/opt/etc/init.d/S98cliproxyapi stop
killall zeroclaw cli-proxy-api 2>/dev/null
rm -f /opt/bin/zeroclaw
rm -rf /opt/cliproxyapi /root/.zeroclaw
rm -f /opt/etc/init.d/S99zeroclaw /opt/etc/init.d/S98cliproxyapi
```

**manual**

```bash
ssh root@<device-ip>
/usr/local/bin/zeroclaw-service stop 2>/dev/null || /opt/bin/zeroclaw-service stop 2>/dev/null || /usr/bin/zeroclaw-service stop 2>/dev/null
/usr/local/bin/cliproxyapi-service stop 2>/dev/null || /opt/bin/cliproxyapi-service stop 2>/dev/null || /usr/bin/cliproxyapi-service stop 2>/dev/null
killall zeroclaw cli-proxy-api 2>/dev/null
rm -rf /root/.zeroclaw /opt/cliproxyapi /usr/local/lib/zeroclaw /usr/lib/zeroclaw
rm -f /usr/local/bin/zeroclaw /opt/bin/zeroclaw /usr/bin/zeroclaw
rm -f /usr/local/bin/zeroclaw-service /usr/local/bin/cliproxyapi-service
rm -f /opt/bin/zeroclaw-service /opt/bin/cliproxyapi-service
rm -f /usr/bin/zeroclaw-service /usr/bin/cliproxyapi-service
```

</details>
