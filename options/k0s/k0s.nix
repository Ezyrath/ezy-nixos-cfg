{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.services.k0s;

  k0sBinary = pkgs.fetchurl {
    url = "https://github.com/k0sproject/k0s/releases/download/v1.34.2%2Bk0s.0/k0s-v1.34.2+k0s.0-amd64";
    # nixprefetch-url https://github.com/k0sproject/k0s/releases/download/v1.34.2%2Bk0s.0/k0s-v1.34.2+k0s.0-amd64
    sha256 = "03l2x3l1nl1hz35k0w9j59ay8rkkhq7p0cj1yg35mbx5jkscwrc2";
  };

  k0sConfig = pkgs.writeText "k0s.yaml" (builtins.toJSON cfg.config);

  k0s = pkgs.runCommand "k0s" {buildInputs = [pkgs.installShellFiles];} ''
    mkdir -p $out/bin
    cp ${k0sBinary} $out/bin/k0s
    chmod +x $out/bin/k0s
    installShellCompletion --cmd k0s \
      --bash <($out/bin/k0s completion bash) \
      --zsh <($out/bin/k0s completion zsh) \
      --fish <($out/bin/k0s completion fish)
  '';
in {
  imports = [
    ./network.nix
    ./keepalived.nix
    ./haproxy.nix
    ./sops.nix
  ];

  options.services.k0s = {
    enable = mkEnableOption "k0s kubernetes service";

    role = mkOption {
      type = types.enum [
        "controller"
        "worker"
        "controller+worker"
      ];
      default = "controller+worker";
      description = "The role of this node in the k0s cluster.";
    };

    extraFlags = mkOption {
      type = types.str;
      default = "";
      description = "Extra flags to pass to the k0s command (e.g., --token-file, --enable-worker).";
    };

    clusterName = mkOption {
      type = types.str;
      default = "k0s";
      description = "Name of the k0s cluster.";
    };

    useSopsToken = mkEnableOption "Using SOPS managed join token";

    config = mkOption {
      type = types.attrs;
      default = {};
      description = "Configuration structure for k0s.yaml. This will be converted to JSON/YAML and passed to k0s.";
      example = {
        spec = {
          api = {
            port = 6442;
          };
        };
      };
    };

    ha = {
      vipv6 = lib.mkOption {
        type = lib.types.str;
        description = "CIDR notation for the VIP address.";
        example = "fd01::10/16";
      };

      vipInterface = lib.mkOption {
        type = lib.types.str;
        description = "Network interface to bind the VIP address.";
        example = "eth0";
      };

      publicInterface = lib.mkOption {
        type = lib.types.str;
        description = "Network interface to access internet";
        example = "eth1";
      };

      nodes = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              ipv6 = lib.mkOption {
                type = lib.types.str;
                default = "";
              };
            };
          }
        );
        description = "Map of hostname to IPs for all nodes.";
        default = {};
        example = {
          "master-1" = {
            ipv6 = "fd01::100";
          };
        };
      };
    };
    network = {
      ipv6 = lib.mkOption {
        type = lib.types.str;
        description = "IP address of this node.";
        example = "fd01::100";
      };

      podCIDR = lib.mkOption {
        type = lib.types.str;
        default = "fd44::/108";
        description = "CIDR for pods.";
      };

      serviceCIDR = lib.mkOption {
        type = lib.types.str;
        default = "fd96::/108";
        description = "CIDR for services.";
      };

      provider = lib.mkOption {
        type = lib.types.enum [
          "calico"
          "kube-router"
        ];
        default = "calico";
        description = "CNI Provider";
      };

      extraTCPPublicPorts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Extra public ports to expose.";
        example = [
          "80"
          "443"
        ];
      };

      extraUDPPublicPorts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Extra public ports to expose.";
        example = ["53"];
      };
    };

    oidc = {
      issuerUrl = mkOption {
        type = types.str;
        default = "";
        description = "OIDC Issuer URL";
      };
      clientId = mkOption {
        type = types.str;
        default = "kubernetes";
        description = "OIDC Client ID";
      };
      usernameClaim = mkOption {
        type = types.str;
        default = "sub";
        description = "OIDC Username Claim";
      };
      groupsClaim = mkOption {
        type = types.str;
        default = "groups";
        description = "OIDC Groups Claim";
      };
      caFile = mkOption {
        type = types.str;
        default = "";
        description = "Path to CA file for OIDC";
      };
    };
  };

  config = mkIf cfg.enable {
    # Generate the dynamic k0s config based on our high-level options
    services.k0s.config = {
      metadata = {
        name = cfg.clusterName;
      };
      spec = {
        api = {
          address = lib.head (lib.splitString "/" cfg.network.ipv6);
          externalAddress = lib.head (lib.splitString "/" cfg.ha.vipv6);
          port = 6442;
          sans = [
            (lib.head (lib.splitString "/" cfg.ha.vipv6))
            cfg.clusterName
          ];
          extraArgs =
            lib.optionalAttrs (cfg.oidc.issuerUrl != "") {
              oidc-issuer-url = cfg.oidc.issuerUrl;
              oidc-client-id = cfg.oidc.clientId;
              oidc-username-claim = cfg.oidc.usernameClaim;
              oidc-groups-claim = cfg.oidc.groupsClaim;
            }
            // lib.optionalAttrs (cfg.oidc.caFile != "") {
              oidc-ca-file = cfg.oidc.caFile;
            };
        };
        network =
          {
            provider = cfg.network.provider;
            podCIDR = cfg.network.podCIDR;
            serviceCIDR = cfg.network.serviceCIDR;
          }
          // lib.optionalAttrs (cfg.network.provider == "calico") {
            calico = {
              mode = "bird";
              envVars = {
                CALICO_IPV4POOL_IPIP = "Never";
                CALICO_IPV4POOL_VXLAN = "Never";
                IP6_AUTODETECTION_METHOD = "cidr=fd00::/8";
                IP = "none";
                CALICO_ROUTER_ID = "hash";
              };
            };
          }
          // {
            workerProfiles = [
              {
                name = "default";
                values = {
                  shutdownGracePeriod = "2m";
                  shutdownGracePeriodCriticalPods = "30s";
                };
              }
            ];
          };
        telemetry = {
          enabled = false;
        };
      };
    };
    # Add k0s to system packages
    environment.systemPackages = [
      k0s
      pkgs.openiscsi
      pkgs.nfs-utils
      pkgs.cryptsetup
    ];

    # Systemd service for k0s
    systemd.services.k0s = {
      description = "k0s - Zero Friction Kubernetes";
      documentation = ["https://docs.k0sproject.io"];
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target"];
      path = with pkgs; [
        kmod
        util-linux
        iproute2
        iptables
        ethtool
        procps
        findutils
      ];
      serviceConfig = {
        ExecStart = let
          cmd =
            if cfg.role == "worker"
            then "worker"
            else "controller";
          # Auto-add appropriate flags for combined role
          roleFlags =
            if cfg.role == "controller+worker"
            then "--enable-worker --no-taints"
            else "";
          configFlag =
            if cfg.config != {}
            then "--config ${k0sConfig}"
            else "";
          tokenFlag =
            if cfg.useSopsToken
            then "--token-file ${config.sops.secrets.k0s_join_token.path}"
            else "";
          featureGateFlag = "--feature-gates=\"IPv6SingleStack=true\"";
          kubeletFlags = "--kubelet-extra-args='--node-ip=${lib.head (lib.splitString "/" cfg.network.ipv6)}'";
        in "${k0s}/bin/k0s ${cmd} ${roleFlags} ${featureGateFlag} ${configFlag} ${tokenFlag} ${kubeletFlags} ${cfg.extraFlags}";

        Restart = "always";
        RestartSec = "5";
        LimitNOFILE = 1048576;
        LimitNPROC = "infinity";
        LimitCORE = "infinity";
        TasksMax = "infinity";
        TimeoutStopSec = "3m";
      };
    };

    # Persistence for k0s data
    environment.persistence."/persist" = {
      directories = [
        "/var/lib/k0s"
        "/var/lib/longhorn"
      ];
    };

    # Longhorn requirements
    services.openiscsi = {
      enable = true;
      name = "iqn.2016-04.com.openiscsi:${config.networking.hostName}";
    };

    # Fix Longhorn not finding tools (iscsiadm & cryptsetup)
    system.activationScripts.longhorn-tools = {
      text = ''
        mkdir -p /usr/local/bin
        mkdir -p /usr/bin
        # Fix iscsi
        ln -sfn ${pkgs.openiscsi}/bin/iscsiadm /usr/local/bin/iscsiadm
        # Fix cryptsetup for encryption
        ln -sfn ${pkgs.cryptsetup}/bin/cryptsetup /usr/local/bin/cryptsetup
        ln -sfn ${pkgs.cryptsetup}/bin/cryptsetup /usr/bin/cryptsetup
      '';
      deps = [];
    };
  };
}
