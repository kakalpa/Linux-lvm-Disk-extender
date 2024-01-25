# LVM Disk Partition Extension Script
This Bash script is designed to facilitate the extension of LVM (Logical Volume Manager) disk partitions, allowing users to make use of additional space after increasing the virtual disk size through virtualization tools like VirtualBox, OpenStack, Proxmox or others.

## Usage
To use this script, follow the example below:

```bash
./extend-lvm.sh /dev/sda
```
Ensure you replace /dev/sda with the appropriate disk device you wish to extend. Running fdisk -l will provide information about existing devices and partitions.

## Prerequisites

This script is intended for systems using LVM. If LVM is not in use, it may not be suitable.
The script assumes familiarity with disk management concepts and tools.

## Instructions
Specify Disk Device:

Provide the target disk device as a command-line argument (e.g., /dev/sda).

## Partition Number Determination:

If using LVM, the partition number corresponds to the LVM-configured partition.
**If not using LVM, the script identifies the last partition on the specified disk.**

## Resize Disk Partition:

The script uses the **sfdisk** command to interactively resize the disk partition.
It first writes to the disk with no changes and then increases the size to the maximum available.
Resize LVM Logical Volume (if applicable):

If LVM is in use, the script resizes the physical volume and extends the logical volume.

## Resize File System:

Depending on the file system type (ext4 or xfs), the script uses either resize2fs or xfs_growfs to resize the file system.

**Notes**
This script is designed for Linux systems.
Ensure that you have appropriate backups before performing disk and partition operations.
Feel free to modify and adapt the script according to your specific requirements and environment.
