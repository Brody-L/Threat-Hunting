# Collection of Linux Persistence Hunting Scripts

## audit-ko.sh
Compares `ls` output on kernel object directories to `debugfs` output to find hidden files. Use this if you suspect a Linux Kernel Module rootkit that may be hiding with a magic prefix. 

```bash
cat /proc/sys/kernel/tainted
```
Check the output for a non-zero value to determine if the kernel is tainted (may indicate a potential LKM rootkit)

## audit-services.sh
Checks systemd services against dpkg -S and snap to find unowned services that may be malicious. Could have false postives. 

## sysd-net.sh
- Identifies systemd services with ESTABLISHED or LISTEN connection states
- Gathers details about the service and the script or binary in ExecStart=
- Stops and Disables the service
- Kills processes associated with the service
- Moves the service and associated script/binary to /quarantine/Systemd-Persistence 
- Includes details about the service
