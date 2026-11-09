_: {
  boot = {
    # Use the systemd-boot EFI boot loader.
    loader = {
      grub.enable = false;
      systemd-boot = {
        enable = false;
        configurationLimit = 4;
        edk2-uefi-shell.enable = true;
        # Enable memtest86
        memtest86.enable = true;
      };
      efi.canTouchEfiVariables = true;
    };

    # Use secure boot
    lanzaboote = {
      enable = true;
      configurationLimit = 4;
      pkiBundle = "/var/lib/sbctl";
    };
  };
}
