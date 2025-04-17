# Collection of Linux Persistence Hunting Scripts

## audit-ko.sh
Compares `ls` output on kernel object directories to debugfs output to find hidden files. 

## audit-services.sh
Checks systemd services against dpkg -S and snap to find unowned services that may be malicious. Could have false postives. 

## collect-seek-destroy.sh
