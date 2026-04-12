# Chapter 2 — Web Server & Public Access

> Set up Nginx, a Cloudflare Tunnel, service supervision, and boot persistence — so your phone serves a website to the world and survives reboots.

**Before starting:** Complete [Chapter 1 — Getting Started](01-getting-started.md) first.

---

## What You'll Achieve in This Chapter

- ✅ Nginx serving your website locally on port 8080
- ✅ Cloudflare Tunnel forwarding public HTTPS traffic to your phone
- ✅ All services auto-managed and auto-restarted by `termux-services`
- ✅ Everything starts automatically on device reboot
- ✅ A polished shell profile with health monitoring and aliases

---

## 1. Nginx (Local Web Server)

### 1.1 Create a Directory for Your Website

```bash
mkdir -p ~/uptime_website
```

### 1.2 Add Some Content

You can use the sample website from this repo:

```bash
cp -r ~/Atlas-M30/Website/. ~/uptime_website/
```

Or create a quick test page:
```bash
echo "<h1>Hello from Atlas-M30!</h1>" > ~/uptime_website/index.html
```

### 1.3 Deploy the Nginx Config

```bash
cp ~/Atlas-M30/Nginx/nginx.conf $PREFIX/etc/nginx/nginx.conf
```

Here's what the config does — it serves your static files on port 8080:

```nginx
worker_processes  1;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;

    server {
        listen 8080;
        server_name localhost;

        # This is the expanded path of ~/uptime_website
        # Nginx doesn't understand ~ — you must use the absolute path
        root /data/data/com.termux/files/home/uptime_website;
        index index.html;

        location / {
            try_files $uri $uri/ =404;
        }

        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
            root /data/data/com.termux/files/usr/share/nginx/html;
        }
    }
}
```

> 💡 **Why the long path?** Termux's home directory is `/data/data/com.termux/files/home`. The `~` shorthand doesn't work inside `nginx.conf` — you must spell out the full path.

### 1.4 Symlink the Default HTML Directory (Optional)

Point Nginx's default HTML location to your website:

```bash
rm -rf $PREFIX/share/nginx/html
ln -s ~/uptime_website $PREFIX/share/nginx/html
```

### 1.5 Test and Start

```bash
# Validate config (catches typos before starting):
nginx -t
# ✅ Expected: "test is successful"

# Start nginx:
nginx

# Verify it's serving your page:
curl -I http://127.0.0.1:8080
# ✅ Expected: HTTP/1.1 200 OK
```

> 📄 Config template: [`Nginx/nginx.conf`](../Nginx/nginx.conf)

---

## 2. Cloudflare Tunnel (Public Access)

A Cloudflare Tunnel lets people on the internet access your local Nginx — without you opening any router ports. Cloudflare handles HTTPS certificates, CDN caching, and DDoS protection automatically.

### Pick Your Method

There are two ways to set up a tunnel. **Token-based (Option A) is recommended** for simplicity.

| | Option A: Token-Based | Option B: Named Tunnel |
|---|---|---|
| **Config lives in** | Cloudflare Dashboard | Local `config.yml` file |
| **Complexity** | Simple | More setup steps |
| **Best for** | Most people | Advanced users who want local control |

---

### Option A — Token-Based (Recommended)

1. Log in to [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)
2. Go to **Networks → Tunnels → Create a tunnel**
3. Name it (e.g., `atlas-m30`)
4. Copy the **tunnel token** they give you
5. Test it manually:

```bash
cloudflared tunnel run --token <YOUR_TOKEN>
```

6. Back in the dashboard, add a **Public Hostname** rule:
   - **Subdomain:** `atlasm30s` (or whatever you want)
   - **Domain:** your Cloudflare-managed domain
   - **Service:** `http://localhost:8080`

7. To use this with the service manager (next section), export the token:

```bash
export CLOUDFLARED_TOKEN="<YOUR_TOKEN>"
```

> **⚠️ Never commit your real token to Git.** Use environment variables or store it in a file excluded by `.gitignore`.

---

### Option B — Named Tunnel (Local Config)

<details>
<summary>Click to expand Option B instructions</summary>

1. **Authenticate:** 
```bash
cloudflared tunnel login
# Opens a browser — authorize your domain there
```

2. **Create a named tunnel:**
```bash
cloudflared tunnel create atlas-m30
# Generates a credentials file at ~/.cloudflared/<UUID>.json
```

3. **Deploy the config template:**
```bash
mkdir -p ~/.cloudflared
cp ~/Atlas-M30/Cloudflared/config.yml ~/.cloudflared/config.yml
```

4. **Edit `~/.cloudflared/config.yml`** and replace the placeholders:

```yaml
tunnel: YOUR_TUNNEL_ID
credentials-file: /data/data/com.termux/files/home/.cloudflared/YOUR_TUNNEL_ID.json

ingress:
  - hostname: atlasm30s.example.com
    service: http://localhost:8080
  - service: http_status:404
```

Replace:
- `YOUR_TUNNEL_ID` → the UUID from step 2
- `atlasm30s.example.com` → your actual domain

5. **Route DNS:**
```bash
cloudflared tunnel route dns atlas-m30 atlasm30s.example.com
```

6. **Test:**
```bash
cloudflared tunnel run
```

</details>

> 📄 Config template: [`Cloudflared/config.yml`](../Cloudflared/config.yml)

---

## 3. Service Supervision (termux-services)

`termux-services` uses [runit](http://smarden.org/runit/) to supervise your daemons. If a service crashes, runit automatically restarts it. This is what makes your phone a **real** server instead of just "some stuff running in the background."

### 3.1 Enable Built-in Services

SSH and Nginx already have runit service definitions (created by their packages). Just enable them:

```bash
sv-enable sshd
sv-enable nginx
```

### 3.2 Create a Custom Cloudflared Service

Cloudflared doesn't come with a runit service, so we create one:

```bash
# Create the service directory and logger:
mkdir -p $PREFIX/var/service/cloudflared/log

# Copy the run script from this repo:
cp ~/Atlas-M30/Services/cloudflared/run $PREFIX/var/service/cloudflared/run
chmod +x $PREFIX/var/service/cloudflared/run

# Set up logging (writes to $PREFIX/var/log/sv/cloudflared/):
ln -sf $PREFIX/share/termux-services/svlogger $PREFIX/var/service/cloudflared/log/run
```

**What's in the run script** (`Services/cloudflared/run`):

```bash
#!/data/data/com.termux/files/usr/bin/sh

if [ -n "$CLOUDFLARED_TOKEN" ]; then
    exec cloudflared tunnel run --token "$CLOUDFLARED_TOKEN"
fi

exec cloudflared tunnel run
```

> 💡 **Why `exec`?** The `exec` command replaces the shell process with `cloudflared`. This is **required** by runit — it needs to directly supervise the `cloudflared` process, not a shell wrapper around it.

Enable and start:

```bash
sv-enable cloudflared
sv up cloudflared
```

### 3.3 Verify Everything Is Running

```bash
sv status sshd nginx cloudflared
```

You should see something like:
```
run: sshd: (pid 12345) 600s
run: nginx: (pid 12346) 600s
run: cloudflared: (pid 12347) 600s
```

> ✅ All three say `run` — your services are live and supervised.

### 3.4 Quick Reference

| What You Want | Command |
|---|---|
| Start a service | `sv up <name>` |
| Stop a service | `sv down <name>` |
| Restart a service | `sv restart <name>` |
| Check status | `sv status <name>` |
| Enable auto-start | `sv-enable <name>` |
| Disable auto-start | `sv-disable <name>` |

> 📄 Run script template: [`Services/cloudflared/run`](../Services/cloudflared/run)

---

## 4. Boot Persistence (Termux:Boot)

Right now your services run great — until the phone reboots. Termux:Boot fixes that by running scripts from `~/.termux/boot/` every time the device starts.

### 4.1 Deploy the Boot Script

```bash
mkdir -p ~/.termux/boot
cp ~/Atlas-M30/Termux/boot/start-atlas-m30.sh ~/.termux/boot/start-atlas-m30.sh
chmod 700 ~/.termux/boot/start-atlas-m30.sh
```

**What's in the boot script** (`Termux/boot/start-atlas-m30.sh`):

```bash
#!/data/data/com.termux/files/usr/bin/sh

# Acquire wake lock first — prevents Android from sleeping
termux-wake-lock

# Start the service daemon
if [ -f "$PREFIX/etc/profile.d/start-services.sh" ]; then
    . "$PREFIX/etc/profile.d/start-services.sh"
fi

# Bring up all supervised services
sv up sshd 2>/dev/null || true
sv up nginx 2>/dev/null || true
sv up cloudflared 2>/dev/null || true

# Fallback: start directly if sv isn't available
pgrep -x sshd >/dev/null || sshd
pgrep -x nginx >/dev/null || nginx
pgrep -x cloudflared >/dev/null || cloudflared tunnel run &
```

### 4.2 Things to Know

- **Open Termux:Boot once** from the app launcher if you haven't already (see [Chapter 1, Section 2.4](01-getting-started.md#24-open-termuxboot-once))
- Boot scripts run in **sorted filename order** — if you add more, prefix with numbers (e.g., `00-wakelock.sh`, `01-services.sh`)
- The shebang **must** be `#!/data/data/com.termux/files/usr/bin/sh` (not `/bin/sh`)
- Scripts **must** be executable (`chmod 700` or `chmod 755`)

### 4.3 Test It

Reboot your phone, wait ~30 seconds, then from your computer:

```bash
ssh atlas-m30       # or: ssh -p 8022 <user>@<tailscale_ip>
sv status sshd nginx cloudflared
```

All three should show `run`. 🎉

> 📄 Boot script template: [`Termux/boot/start-atlas-m30.sh`](../Termux/boot/start-atlas-m30.sh)

---

## 5. Shell Profile (.bashrc)

The `.bashrc` file is the final piece — it ties everything together with aliases, a health monitor, and automatic service checks on every login.

### 5.1 Deploy It

```bash
cp ~/Atlas-M30/.bashrc ~/.bashrc
source ~/.bashrc
```

### 5.2 What It Does

| # | Feature | Description |
|---|---|---|
| 1 | **Custom prompt** | Shows `Atlas-M30:~/directory$` |
| 2 | **Service daemon** | Sources `termux-services` to initialize runit |
| 3 | **Auto-start checks** | Ensures sshd, nginx, cloudflared are running |
| 4 | **Wake lock** | Acquires `termux-wake-lock` |
| 5 | **Aliases** | Quick shortcuts for common operations |
| 6 | **Health monitor** | `health` command for battery/thermal/uptime |
| 7 | **Login banner** | Welcomes you with the server name and public URL |

### 5.3 Aliases Cheat Sheet

| Type This | Does This |
|---|---|
| `status sshd` | Check if sshd is running |
| `restart nginx` | Restart the web server |
| `c-logs` | Tail cloudflared tunnel logs |
| `n-logs` | Tail nginx error logs |
| `edit` | Open `.bashrc` in nano |
| `reload` | Re-source `.bashrc` |
| `health` or `h` | Show system health dashboard |

### 5.4 The Health Monitor

The `health` (or `h`) command gives you a quick server status:

```
--- Atlas-M30 Health Report ---
Battery: 87% (Charging)
Thermal: 34.5°C
Uptime:  up 3 days, 7 hours, 12 minutes
-------------------------------
```

It reads battery data two ways:
1. **Fast path:** Directly from `/sys/class/power_supply/battery/` (works on most phones, no dependencies)
2. **Fallback:** Uses `termux-battery-status` + `jq` (needs the Termux:API app)

> 📄 Shell profile: [`.bashrc`](../.bashrc)

---

## ✅ Chapter 2 Complete

You now have:
- Nginx serving your website locally
- A Cloudflare Tunnel making it publicly accessible via HTTPS
- All services supervised and auto-restarted by runit
- Boot persistence so everything survives reboots
- A polished shell profile with monitoring tools

**Next:** [Chapter 3 — Operations & Troubleshooting →](03-operations.md)
