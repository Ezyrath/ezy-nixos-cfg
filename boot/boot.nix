_: {
  # Use the systemd-boot EFI boot loader.
  boot.loader = {
    grub.enable = false;
    systemd-boot = {
      enable = true;
      configurationLimit = 4;
      edk2-uefi-shell.enable = true;
      # Enable memtest86
      memtest86.enable = true;
    };
    efi.canTouchEfiVariables = true;
  };
}
