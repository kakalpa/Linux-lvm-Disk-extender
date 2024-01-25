#!/bin/bash

if [ -z "$1" ] ; then
  echo "You must specify the disk device being extended, eg: /dev/sda or /dev/vda";
  echo "Example Usage: ./extend-lvm.sh /dev/sda";
  echo "Run 'fdisk -l' to see the existing devices and partitions. If there are more than one, this will also give you a clue as to which one has grown and needs to be modified";
  exit 1
fi
device=$1;
lvm="";

# Get the LVM physical device if using LVM
# ----------------------------------------

# Get the physical volume device 
pvdevice=$(pvs | grep $device | awk ' { print $1; } ' | xargs);

# If there is no pvdevice, then the system is not using LVM
if [ -z "$pvdevice" ] ; then lvm="";
else lvm=true; fi


#disklabel_type=$(fdisk -l $device | grep -i disklabel | awk -F ":" ' { print $2; } ' | xargs);

# Part 1 - Determine the partition number to delete  
# -------------------------------------------------
# This may be different for depending on if it is LVM or non-LVM


# If using LVM, then the partition number is that of the partition that is configured for LVM
if [ -n "$lvm" ] ; then
  # Get the volume group device
  vgdevice=$(pvs | grep $device | awk ' { print $2; } ' | xargs);

  # Set the partition type to be the GUID for LVM: (This will work for MBR/GPT and in EFI or non-EFI scenarios
  partition_type="E6D6D379-F507-44C2-A23C-238F2A3DF928";

  # Get the partition number of the physical volume device so that we can update that one with sfdisk in Part 2
  # This command uses the built in bash search and replace tool ${string_to_search_and_replace/$string_to_find/$string_to_replace}
  #   In this case, we do not have a "$string_to_replace" variable at the end, so it will just remove the search string
  #   Eg: pvdevice=/dev/vda2; partition=/dev/vda  Result: partition_number="2" (/dev/vda stripped away)
  partition_number=${pvdevice/$device/}

# if not using LVM, then the partition number is that of the LAST partition on the disk
else
  # Find the last partition on the $device
  last_partition=$(fdisk -l 2> /dev/null | egrep "^/dev/vda" | awk ' { print $1 } ' | tail -n 1);

  # Find the file system type of the last partition
  filesystem=$(df -Th "/dev/vda2" | tail -1 |  awk ' { print $2 } ');

  # Get the partition number of the physical volume device so that we can update that one with sfdisk in Part 2
  # This command uses the built in bash search and replace tool ${string_to_search_and_replace/$string_to_find/$string_to_replace}
  #   In this case, we do not have a "$string_to_replace" variable at the end, so it will just remove the search string
  #   Eg: pvdevice=/dev/vda2; partition=/dev/vda  Result: partition_number="2" (/dev/vda stripped away)
  partition_number=${last_partition/$device/}
fi

# Part 2 - resize the disk partition
# ----------------------------------
# This script pipes commands into the interactive sfdisk command so you do not have to interact with it
#   The -N# option specifies the partition we want to modify (eg: -N2 is the 2nd partition on the given device
#   sfdisk takes a command of the format: <start>,<size>,<type>[,<bootable>]
#   We can use "-" to just use the default (which is the current values for the partition), "+" can be used to specify max-available, "lvm" is a short form for lvm

# First we write to the disk with no changes, to make sure any paritition table inconsistencies are addressed
sfdisk $device -N${partition_number} --force << EOF
-,-,-
EOF

# Next, we write to the disk and increase the <size> to the max availabe (using the "+" sign)
sfdisk $device -N${partition_number} --force << EOF
-,+,$partition_type
EOF

# Force the kernel to probe the size of the partition:
partprobe

# Part 3 - resize LVM logical volume
# ----------------------------------
# This is only done for the LVM case

# If LVM is used:
if [ -n "$lvm" ] ; then
  # Resize the physical volume
  pvresize $pvdevice

  # Get the logical volume path
  lvpath=$(lvdisplay $vgdevice | grep "LV Path" | awk ' { print $3; } ' | xargs);
  echo "File System Path: $lvpath";

  filesystem=$(df -Th "$lvpath" | tail -1 |  awk ' { print $2 } ');
  echo "File System Type: $filesystem";

  # Extend the logical volume
  lvextend -l +100%FREE $lvpath

fi


# Part 4 - Resize the file system on the partion/volume
# -----------------------------------------------------
# The path to the file system will be different for LVM or a raw partition:

# If LVM is used:
if [ -n "$lvm" ] ; then
  filesystem_path="$lvpath";
# If not using LVM:  
else
  filesystem_path="$last_partition";
fi

# ubuntu we use ext4 by default
if [ "$filesystem" = "ext4" ] ; then
  resize2fs $filesystem_path;
# CentOS / Fedora / RedHat use xfs by default
elif [ "$filesystem" = "xfs" ] ; then
  xfs_growfs $filesystem_path;
else
  # Generate an error if it is not a common one.  We can add more checks if other filesystems are regularly used on openstack images.
  echo "ERROR: Filesystem type \"$filesystem\" for $filesystem_path did not match an expected type";
  exit 1;
fi

echo "";
echo "File System resize is finished!"

