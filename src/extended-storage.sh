#!/usr/bin/env bash
set -Eeuo pipefail

# Extended Storage Configuration
: "${EXT_STORAGE:=""}"
: "${EXT_STORAGE_SIZE:="8G"}"
: "${EXT_STORAGE_BOOT:="N"}"

configureExtendedStorage() {

  local size="$EXT_STORAGE_SIZE"
  
  # If EXT_STORAGE is not enabled, skip
  [[ "${EXT_STORAGE,,}" != "y" ]] && return 0
  
  local msg="Configuring extended storage (${size})..."
  info "$msg" && html "$msg"
  
  # Set the storage file path
  EXT_STORAGE_FILE="$STORAGE/extended.img"
  
  # Create the extended storage disk if it doesn't exist
  if [ ! -f "$EXT_STORAGE_FILE" ]; then
    local msg="Creating ${size} extended storage disk..."
    info "$msg" && html "$msg"
    
    # Create a raw disk image
    if ! qemu-img create -f raw "$EXT_STORAGE_FILE" "$size" 2>&1 | tee -a "$QEMU_LOG"; then
      error "Failed to create extended storage disk!" && return 1
    fi
    
    # Format the disk with FAT32 for Windows compatibility
    # This makes it appear more like a USB drive
    if command -v mkfs.vfat &> /dev/null; then
      local msg="Formatting extended storage as FAT32..."
      info "$msg" && html "$msg"
      
      # Create FAT32 filesystem with volume label "Extended"
      if ! mkfs.vfat -F 32 -n "EXTENDED" "$EXT_STORAGE_FILE" 2>&1 | tee -a "$QEMU_LOG"; then
        warn "Failed to format extended storage, will be unformatted"
      fi
    fi
  fi
  
  # Add the extended storage as a USB storage device
  # Using usb-storage makes it appear as removable media in Windows
  ARGS="${ARGS:+$ARGS }-drive file=$EXT_STORAGE_FILE,if=none,id=usbstick,format=raw,cache=writeback"
  
  # Add bootindex if boot is enabled (lower number = higher priority)
  # bootindex=1 makes it the first boot device, higher numbers boot after main disk
  if [[ "${EXT_STORAGE_BOOT,,}" == "y" ]]; then
    ARGS="$ARGS -device usb-storage,drive=usbstick,removable=on,bootindex=1"
    local msg="Extended storage configured as bootable device (bootindex=1)"
    info "$msg" && html "$msg"
  else
    ARGS="$ARGS -device usb-storage,drive=usbstick,removable=on"
  fi
  
  return 0
}

# Call the configuration function if this script is sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  configureExtendedStorage
fi

return 0
