# =======================================================
# ZeroClaw Test Router - Multi-Device Dockerfile
# =======================================================
# Shared Dockerfile cho tất cả thiết bị.
# Device-specific configs nằm trong devices/<DEVICE>/
#
# Build: docker compose -f docker/docker-compose.yml build
# Thêm thiết bị mới: tạo devices/<tên>/ với release files + ubus-board.json
# =======================================================

ARG DEVICE=jdc1800pro
FROM arm64v8/alpine:3.19

# ==========================
# 1. Packages (barebones + build deps)
# ==========================
RUN apk add --no-cache \
    openssh-server \
    busybox-extras \
    procps \
    shadow \
    bash \
    build-base \
    pkgconf \
    git \
    curl \
    openssl-dev \
    perl \
    ca-certificates \
    && rm -rf /var/cache/apk/*

# ==========================
# 1b. Rust Toolchain
# ==========================
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable \
    && chmod -R a+rX /usr/local/cargo /usr/local/rustup

# ==========================
# 2. SSH Server
# ==========================
RUN echo "root:root" | chpasswd \
    && ssh-keygen -A \
    && mkdir -p /var/run/sshd \
    && sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && echo "PermitRootLogin yes" >> /etc/ssh/sshd_config

# ==========================
# 3. OpenWrt Filesystem
# ==========================
RUN mkdir -p /etc/config /etc/init.d /etc/rc.d /overlay /opt /usr/bin /root

# ==========================
# 4. Fake procd (compiled)
# ==========================
RUN apk add --no-cache gcc musl-dev \
    && printf '#include <unistd.h>\nint main(){while(1)pause();return 0;}\n' > /tmp/procd.c \
    && gcc -static -o /usr/sbin/procd /tmp/procd.c \
    && rm /tmp/procd.c \
    && apk del gcc musl-dev \
    && chmod +x /usr/sbin/procd

# ==========================
# 5. Shared fake tools
# ==========================
COPY scripts/fake-opkg.sh /usr/bin/opkg
COPY scripts/fake-logread.sh /usr/sbin/logread
COPY scripts/fake-ubus.sh /usr/bin/ubus
RUN chmod +x /usr/bin/opkg /usr/sbin/logread /usr/bin/ubus \
    && touch /tmp/logread.log

# ==========================
# 6. Device-specific configs
# ==========================
ARG DEVICE
COPY devices/${DEVICE}/kwrt_release  /etc/kwrt_release
COPY devices/${DEVICE}/openwrt_release /etc/openwrt_release
COPY devices/${DEVICE}/os-release    /etc/os-release
COPY devices/${DEVICE}/ubus-board.json /etc/device/ubus-board.json
COPY devices/${DEVICE}/config-system /etc/config/system

# ==========================
# 7. Entrypoint
# ==========================
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22 3080 8317
ENTRYPOINT ["/entrypoint.sh"]
