#!/data/data/com.termux/files/usr/bin/sh

# Atlas-M30 Boot Script
# Runs on device startup via Termux:Boot.
# Ensures wake lock, service daemon, and all critical services are active.

# 1. Acquire wake lock to prevent Android from sleeping.
termux-wake-lock

# 2. Load runit service daemon if available.
if [ -f "$PREFIX/etc/profile.d/start-services.sh" ]; then
    . "$PREFIX/etc/profile.d/start-services.sh"
fi

# 3. Start supervised services; ignore failures so script continues.
sv up sshd 2>/dev/null || true
sv up nginx 2>/dev/null || true
sv up cloudflared 2>/dev/null || true

# 4. Fallback direct starts when service manager is unavailable.
pgrep -x sshd >/dev/null || sshd
pgrep -x nginx >/dev/null || nginx
pgrep -x cloudflared >/dev/null || cloudflared tunnel run &
