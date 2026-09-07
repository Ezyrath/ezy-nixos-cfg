_: {
  boot = {
    # Use the systemd-boot EFI boot loader.
    loader = {
      grub.enable = false;
      systemd-boot = {
        enable = false;
        edk2-uefi-shell.enable = true;
        # Enable memtest86
        memtest86.enable = true;
      };
      efi.canTouchEfiVariables = true;
    };

    # Use secure boot
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };
  };
}
