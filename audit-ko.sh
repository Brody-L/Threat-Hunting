#!/bin/bash

# Find all visible .ko and .ko.xz files
find / -type f -name "*.ko" -exec ls {} + 2>/dev/null > /tmp/ko_ls.txt

OUTPUT="/tmp/ko_debugfs_results.txt"
> "$OUTPUT"

# Find all mounted ext[234] partitions
mapfile -t FS_DEVICES < <(mount | grep -E 'type ext[234]' | awk '{print $1}')

# Gather common kernel object directories
mapfile -t KO_DIRS < <(find /lib/modules/ -type d -path "*/kernel/*" 2>/dev/null)

echo "[*] Scanning for .ko files using debugfs..." | tee -a "$OUTPUT"

for DEV in "${FS_DEVICES[@]}"; do
    echo -e "\n=== Device: $DEV ===" | tee -a "$OUTPUT"
    for DIR in "${KO_DIRS[@]}"; do
        echo -e "\n-- Dir: $DIR" | tee -a "$OUTPUT" 2>/dev/null
        debugfs "$DEV" -R "ls $DIR" 2>/dev/null | grep "\.ko" >> "$OUTPUT"
    done
done

echo -e "\n[*] Scan complete. Output saved to $OUTPUT"

# === Parse ls output ===
awk -F\/ '{print $NF}' /tmp/ko_ls.txt | sort | uniq  > /tmp/ko_ls_filenames.txt

# === Parse debugfs output ===
grep "\.ko" /tmp/ko_debugfs_results.txt | awk '{print $NF}' | sort | uniq > /tmp/ko_debugfs_filenames.txt

oddity=$(diff -u <(cat /tmp/ko_ls_filenames.txt) <(grep "\.ko" /tmp/ko_debugfs_filenames.txt) | sort | uniq | grep '^\+')

echo "[*] Parsed results:"
echo " - Visible files: /tmp/ko_ls_filenames.txt"
echo " - Debugfs files: /tmp/ko_debugfs_filenames.txt"
echo "----"
echo "[*] Potential Oddity:"
echo " - Diffed results:"
echo "$oddity"
