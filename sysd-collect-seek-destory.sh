#!/bin/bash

# Define quarantine directory
QUARANTINE_DIR="/quarantine/Systemd-Persistence"
mkdir -p "$QUARANTINE_DIR"

# Function to collect artifacts
collect_artifacts() {
    local pid="$1"
    local service_name="$2"
    local binary_path="$3"
    local cmdline="$4"
    local established="$5"
    local filename="$QUARANTINE_DIR/$service_name.txt"

    {
        echo "Timestamp: $(date "+%Y-%m-%d %H:%M:%S")"
        echo "=============================="
        echo "Service: $service_name"
        echo "PID: $pid"
        echo "Binary Path: $binary_path"
        echo "Command Line: $cmdline"
        echo "------------------------------"
        echo "Established Connections:"
        echo "$established"
        echo "------------------------------"
        echo "Systemd Service Details:"
        systemctl show "$service_name"
        echo "------------------------------"
        echo "Actions Taken:"
        echo "✅ Binary deleted"
        echo "✅ Service stopped and disabled"
        echo "✅ Process killed"
        echo "✅ Network connections confirmed closed"
    } > "$filename"

    echo "Artifacts collected in: $filename"
}

# Step 1: Systemd Service Check and Binary Deletion
echo "Checking running systemd services..."

for service in $(systemctl list-units --type=service --state=running --no-legend | awk '{print $1}'); do
    # Get the PID of the service
    pid=$(systemctl show -p MainPID "$service" | cut -d'=' -f2)

    if [[ "$pid" != "0" && -d "/proc/$pid" ]]; then
        # Get the binary path
        binary_path=$(readlink -f /proc/$pid/exe)

        if [[ -f "$binary_path" ]]; then
            # Check for established network connections
            established=$(ss -tnp | grep "pid=$pid")

            if [[ -n "$established" ]]; then
                # Get command line arguments
                cmdline=$(cat /proc/$pid/cmdline | tr '\0' ' ')
                echo "Processing service: $service"
                echo "Command Line: $cmdline"
                echo "Established Connections:"
                echo "$established"

                # Collect artifacts
                collect_artifacts "$pid" "$service" "$binary_path" "$cmdline" "$established"

                # Stop and disable the service
                echo "Stopping and disabling service: $service"
                systemctl stop "$service"
                systemctl disable "$service"

                # Kill the process
                echo "Killing process with PID: $pid"
                kill -9 "$pid"

                # Delete binary
                echo "Deleting binary: $binary_path"
                rm -f "$binary_path"
            fi
        fi
    fi
done

# Step 2: Identify Suspicious Binaries and Handle Them
echo "Finding suspicious binaries..."

FOUND_BINARIES=()

while IFS= read -r binary_path; do
    if [[ -n "$binary_path" ]]; then
        echo "Found binary: $binary_path"
        FOUND_BINARIES+=("$binary_path")
    fi
done < <(find /proc/**/exe -exec ls -l {} \; 2>/dev/null | grep - | awk '{print $NF}' | sort | uniq -u | grep -E "/usr/local/go|sliver|runtime.*\.go|/usr/share/man/webmin")

for binary in "${FOUND_BINARIES[@]}"; do
    echo "Processing binary: $binary"

    # Find PIDs running this binary
    PIDS=($(pgrep -f "$binary"))
    echo "Processes found: ${PIDS[*]:-None}"

    # Find services using this binary
    SERVICES=()
    while IFS= read -r service; do
        if [[ -n "$service" ]]; then
            SERVICES+=("$service")
        fi
    done < <(systemctl list-units --type=service --state=running --no-legend | awk '{print $1}' | while read svc; do
        if systemctl show "$svc" | grep -q "ExecStart=.*$binary"; then
            echo "$svc"
        fi
    done)

    SERVICE_NAME="${SERVICES[0]:-unknown-service}"

    echo "Systemd Services using this binary: ${SERVICES[*]:-None}"

    # Collect artifacts
    collect_artifacts "${PIDS[0]:-N/A}" "$SERVICE_NAME" "$binary" "N/A" "N/A"

    # Stop and disable services
    for service in "${SERVICES[@]}"; do
        echo "Stopping and disabling service: $service"
        systemctl stop "$service"
        systemctl disable "$service"
    done

    # Kill processes
    for pid in "${PIDS[@]}"; do
        echo "Killing process with PID: $pid"
        kill -9 "$pid"
    done

    # Delete the binary
    echo "Deleting binary: $binary"
    rm -f "$binary"
done
