{pkgs, ...}: {
  # --- SCANNER & PRINTER ---
  services = {
    # Enable CUPS to print documents.
    printing.enable = true;

    # Enable Device network service discovery
    avahi = {
      enable = true;
      nssmdns4 = true;
    };
  };

  # Enable Scanner
  hardware.sane = {
    enable = true;
    extraBackends = [pkgs.sane-airscan]; # airscan > escl
    disabledDefaultBackends = ["escl"];
  };
  # --------------------------
}
