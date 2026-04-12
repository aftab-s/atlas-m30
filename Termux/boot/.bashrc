# ---------------------------------------------------------
# ATLAS-M30 : SYSTEM CONFIGURATION
# ---------------------------------------------------------

# 1. ENVIRONMENT & PROMPT
export PS1="\[\e[32m\]Atlas-M30\[\e[m\]:\[\e[34m\]\w\[\e[m\]\$ "

# 2. START TERMUX SERVICES
# Ensure that termux-services is running.
if [ -f "$PREFIX/etc/profile.d/start-services.sh" ]; then
    source "$PREFIX/etc/profile.d/start-services.sh"
fi

# 3. ENSURE CRITICAL DAEMONS ARE ACTIVE (NGINX & CLOUDFLARED)
# Use sv to bring up the services if termux-services are installed.
if command -v sv > /dev/null 2>&1; then
    sv up sshd > /dev/null 2>&1 || true
    sv up nginx > /dev/null 2>&1 || true
    sv up cloudflared > /dev/null 2>&1 || true
fi

# 4. SMART WAKE LOCK & SSH FALLBACK
# Acquire a wakelock so Android doesn't kill Termux in the background. (Running this multiple times is safe)
termux-wake-lock > /dev/null 2>&1 || true

# If termux-services isn't handling sshd, we fall back to running it directly.
if ! pgrep -x "sshd" > /dev/null; then
    sshd
fi

# If nginx and cloudflared aren't handled by sv, we can try running them standalone as fallbacks.
if ! pgrep -x "nginx" > /dev/null; then
    nginx > /dev/null 2>&1 || true
fi

if ! pgrep -x "cloudflared" > /dev/null; then
    cloudflared tunnel run > /dev/null 2>&1 &
fi

# 5. DEVOPS ALIASES
alias status='sv status'
alias restart='sv restart'
alias c-logs='tail -f $PREFIX/var/service/cloudflared/log/run'
alias n-logs='tail -f $PREFIX/var/log/nginx/error.log'
alias edit='nano ~/.bashrc'
alias reload='source ~/.bashrc'

# 6. ATLAS-M30 HEALTH MONITOR
# Reads fast directly from sysfs to avoid slow termux-API overhead.
health() {
    local PERC="N/A"
    local STAT="N/A"
    local TEMP="N/A"

    # Fast direct read from Android kernel
    if [ -f /sys/class/power_supply/battery/capacity ]; then
        PERC=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null)
        STAT=$(cat /sys/class/power_supply/battery/status 2>/dev/null)
        local RAW_TEMP=$(cat /sys/class/power_supply/battery/temp 2>/dev/null)
        if [ -n "$RAW_TEMP" ]; then
            # Format temp to 1 decimal place (usually comes as 345 for 34.5C)
            TEMP=$(awk -v t="$RAW_TEMP" 'BEGIN {printf "%.1f", t/10}')
        fi
    else
        # Fallback to slower termux-api if sysfs is locked
        if ! command -v jq &> /dev/null; then
            echo "Error: 'jq' is not installed for API fallback."
            return
        fi
        local BATT=$(termux-battery-status)
        TEMP=$(echo "$BATT" | jq -r '.temperature' 2>/dev/null || echo "N/A")
        PERC=$(echo "$BATT" | jq -r '.percentage' 2>/dev/null || echo "N/A")
        STAT=$(echo "$BATT" | jq -r '.status' 2>/dev/null || echo "N/A")
    fi
    
    echo -e "\n\e[1;36m--- Atlas-M30 Health Report ---\e[0m"
    echo -e "Battery: \e[1;32m$PERC%\e[0m ($STAT)"
    echo -e "Thermal: \e[1;33m${TEMP}°C\e[0m"
    echo -e "Uptime:  \e[1;34m$(uptime -p)\e[0m"
    echo -e "\e[1;36m-------------------------------\e[0m\n"
}
alias h='health'

# 7. LOGIN BANNER
echo -e "\n\e[1;32mWelcome to Atlas-M30 Node\e[0m"
echo -e "Public Address: \e[4;34mhttps://atlasm30s.aftabs.me\e[0m"
echo -e "Type \e[1;33mhealth\e[0m for system metrics.\n"