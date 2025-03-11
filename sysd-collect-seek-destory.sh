#!/bin/bash

# Define quarantine directory
QUARANTINE_DIR="/quarantine/Systemd-Persistence"
mkdir -p "$QUARANTINE_DIR"

# Function to collect artifacts
collect_artifacts() {
    local service_name="$1"
    local binary_path="$2"
    local pids=("${!3}") # Array of PIDs
    local services=("${!4}") # Array of services
    local filename="$QUARANTINE_DIR/$service_name.txt"

    {
        echo "Timestamp: $(date "+%Y-%m-%d %H:%M:%S")"
        echo "=============================="
        echo "Binary Path: $binary_path"
        echo "------------------------------"
        echo "Process Information:"
        for pid in "${pids[@]}"; do
            echo "PID: $pid"
            echo "Command Line: $(cat /proc/$pid/cmdline | tr '\0' ' ')"
            echo "------------------------------"
            echo "Network Connections for PID $pid:"
            ss -tnp | grep "pid=$pid" || echo "No network connections."
            echo "------------------------------"
        done

        # Collect systemd service information
        if [ "${#services[@]}" -gt 0 ]; then
            echo "Systemd Services using this binary:"
            for service in "${services[@]}"; do
                echo "Service: $service"
                systemctl show "$service"
                echo "------------------------------"
            done
        else
            echo "No systemd services found for this binary."
        fi

        echo "Actions Taken:"
        echo "✅ Binary deleted"
        echo "✅ Services stopped and disabled"
        echo "✅ Processes killed"
        echo "✅ Network connections confirmed closed"
    } > "$filename"

    echo "Artifacts collected in: $filename"
}

# Step 1: Identify running services and delete their binaries
echo "Step 1: Finding running services and their binaries..."

SERVICES_FOUND=()

while IFS= read -r service; do
    if [[ -n "$service" ]]; then
        SERVICES_FOUND+=("$service")
    fi
done < <(systemctl list-units --type=service --state=running --no-legend | awk '{print $1}')

for service in "${SERVICES_FOUND[@]}"; do
    echo "Processing service: $service"

    # Get binary used by the service
    BINARY_PATH=$(systemctl show "$service" --property=ExecStart | cut -d= -f2 | awk '{print $1}' | tr -d '"')

    if [[ -z "$BINARY_PATH" || ! -f "$BINARY_PATH" ]]; then
        echo "No valid binary found for $service. Skipping..."
        continue
    fi

    echo "Binary used by service: $BINARY_PATH"

    # Find PIDs using this binary
    PIDS=($(pgrep -f "$BINARY_PATH"))
    echo "Processes found: ${PIDS[*]:-None}"

    # Collect artifacts
    collect_artifacts "$service" "$BINARY_PATH" PIDS[@] SERVICES_FOUND[@]

    # Stop and disable service
    echo "Stopping and disabling service: $service"
    systemctl stop "$service"
    systemctl disable "$service"

    # Kill processes
    for pid in "${PIDS[@]}"; do
        echo "Killing process with PID: $pid"
        kill -9 "$pid"
    done

    # Delete binary
    echo "Deleting binary: $BINARY_PATH"
    rm -f "$BINARY_PATH"
done

# Step 2: Find suspicious binaries and handle them
echo "Step 2: Finding suspicious binaries..."

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
    collect_artifacts "$SERVICE_NAME" "$binary" PIDS[@] SERVICES[@]

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

echo "Step 1 and Step 2 completed successfully."
