# Chapter 3 — Operations & Troubleshooting

> Keep your server running, verify everything works, and fix things when they break.

**Before starting:** Complete [Chapter 1](01-getting-started.md) and [Chapter 2](02-services-and-deployment.md) first.

---

## What This Chapter Covers

- 🚀 Quick-deploy script for setting everything up at once
- ✅ Full verification checklist
- 🔒 Security hardening best practices
- 🔧 Troubleshooting for every common issue

---

## 1. Quick Deploy (One-Shot Setup)

Already finished Chapters 1 and 2 step-by-step? Skip this section.

If you're setting up a **new device** and want to blast through everything at once, here's the complete deploy script. Run this **after** completing the Android preparation steps from [Chapter 1, Section 2](01-getting-started.md#2-prepare-your-android-device).

```bash
# ── 1. Install packages ──
pkg update && pkg upgrade -y
pkg install -y openssh nginx termux-services cloudflared termux-api jq git
termux-setup-storage
passwd

# ── 2. Close & reopen Termux, then continue ──

# ── 3. Clone the repo ──
cd ~
git clone https://github.com/YOUR_USERNAME/Atlas-M30.git
cd Atlas-M30

# ── 4. Create directories ──
mkdir -p ~/.cloudflared
mkdir -p ~/.ssh
mkdir -p ~/.termux/boot
mkdir -p $PREFIX/var/service/cloudflared/log
mkdir -p ~/uptime_website

# ── 5. Copy all configs ──
cp Nginx/nginx.conf              $PREFIX/etc/nginx/nginx.conf
cp Cloudflared/config.yml        ~/.cloudflared/config.yml
cp SSH/config                    ~/.ssh/config
cp Services/cloudflared/run      $PREFIX/var/service/cloudflared/run
cp Termux/boot/start-atlas-m30.sh ~/.termux/boot/start-atlas-m30.sh
cp .bashrc                       ~/.bashrc
cp -r Website/.                  ~/uptime_website/

# ── 6. Set permissions ──
chmod +x $PREFIX/var/service/cloudflared/run
chmod 700 ~/.termux/boot/start-atlas-m30.sh

# ── 7. Set up cloudflared logger ──
ln -sf $PREFIX/share/termux-services/svlogger $PREFIX/var/service/cloudflared/log/run

# ── 8. Symlink nginx HTML ──
rm -rf $PREFIX/share/nginx/html
ln -s ~/uptime_website $PREFIX/share/nginx/html

# ── 9. ⚠️ EDIT PLACEHOLDERS before enabling: ──
#   nano ~/.cloudflared/config.yml   → replace YOUR_TUNNEL_ID, hostname
#   nano ~/.ssh/config               → replace username, IP
#   nano ~/.bashrc                   → update public URL if different

# ── 10. Enable services ──
sv-enable sshd
sv-enable nginx
sv-enable cloudflared

# ── 11. Load shell profile ──
source ~/.bashrc
```

---

## 2. Verification Checklist

Run these checks after your initial setup **and after every reboot** to confirm everything is healthy.

### Services Running

```bash
sv status sshd nginx cloudflared
```
✅ **Expected:** All three show `run: <name>: (pid ...) Ns`

### Ports Listening

```bash
ss -lnt | grep -E '(:8022|:8080)'
```
✅ **Expected:** LISTEN entries for both ports

### Nginx Config Syntax

```bash
nginx -t
```
✅ **Expected:** "test is successful"

### Local Web Access

```bash
curl -I http://127.0.0.1:8080
```
✅ **Expected:** `HTTP/1.1 200 OK`

### SSH Access (From Another Machine)

```bash
ssh -p 8022 <username>@<tailscale_ip>
# or if you set up the SSH shortcut:
ssh atlas-m30
```
✅ **Expected:** Termux shell prompt

### Public Tunnel

```bash
curl -I https://<your-public-hostname>
```
✅ **Expected:** `HTTP/2 200` (served via Cloudflare)

### Health Monitor

```bash
health
```
✅ **Expected:** Battery %, temperature, and uptime

### Wake Lock

Check your phone's notification shade for a persistent Termux notification saying **"wake lock held"** (or similar wording).

---

## 3. Security Best Practices

### ✅ Do

| Practice | Why |
|---|---|
| Use SSH key auth instead of passwords | Keys can't be brute-forced like passwords |
| Keep packages updated regularly | `pkg update && pkg upgrade -y` |
| Use `.gitignore` to exclude secrets | Prevents accidental token/key commits |
| Store tunnel tokens in environment variables | Not in config files that get committed |
| Keep the phone plugged in and ventilated | It's running 24/7 — heat kills batteries |

### ❌ Don't

| Mistake | Risk |
|---|---|
| Commit real Cloudflare tokens to Git | Anyone with repo access gets your tunnel |
| Commit SSH private keys | Full access to your server |
| Use weak/short Termux passwords | Easy brute-force if SSH is exposed |
| Expose sshd to the public internet | Use Tailscale as your private access layer |
| Run `cloudflared service install` | That's for systemd (Linux), not runit (Termux) |

---

## 4. Troubleshooting

### `sv: command not found`

**What happened:** `termux-services` isn't installed, or you didn't restart Termux after installing it.

**Fix:**
```bash
pkg install termux-services
# Then close and fully reopen Termux
```

---

### `sshd: no hostkeys available`

**What happened:** SSH host keys weren't generated during package installation.

**Fix:**
```bash
ssh-keygen -A
sshd
```

---

### `cloudflared` exits immediately

**What happened:** Missing or invalid tunnel configuration.

**If using token method:**
```bash
# Check that the token is set:
echo $CLOUDFLARED_TOKEN

# Test manually:
cloudflared tunnel run --token <your-token>
```

**If using named tunnel:**
```bash
# Check your config:
cat ~/.cloudflared/config.yml

# Make sure the credentials file exists:
ls ~/.cloudflared/*.json
```

---

### Nginx returns 403 Forbidden

**What happened:** Your website directory is empty or has wrong permissions.

**Fix:**
```bash
# Make sure there's at least an index.html:
echo "<h1>Atlas-M30</h1>" > ~/uptime_website/index.html

# Verify the symlink points to the right place:
ls -la $PREFIX/share/nginx/html
# Should show: ... -> /data/data/com.termux/files/home/uptime_website
```

---

### Android kills Termux after a few hours

**Symptoms:** SSH disconnects, services stop, you have to re-open Termux manually.

**Diagnostic checklist:**

| Step | How to Check |
|---|---|
| 1. Wake lock active? | Check notification shade for Termux persistant notification |
| 2. Battery optimization off? | Settings → Apps → Termux → Battery → must be "Unrestricted" |
| 3. Termux locked in Recents? | Long-press in Recent Apps → Lock/Pin |
| 4. Phantom Process Killer disabled? | See [Chapter 1, Section 2.3](01-getting-started.md#23-disable-the-phantom-process-killer-android-12) |
| 5. OEM-specific settings? | Check [dontkillmyapp.com](https://dontkillmyapp.com) for your phone brand |

---

### SSH connection times out

**Check these in order:**

```bash
# 1. Is sshd actually running?
pgrep sshd

# 2. Is Tailscale connected? (check the Android Tailscale app)

# 3. Can you ping the Tailscale IP from your computer?
ping <tailscale_ip>

# 4. Is the port open?
ss -lnt | grep 8022
```

---

### Services show `down` after reboot

**What happened:** `sv-enable` wasn't run, or Termux:Boot isn't configured.

**Fix:**
```bash
# Enable auto-start for all services:
sv-enable sshd
sv-enable nginx
sv-enable cloudflared

# Verify boot script exists and is executable:
ls -la ~/.termux/boot/
# Should show: start-atlas-m30.sh with execute permissions (rwx)
```

---

### `termux-battery-status` returns nothing

**What happened:** The Termux:API Android app isn't installed, or it's from a different source than Termux (e.g., one from F-Droid and the other from Play Store).

**Fix:**
1. Install the **Termux:API** app from F-Droid
2. Install the CLI package: `pkg install termux-api`

> 💡 The `health` function has a built-in fallback — it reads directly from `/sys/class/power_supply/battery/` which works on most phones without needing the API app at all.

---

## 5. Config File Reference

Quick reference for where each repo file gets installed on the device:

| Repo File | Install To | What It Does |
|---|---|---|
| [`.bashrc`](../.bashrc) | `~/.bashrc` | Shell profile, aliases, health monitor |
| [`Nginx/nginx.conf`](../Nginx/nginx.conf) | `$PREFIX/etc/nginx/nginx.conf` | Web server configuration |
| [`Cloudflared/config.yml`](../Cloudflared/config.yml) | `~/.cloudflared/config.yml` | Tunnel config (Option B only) |
| [`Services/cloudflared/run`](../Services/cloudflared/run) | `$PREFIX/var/service/cloudflared/run` | runit run script for the tunnel |
| [`SSH/config`](../SSH/config) | `~/.ssh/config` _(on your computer)_ | SSH connection shortcut |
| [`Termux/boot/start-atlas-m30.sh`](../Termux/boot/start-atlas-m30.sh) | `~/.termux/boot/start-atlas-m30.sh` | Boot startup script |
| [`Website/*`](../Website/) | `~/uptime_website/` | Static website files |

---

## 6. Updating Your Setup

### Update Packages

```bash
pkg update && pkg upgrade -y
```

Run this regularly (weekly is a good cadence) to get security patches.

### Update Config Files from the Repo

If you make changes to the repo on GitHub and want to pull them to the device:

```bash
cd ~/Atlas-M30
git pull

# Re-copy any changed configs:
cp .bashrc ~/.bashrc
source ~/.bashrc

# If you changed nginx:
cp Nginx/nginx.conf $PREFIX/etc/nginx/nginx.conf
nginx -t && sv restart nginx
```

---

## ✅ Setup Complete

You've built a fully functional headless Android server with:

| ✅ | Feature |
|---|---|
| 🔑 | SSH access via Tailscale (private, encrypted) |
| 🌐 | Nginx web server on port 8080 |
| 🚇 | Cloudflare Tunnel for public HTTPS |
| 🔄 | Auto-restart via runit service supervision |
| 🚀 | Auto-start on boot via Termux:Boot |
| 📊 | Health monitoring (battery, thermal, uptime) |
| 🛡️ | No root required |

---

**← [Chapter 1: Getting Started](01-getting-started.md)** · **[Chapter 2: Web Server & Public Access](02-services-and-deployment.md)** · **Chapter 3: You are here**
