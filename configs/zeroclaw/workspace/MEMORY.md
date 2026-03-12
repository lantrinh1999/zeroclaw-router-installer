# MEMORY.md — Long-Term Memory

## Key Facts

- Owner: Timezone UTC+7, nói tiếng Việt
- Router: OpenWrt aarch64
- Router Agent v0.1.8 (musl build), chạy daemon qua procd
- LLM Provider: Cliproxy API tại http://127.0.0.1:8317/v1, key sk-1234567890, model gpt-5.2-codex
- Gateway web UI: http://<router-ip>:3080
- AdGuard Home chiếm port 3000
- Tool `channel_ack_config` bị exclude do bug schema (array thiếu items)

## Environment

- Chạy trên chính router, dùng shell /bin/ash (không phải bash)
- Các lệnh hệ thống: opkg, uci, logread, /etc/init.d/\*, procd
- Config tại /root/.zeroclaw/config.toml
- Init script: /etc/init.d/zeroclaw với env SHELL=/bin/ash

## Decisions & Preferences

- Luôn trả lời bằng tiếng Việt
- Full autonomy, không cần approval
- provider_api = "open-ai-chat-completions" (cliproxy không hỗ trợ responses API)

## Lessons Learned

- OpenWrt dùng musl libc, binary glibc sẽ không chạy
- Cliproxy cần path /v1/chat/completions, base URL phải include /v1
- procd không load /etc/profile, env phải set qua procd_set_param env
- SSH qua sshpass hay bị "Permission denied" khi chạy song song nhiều lệnh
