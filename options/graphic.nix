{
  pkgs,
  lib,
  ...
}: {
  environment = {
    # system packages (graphics related)
    sessionVariables.NIXOS_OZONE_WL = "1";
    systemPackages = with pkgs; [
      setxkbmap
      xdg-utils
      yubioath-flutter # Yubico Authenticator (GUI: OATH, FIDO2, PIV, OTP slots)
      nvtopPackages.full # GPU process monitor (AMD/Intel/Nvidia)

      # desktop & creative applications (native FOSS)
      audacity
      blender
      gimp
      inkscape
      kdePackages.kcalc
      keepassxc
      krita
      obs-studio
      qpwgraph
      vlc
    ];

    plasma6.excludePackages = with pkgs.kdePackages; [
      plasma-browser-integration
      discover
      oxygen
      elisa
    ];

    # Impermanence configuration
    persistence."/persist" = {
      directories = [
        "/var/lib/flatpak" # flatpak apps and data
      ];
      users.ezyrath = {
        directories = [
          "Android" # android sdk
          ".android" # android config
          ".var" # flatpak apps data
          ".rustup" # rustup data
        ];
      };
    };
  };

  # user packages (graphics related)
  # users.users.ezyrath.packages = with pkgs; [
  #   #pkgsRocm.blender
  # ];

  # enable graphics support
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services = {
    # enable desktop environment (KDE Plasma 6)
    desktopManager.plasma6.enable = true;

    # smartcard daemon, required by Yubico Authenticator
    pcscd.enable = true;

    # steam input support + wooting + yubikey
    udev.packages = with pkgs; [
      game-devices-udev-rules
      wooting-udev-rules
      yubikey-personalization
    ];

    # enable ntsync for wine
    udev.extraRules = ''
      KERNEL=="ntsync", MODE="0644"
    '';

    # use pipewire
    # rtkit is optional but recommended
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
      #package = nixpkgs.pipewire-stable.pipewire;
    };
  };

  programs = {
    # enable gamemode (CPU/GPU optimizations for gaming)
    gamemode.enable = true;

    # enable virt-manager
    virt-manager.enable = true;

    # use dconf for theme settings for flatpak apps
    dconf.enable = true;

    # KDE Connect
    kdeconnect.enable = true;
  };

  # open KDE Connect ports; the allowedTCPPortRanges/allowedUDPPortRanges set
  # by programs.kdeconnect have no effect since networking.firewall is
  # disabled in favor of the custom nftables ruleset in firewall/basic.nix,
  # so add the accept rules to that same ruleset here instead.
  # mkAfter ensures this is appended after basic.nix's "flush ruleset; table
  # inet filter { ... }" block, since the table must exist first.
  networking.nftables.ruleset = lib.mkAfter ''
    add rule inet filter input tcp dport 1714-1764 accept
    add rule inet filter input udp dport 1714-1764 accept
  '';

  # use waydroid
  #virtualisation.waydroid.enable = true;

  # use portal fix gtk for flatpak apps
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      kdePackages.xdg-desktop-portal-kde
      xdg-desktop-portal-gtk
    ];
    configPackages = with pkgs; [
      kdePackages.xdg-desktop-portal-kde
      xdg-desktop-portal-gtk
    ];
  };

  # steam input support + wooting
  hardware.uinput.enable = true;

  # enable ntsync for wine
  boot.kernelModules = ["ntsync"];

  # rtkit is optional but recommended
  security.rtkit.enable = true;

  # create icons/fonts bind mounts for flatpak apps
  system.fsPackages = [pkgs.bindfs];
  fileSystems = let
    mkRoSymBind = path: {
      device = path;
      fsType = "fuse.bindfs";
      options = [
        "ro"
        "resolve-symlinks"
        "x-gvfs-hide"
      ];
    };
    aggregated = pkgs.buildEnv {
      name = "system-fonts-and-icons";
      paths = with pkgs; [
        kdePackages.breeze

        noto-fonts
        noto-fonts-color-emoji
        noto-fonts-cjk-sans
        noto-fonts-cjk-serif
      ];
      pathsToLink = [
        "/share/fonts"
        "/share/icons"
      ];
    };
  in {
    # Create an FHS mount to support flatpak host icons/fonts
    "/usr/share/icons" = mkRoSymBind "${aggregated}/share/icons";
    "/usr/share/fonts" = mkRoSymBind "${aggregated}/share/fonts";
  };
}
