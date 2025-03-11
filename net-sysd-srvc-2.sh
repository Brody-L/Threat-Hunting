#!/bin/bash

for service in $(systemctl list-units --type=service --state=running --no-legend | awk '{print $1}'); do
    # Get the PID of the service
    pid=$(systemctl show -p MainPID $service | cut -d'=' -f2)
    if [ "$pid" != "0" ]; then
        # Check if the binary has an established connection
        established=$(ss -tnp | grep "pid=$pid")
        if [ ! -z "$established" ]; then
            cmdline=$(cat /proc/$pid/cmdline | tr '\0' ' ')
            echo "Command Line: $cmdline"
            echo "Service: $service"
            echo "Established Connections:"
            echo "$established"

            # Stop the systemd service
            echo "Stopping service $service..."
            systemctl stop $service

            # Kill the process to remove the established network connection
            echo "Killing process with PID: $pid..."
            kill -9 $pid

            # Delete the binary that the service is running
            binary_path=$(readlink -f /proc/$pid/exe)
            if [ -n "$binary_path" ]; then
                echo "Deleting binary: $binary_path"
                rm -f "$binary_path"
            fi

            echo "-----------------------------"
        fi
    fi
done
