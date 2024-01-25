#!/bin/bash
set -e

# Function to log messages
log() {
  echo "[INFO] $1"
}

# Function to log errors and exit
error() {
  echo "[ERROR] $1" >&2
  exit 1
}

# Function to prompt user for confirmation
confirm() {
  read -r -p "$1 [Y/n] " response
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    log "Script aborted by user."
    exit 0
  fi
}

# Check for required argument
if [ -z "$1" ]; then
  error "You must specify the disk device being extended, e.g., /dev/sda"
fi

device="$1"
lvm=""
partition_type="E6D6D379-F507-44C2-A23C-238F2A3DF928"

# Determine if LVM is in use
pvdevice=$(pvs | grep "$device" | awk '{print $1}' | xargs)
if [ -n "$pvdevice" ]; then
  lvm=true
fi

# Determine the partition number
if [ -n "$lvm" ]; then
  vgdevice=$(pvs | grep "$device" | awk '{print $2}' | xargs)
  read -r -p "Enter the partition number for $device: " partition_number
else
  last_partition=$(fdisk -l 2> /dev/null | grep "^$device" | awk '{print $1}' | tail -n 1)
  read -r -p "Enter the partition number for $device: " partition_number
fi

# Confirm user's intention
confirm "This script will extend the disk partition on $device. Do you want to proceed?"

# Resize the disk partition
log "Resizing disk partition..."
sfdisk "$device" -N"${partition_number}" --force <<EOF
-,-,-
EOF

sfdisk "$device" -N"${partition_number}" --force <<EOF
-,+,$partition_type
EOF

partprobe

# Resize LVM logical volume (if applicable)
if [ -n "$lvm" ]; then
  log "Resizing LVM logical volume..."
  pvresize "$pvdevice"
  lvpath=$(lvdisplay "$vgdevice" | grep "LV Path" | awk '{print $3}' | xargs)
  lvextend -l +100%FREE "$lvpath"
fi

# Resize the file system
log "Resizing file system..."
if [ -n "$lvm" ]; then
  filesystem_path="$lvpath"
else
  filesystem_path="$last_partition"
fi

case "$(df -Th "$filesystem_path" | tail -1 | awk '{print $2}')" in
  ext4)
    resize2fs "$filesystem_path"
    ;;
  xfs)
    xfs_growfs "$filesystem_path"
    ;;
  *)
    error "Unsupported file system type."
    ;;
esac

log "File system resize is finished!"
