#!/bin/bash

echo "[*] Listing all systemd timers (system and user)..."
echo "----------------------------------------------------"
systemctl list-timers --all --no-pager --no-legend 2>/dev/null

echo
echo "[*] Auditing systemd timer files..."
echo "-----------------------------------"

dirs=(
    "/etc/systemd/system/"
    "/etc/systemd/user/"
    "/lib/systemd/system/"
    "/usr/lib/systemd/system/"
    "/usr/lib/systemd/user/"
    "$HOME/.config/systemd/user/"
    "$HOME/.local/share/systemd/user/"
    "/run/systemd/system/"
)

for dir in "${dirs[@]}"; do
    find "$dir" -type f -name "*.timer" 2>/dev/null | while read -r timer; do
        base=$(basename "$timer")
        service_name=$(grep -i '^Unit=' "$timer" 2>/dev/null | cut -d= -f2)

        # Skip known transient runtime copies
        found_alt=0
        for alt in "/usr/lib/systemd/system" "/lib/systemd/system" "/etc/systemd/system"; do
            alt_path="$alt/$base"
            if [[ "$alt_path" != "$timer" && -f "$alt_path" ]]; then
                if dpkg -S "$alt_path" &>/dev/null; then
                    found_alt=1
                    break
                fi
            fi
        done

        # Only flag if no matching packaged path was found
        if [[ "$found_alt" -eq 0 ]] && ! dpkg -S "$timer" &>/dev/null; then
            echo "[!] Unpackaged timer: $timer"
            ls -lc "$timer" | awk '{print "    Last status change: "$6, $7, $8}'
            
            if [ -n "$service_name" ]; then
                echo "    Triggers: $service_name"
            else
                echo "    No Unit= defined. May use default: ${base%.timer}.service"
            fi
            echo
        fi
    done
done
