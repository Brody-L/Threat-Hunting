#!/bin/bash
for service in $(systemctl list-units --type=service --state=running --no-legend | awk '{print $1}'); do
    echo "Service: $service"
    # Get the PID of the service
    pid=$(systemctl show -p MainPID $service | cut -d'=' -f2)
    if [ "$pid" != "0" ]; then
        # Get the command line arguments from the proc filesystem
        cmdline=$(cat /proc/$pid/cmdline | tr '\0' ' ')
        echo "Command Line: $cmdline"
        # Check if the binary is listening on a port
        listening=$(ss -ltnp | grep "pid=$pid")
        if [ ! -z "$listening" ]; then
            echo "Listening on Port:"
            echo "$listening"
        else
            echo "Not Listening on Any Port."
        fi
        # Check if the binary has an established connection
        established=$(ss -tnp | grep "pid=$pid")
        if [ ! -z "$established" ]; then
            echo "Established Connections:"
            echo "$established"
        else
            echo "No Established Connections."
        fi
        echo "-----------------------------"
    fi
done
