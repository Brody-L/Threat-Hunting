# Collection of Linux Persistence Hunting Scripts

## audit-ko.sh
Compares `ls` output on kernel object directories to debugfs output to find hidden files. 

## audit-services.sh
Checks systemd services against dpkg -S and snap to find unowned services that may be malicious. Could have false postives. 

## sysd-collect-seek-destroy.sh
- Identifies systemd services with ESTABLISHED or LISTEN connection states
- Gathers details about the service and the script or binary in ExecStart=
- Stops and Disables the service
- Moves the service to /quarantine/Systemd-Persistence
- Includes extensive details about the service
