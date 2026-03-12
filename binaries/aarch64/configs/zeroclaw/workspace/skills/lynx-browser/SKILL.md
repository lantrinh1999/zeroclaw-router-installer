---
name: lynx-browser
description: Text-based web browser dùng lynx/curl trên router
version: 1.0.0
---

# Lynx Browser

Duyệt web bằng text trên router (dùng curl vì lynx có thể chưa cài).

## Lệnh
```bash
# Fetch và render text từ URL
curl -sL "$URL" | sed 's/<[^>]*>//g' | head -100
```

Hoặc nếu có lynx:
```bash
lynx -dump "$URL" | head -100
```

Tiếng Việt.
