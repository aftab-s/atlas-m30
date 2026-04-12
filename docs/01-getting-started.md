# Chapter 1 — Getting Started

> From zero to SSH access on your Android phone in under 30 minutes.

This chapter covers everything you need to get remote terminal access to your phone over a private encrypted network. By the end, you'll be SSHing into your phone from your laptop.

---

## What You'll Achieve in This Chapter

- ✅ Termux installed and configured
- ✅ SSH server running on port 8022
- ✅ Tailscale VPN mesh connecting your devices
- ✅ Secure SSH access from any of your machines, anywhere

---

## 1. Prerequisites

### Hardware

- Any Android phone or tablet (Android 7+, Android 12+ supported with extra steps)

### Apps to Install

> **⚠️ Critical:** Install **all** Termux apps from the **same source** (F-Droid). The Play Store version of Termux is deprecated, and F-Droid / Play Store builds use different signing keys — they **cannot** work together.

| App | Where to Get It | What It Does |
|---|---|---|
| [Termux](https://f-droid.org/en/packages/com.termux/) | F-Droid | Linux terminal on Android |
| [Termux:Boot](https://f-droid.org/en/packages/com.termux.boot/) | F-Droid | Runs scripts when phone starts |
| [Termux:API](https://f-droid.org/en/packages/com.termux.api/) | F-Droid | Access to battery, sensors, etc. |
| [Tailscale](https://play.google.com/store/apps/details?id=com.tailscale.ipn) | Play Store / F-Droid | Private VPN mesh network |

### Accounts You'll Need

| Service | Link | Cost |
|---|---|---|
| Tailscale | [tailscale.com/start](https://login.tailscale.com/start) | Free for personal use |
| Cloudflare | [dash.cloudflare.com](https://dash.cloudflare.com/sign-up) | Free tier works |

### On Your Computer

- An SSH client (built into macOS, Linux, and Windows 10+)
- Tailscale installed and signed in with the **same account** as your phone

---

## 2. Prepare Your Android Device

These steps are **critical** for uptime. Skip them and Android **will** kill your server processes after a few hours.

### 2.1 Disable Battery Optimization

Go to: **Settings → Apps → Termux → Battery → Unrestricted**

Repeat this for **all four apps**: Termux, Termux:Boot, Termux:API, and Tailscale.

> 💡 **Tip:** Every Android manufacturer (Samsung, Xiaomi, OnePlus, Pixel, etc.) adds their own extra battery-killing features on top of stock Android. Visit **[dontkillmyapp.com](https://dontkillmyapp.com)** and follow the instructions specific to your phone brand. This is the single most important thing you can do for server stability.

### 2.2 Lock Termux in Recent Apps

1. Open Termux
2. Open the Recent Apps view (swipe up or press the square button)
3. Long-press the Termux card → tap **Lock** / **Keep Open** / **Pin** (wording varies by phone)

This tells Android "don't kill this app when I switch to something else."

### 2.3 Disable the Phantom Process Killer (Android 12+)

Android 12 introduced a "Phantom Process Killer" that aggressively terminates background child processes. It **will** kill your SSH sessions and server daemons.

#### If you have Android 14+ (easy, no PC needed):

1. Enable Developer Options: **Settings → About Phone → tap "Build Number" 7 times**
2. Go to **Settings → System → Developer Options**
3. Find **"Disable child process restrictions"** → turn it **ON**

#### If you have Android 12 or 13 (needs ADB):

**From a PC** connected via USB:
```bash
adb shell "/system/bin/device_config put activity_manager max_phantom_processes 2147483647"
adb shell "settings put global settings_enable_monitor_phantom_procs false"
```

**Or from Termux itself** using wireless ADB:
```bash
pkg install android-tools

# 1. Enable "Wireless Debugging" in Developer Options on your phone
# 2. Tap "Wireless Debugging" → "Pair device with pairing code"
adb pair <IP>:<PAIR_PORT>     # Enter the pairing code shown on screen

# 3. Connect (use IP:Port from the main Wireless Debugging screen, NOT the pairing screen)
adb connect <IP>:<PORT>

# 4. Run the fix
adb shell "/system/bin/device_config put activity_manager max_phantom_processes 2147483647"
```

> ⚠️ These settings may reset after a reboot or if Developer Options are toggled off.

### 2.4 Open Termux:Boot Once

After installing the Termux:Boot app, **open it once** from the app launcher. This grants the boot-startup permission. You don't need to configure anything inside it — just open and close it.

---

## 3. Set Up Termux

### 3.1 Update Everything

Open Termux and run:
```bash
pkg update && pkg upgrade -y
```

### 3.2 Install Packages

```bash
pkg install -y openssh nginx termux-services cloudflared termux-api jq git
```

Here's what each one does:

| Package | Purpose |
|---|---|
| `openssh` | SSH server (`sshd`) and client |
| `nginx` | Lightweight web server |
| `termux-services` | Service manager (auto-restart crashed daemons) |
| `cloudflared` | Cloudflare Tunnel client |
| `termux-api` | CLI tools for battery status, notifications, etc. |
| `jq` | JSON parser (used by the health monitor) |
| `git` | Clone this repo onto your phone |

### 3.3 Grant Storage Access

```bash
termux-setup-storage
```

Tap **Allow** when Android asks for permission. This creates `~/storage/` with shortcuts to your Downloads, DCIM, and other folders.

### 3.4 Set a Password

```bash
passwd
```

Choose a strong password — you'll use this to SSH in.

### 3.5 Find Your Username

```bash
whoami
```

You'll see something like `u0_a123`. **Write this down** — you need it to connect via SSH.

### 3.6 Restart Termux

**Close Termux completely and reopen it.** The service manager (`termux-services`) only initializes when a new session starts. If you skip this step, `sv` commands won't work.

---

## 4. Set Up SSH (OpenSSH)

### 4.1 Generate Host Keys

The `openssh` package usually creates host keys during installation. But if `sshd` fails to start with "no hostkeys available":

```bash
ssh-keygen -A
```

### 4.2 Start the SSH Server

```bash
sshd
```

Verify it's running:
```bash
pgrep sshd
# Should print a process ID number
```

### 4.3 Find Your IP Address

```bash
ifconfig
# Look for the "inet" value under "wlan0"
# Example: 192.168.1.42
```

### 4.4 Test the Connection (From Your Computer)

```bash
ssh -p 8022 <username>@<ip_address>
```

- Replace `<username>` with the output from `whoami` (e.g., `u0_a123`)
- **Port 8022** is the Termux default (Android won't let non-root apps use port 22)

> 🎉 If you see a Termux shell prompt — congratulations! You now have SSH access to your phone over your local network.

### 4.5 Set Up SSH Key Authentication (Recommended)

Password auth works, but key-based auth is both more secure and more convenient. Run these **on your computer**:

```bash
# Generate a key pair (skip if you already have one):
ssh-keygen -t ed25519 -C "your-email@example.com"

# Copy your public key to the phone:
ssh-copy-id -p 8022 <username>@<ip_address>
```

Test that it works without a password:
```bash
ssh -p 8022 <username>@<ip_address>
# Should log in without asking for a password
```

Once confirmed, you can optionally disable password login entirely (on the **Termux device**):
```bash
echo "PasswordAuthentication no" >> $PREFIX/etc/ssh/sshd_config
pkill sshd && sshd
```

---

## 5. Set Up Tailscale (Private VPN)

Tailscale creates a private WireGuard mesh network. Your phone gets a stable `100.x.x.x` IP that's reachable from any of your devices — regardless of what WiFi or mobile network they're on.

### 5.1 On Your Phone

1. Open the **Tailscale** app
2. Sign in (Google, Microsoft, GitHub — whichever you prefer)
3. Toggle Tailscale **ON**
4. Note your assigned IP address (e.g., `100.64.0.2`) — it's shown in the app

### 5.2 On Your Computer

1. [Install Tailscale](https://tailscale.com/download)
2. Sign in with the **same account**
3. Verify both devices appear in the [Tailscale admin console](https://login.tailscale.com/admin/machines)

### 5.3 Test It

From your computer:
```bash
# Ping your phone over Tailscale:
ping 100.64.0.2

# SSH over Tailscale:
ssh -p 8022 <username>@100.64.0.2
```

> 🎉 You can now SSH into your phone from **anywhere in the world**, as long as both devices have Tailscale running. No port forwarding, no public IP needed.

### 5.4 Create an SSH Shortcut (Optional but Handy)

Add this to `~/.ssh/config` on your **computer**:

```ssh-config
Host atlas-m30
    HostName 100.64.0.2
    Port 8022
    User REPLACE_WITH_TERMUX_USERNAME
    ServerAliveInterval 30
    ServerAliveCountMax 3
```

Replace `REPLACE_WITH_TERMUX_USERNAME` with your actual username and `100.64.0.2` with your Tailscale IP.

Now you can connect with just:
```bash
ssh atlas-m30
```

> 📄 A template for this config is at [`SSH/config`](../SSH/config) in this repo.

---

## ✅ Chapter 1 Complete

You now have:
- A Termux environment with all packages installed
- SSH access over your local network and Tailscale
- Android configured to not kill your background processes

**Next:** [Chapter 2 — Web Server & Public Access →](02-services-and-deployment.md)
