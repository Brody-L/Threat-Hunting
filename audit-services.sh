#!/bin/bash

echo "[*] Gathering installed Snap packages and their services..."
snap_services=$(snap services 2>/dev/null | awk 'NR>1 {print $1}')
snap_packages=$(snap list 2>/dev/null | awk 'NR>1 {print $1}')

# Directories to search recursively
dirs=("/etc/systemd/system" "/lib/systemd/system")

echo
echo "[*] Auditing systemd service files for suspicious entries..."
echo "-----------------------------------------------------------"

for dir in "${dirs[@]}"; do
    # Recursively find all .service files (exclude symlinks)
    find "$dir" -type f -name "*.service" ! -lname '*' 2>/dev/null | while read -r service; do

        base=$(basename "$service")

        # Skip known snap-managed services
        if [[ "$base" =~ ^snap\. ]]; then
            snap_name=$(echo "$base" | cut -d'.' -f2)
            if echo "$snap_packages" | grep -qx "$snap_name"; then
                continue
            fi
        fi

        # Check if file is part of a package
        if ! dpkg -S "$service" &>/dev/null; then
            echo "[!] Unpackaged service: $service"
            ls -lc "$service" | awk '{print "    Last status change: "$6, $7, $8}'

            exec_line=$(grep -E '^\s*ExecStart=' "$service" | sed 's/^\s*//')
            if [ -n "$exec_line" ]; then
                echo "    $exec_line"
            fi
            echo
        fi
    done
done
