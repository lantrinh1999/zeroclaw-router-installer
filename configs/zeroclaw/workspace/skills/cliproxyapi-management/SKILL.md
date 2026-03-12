---
name: cliproxyapi-management
description: Quản lý toàn diện CLIProxyAPI (LLM proxy) - config, accounts, monitoring, troubleshooting
version: 1.0.0
---

# CLIProxyAPI Management

CLIProxyAPI là LLM proxy chạy trên router, round-robin ~52 Codex free accounts để cung cấp API cho ZeroClaw.

## Thông tin cơ bản

- **Binary:** `/opt/cliproxyapi/cli-proxy-api`
- **Config:** `/opt/cliproxyapi/config.yaml`
- **Auth dir:** `/opt/cliproxyapi/auth/` (chứa JSON credentials)
- **Init script:** `/etc/init.d/cliproxyapi`
- **Port:** 8317
- **API endpoint:** `http://127.0.0.1:8317/v1/chat/completions`
- **API key:** `sk-1234567890`
- **Routing:** round-robin
- **Chỉ hỗ trợ:** `/v1/chat/completions` (KHÔNG có responses API)

## CẢNH BÁO - KHÔNG ĐƯỢC THAY ĐỔI

```
request-retry: 10        # KHÔNG ĐƯỢC GIẢM
max-retry-credentials: 10 # KHÔNG ĐƯỢC GIẢM
```
Hai giá trị này đã được user lock cứng. Giảm xuống sẽ gây lỗi khi nhiều account bị rate-limit.

## Quản lý service

```bash
# Xem trạng thái
/etc/init.d/cliproxyapi status
ps w | grep cli-proxy | grep -v grep

# Restart
/etc/init.d/cliproxyapi restart

# Stop / Start
/etc/init.d/cliproxyapi stop
/etc/init.d/cliproxyapi start

# Xem log
logread | grep cli-proxy | tail -30

# Kiểm tra port
netstat -tlnp | grep 8317
```

## Xem config hiện tại

```bash
cat /opt/cliproxyapi/config.yaml
```

## Config đầy đủ (tham khảo)

```yaml
host: "0.0.0.0"
port: 8317
tls:
  enable: false
remote-management:
  allow-remote: true
  secret-key: "<bcrypt hash>"
  disable-control-panel: true
auth-dir: "/opt/cliproxyapi/auth"
api-keys:
  - "sk-1234567890"
debug: false
request-retry: 10              # SỐ LẦN RETRY REQUEST - KHÔNG GIẢM
max-retry-credentials: 10      # SỐ CREDENTIAL THỬ LẠI - KHÔNG GIẢM
max-retry-interval: 10         # Giây giữa các retry
nonstream-keepalive-interval: 10
quota-exceeded:
  switch-project: true
  switch-preview-model: true
routing:
  strategy: "round-robin"
logs-max-total-size-mb: 5
usage-statistics-enabled: false
commercial-mode: true
```

## Quản lý accounts (credentials)

```bash
# Đếm accounts
ls /opt/cliproxyapi/auth/ | wc -l

# Liệt kê accounts
ls /opt/cliproxyapi/auth/

# Xem chi tiết 1 account
cat /opt/cliproxyapi/auth/<filename>.json

# Thêm account: copy file JSON vào auth dir, restart
# Xoá account: xoá file JSON, restart
```

## Test API

```bash
# Quick test
curl -s http://127.0.0.1:8317/v1/chat/completions \
  -H "Authorization: Bearer sk-1234567890" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-5.2-codex","messages":[{"role":"user","content":"hi"}],"max_tokens":10}'

# Test health (xem có phản hồi không)
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8317/v1/models
```

## Monitoring

```bash
# Xem log errors
logread | grep cli-proxy | grep -i error | tail -20

# Xem log rate limit / quota
logread | grep cli-proxy | grep -iE "rate|limit|quota|429" | tail -20

# Xem log retry
logread | grep cli-proxy | grep -i retry | tail -10

# RAM usage
ps w | grep cli-proxy | grep -v grep
```

## Troubleshooting

### API trả 404
- ZeroClaw phải dùng `provider_api = "open-ai-chat-completions"` trong config
- Base URL phải là `http://127.0.0.1:8317/v1` (có `/v1`)
- CLIProxyAPI chỉ hỗ trợ `/v1/chat/completions`, KHÔNG có responses API

### Request timeout / chậm
- Kiểm tra log: `logread | grep cli-proxy | tail -30`
- Nhiều account bị rate-limit -> cliproxy tự rotate sang account khác
- KHÔNG giảm request-retry và max-retry-credentials

### Service không start
- Kiểm tra port 8317 có bị chiếm: `netstat -tlnp | grep 8317`
- Kiểm tra binary: `ls -la /opt/cliproxyapi/cli-proxy-api`
- Kiểm tra config YAML syntax: `cat /opt/cliproxyapi/config.yaml`

### Thêm account mới
1. Tạo file JSON trong `/opt/cliproxyapi/auth/`
2. Format: `codex-<id>-<email>-free.json`
3. Restart: `/etc/init.d/cliproxyapi restart`

## Liên kết với ZeroClaw

ZeroClaw config cần đúng các giá trị sau để dùng CLIProxyAPI:
```toml
default_provider = "custom:http://127.0.0.1:8317/v1"
provider_api = "open-ai-chat-completions"
default_model = "gpt-5.2-codex"
api_key = "sk-1234567890"
```

Tiếng Việt.
