{
  config,
  pkgs,
  ...
}: let
  # Other python packages
  python-packages = ps:
    with ps; [
      virtualenv
      yt-dlp
    ];

  # absolute path to the repo checkout on the target machine, needed to read
  # gitignored files (facter.json, secrets/) with --impure
  repoRoot = /etc/nixos;
in {
  # Set your time zone.
  time.timeZone = "Europe/Paris";

  # Select internationalisation properties.
  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = [
      "en_US.UTF-8/UTF-8"
      "fr_FR.UTF-8/UTF-8"
    ];
    extraLocaleSettings = {
      LC_TIME = "fr_FR.UTF-8";
      LC_MEASUREMENT = "fr_FR.UTF-8";
      LC_MONETARY = "fr_FR.UTF-8";
      LC_NUMERIC = "fr_FR.UTF-8";
      LC_PAPER = "fr_FR.UTF-8";
      LC_TELEPHONE = "fr_FR.UTF-8";
      LC_NAME = "fr_FR.UTF-8";
      #LC_IDENTIFICATION = "fr_FR.UTF-8";
      LC_ADDRESS = "fr_FR.UTF-8";
    };
  };

  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
    earlySetup = true;
  };

  # use nonfree
  nixpkgs.config.allowUnfree = true;

  # accept license
  nixpkgs.config.android_sdk.accept_license = true;

  # nix settings and automated maintenance
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "Sun 04:00";
      options = "--delete-older-than 14d";
    };
  };

  boot = {
    # set kernel version
    kernelPackages = pkgs.linuxPackages_latest;

    # TCP BBR congestion control and network latency optimization
    kernel.sysctl = {
      "net.core.default_qdisc" = "cake";
      "net.ipv4.tcp_congestion_control" = "bbr";
    };

    # Enable ssh in initrd (rescue mode)
    initrd.network.ssh = {
      port = 2222;
      hostKeys = [
        (repoRoot + "/secrets/initrd_ssh_key")
      ];
      authorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILdaDRDViIf80h8tcbnv7PlngZoBudB94dLkf80JunhR initrd"
      ];
    };

    # Add kernel modules network for initrd ssh
    initrd.availableKernelModules = [
      "igb"
      "igc"
    ];
  };

  # Hardware firmware and CPU microcode updates
  hardware = {
    enableRedistributableFirmware = true;
    cpu.amd.updateMicrocode = true;
  };

  # set nixos-facter report path
  facter.reportPath = repoRoot + "/facter.json";

  # set sops age key file location
  sops.age.keyFile = "/persist/var/lib/sops/key.age";

  # --- sops secrets ---
  sops.secrets = {
    ezyrath_password = {
      neededForUsers = true;
    };
  };

  # Set user accounts
  users = {
    mutableUsers = false;
    users = {
      root = {
        hashedPassword = "!";
      };
      ezyrath = {
        isNormalUser = true;
        hashedPasswordFile = config.sops.secrets.ezyrath_password.path;
        extraGroups = [
          "wheel"
          "libvirtd"
          "kvm"
          "adbusers"
          "input"
        ];
      };
    };
  };

  # Set what sudo preserves
  security.sudo.extraConfig = ''
    # preserve ssh-add
    Defaults env_keep += "SSH_AUTH_SOCK"
  '';

  # List packages installed in system profile
  environment.systemPackages = with pkgs; [
    # utils
    htop
    btop
    usbutils
    pciutils # lspci
    fastfetch
    vim
    file
    tree
    wget
    curl
    ripgrep # rg
    fd # faster find
    ncdu # disk space visualizer
    imagemagick
    ghostscript
    exiftool
    rclone # file synchronization
    ffmpeg-full # video/audio processing
    smartmontools # disk health
    sbctl # secure boot management
    sops # secrets management
    nixos-facter # generate hardware facts
    nixos-anywhere # deploy NixOS over SSH
    yq-go # yaml parser
    jq # json parser
    moreutils # useful utils

    # encryption
    age

    # compression
    zip
    unzip
    unrar
    p7zip

    # dev
    git
    git-lfs
    git-annex
    pre-commit
    nixfmt
    shfmt
    nixd
    nil

    # dev env
    nodejs # LTS - https://nodejs.org/en/download
    #androidsdk # too heavy install manually
    (pkgs.python3.withPackages python-packages) # https://devguide.python.org/versions/
  ];

  services = {
    # Periodic TRIM for NVMe SSD longevity and performance
    fstrim = {
      enable = true;
      interval = "Sun 04:30";
    };

    # Configure Journald retention
    journald.extraConfig = ''
      SystemMaxUse=1G
      MaxRetentionSec=1month
    '';

    # Configure OpenSSH daemon.
    openssh.settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      PubkeyAuthentication = "yes";
      GSSAPIAuthentication = "no";
      ChallengeResponseAuthentication = "no";
      LogLevel = "VERBOSE";
    };
  };

  programs = {
    # Enable Firejail
    firejail.enable = true;

    # Enable GnuPG
    gnupg.agent = {
      enable = true;
      pinentryPackage = pkgs.pinentry-qt;
      enableExtraSocket = true;
    };

    # Configure SSH Client
    ssh = {
      startAgent = true;
      knownHosts = {
        "github-ed25519" = {
          hostNames = ["github.com"];
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
        };
        "github-ecdsa" = {
          hostNames = ["github.com"];
          publicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=";
        };
        "github-rsa" = {
          hostNames = ["github.com"];
          publicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=";
        };
      };
    };
  };

  # Use docker (rootless)
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };

  # Enable kvm/libvirtd
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      vhostUserPackages = [pkgs.virtiofsd];
      runAsRoot = true;
      swtpm.enable = true;
    };
  };

  # Impermanence configuration
  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/systemd/coredump"

      "/etc/ssh" # SSH server keys
      "/etc/nixos" # NixOS configuration files
      "/var/lib/nixos" # NixOS state files

      "/etc/NetworkManager/system-connections"
      "/etc/NetworkManager/VPN"

      "/var/lib/libvirt"
      "/var/lib/qemu"

      "/var/lib/fail2ban" # fail2ban state
      "/var/lib/sbctl" # secure boot keys
    ];
    files = [
      "/etc/machine-id"
    ];
    users.ezyrath = {
      directories = [
        "Desktop"
        "Documents"
        "Downloads"
        ".config"
        ".local"
        "cloud" # personal cloud data
        ".cache" # cache data
        ".cargo" # rust cargo data
        ".gnupg" # gpg keys
        ".pki" # pki data
        ".docker" # docker config
        ".gemini" # antigravity cli & gemini config
        ".kube" # kubernetes config
      ];
      files = [];
    };
  };
}
