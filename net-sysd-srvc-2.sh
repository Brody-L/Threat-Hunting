#!/bin/bash
for service in $(systemctl list-units --type=service --state=running --no-legend | awk '{print $1}'); do
    # Get the PID of the service
    pid=$(systemctl show -p MainPID $service | cut -d'=' -f2)
    if [ "$pid" != "0" ]; then
        # Get the command line arguments from the proc filesystem
        # Check if the binary has an established connection
        established=$(ss -tnp | grep "pid=$pid")
        if [ ! -z "$established" ]; then
            cmdline=$(cat /proc/$pid/cmdline | tr '\0' ' ')
            echo "Command Line: $cmdline"
            echo "Service: $service"
            echo "Established Connections:"
            echo "$established"
        fi
    fi
done
