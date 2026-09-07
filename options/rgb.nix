{pkgs, ...}: {
  # Enable OpenRGB
  services.hardware.openrgb.enable = true;

  # OpenRGB udev rules
  services.udev.packages = [pkgs.openrgb];
  boot.kernelModules = ["i2c-dev"];
  hardware.i2c.enable = true;
}
