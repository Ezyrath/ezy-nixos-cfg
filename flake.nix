# /etc/nixos/flake.nix
{
  description = "ezyrath NixOS configuration";

  inputs = {
    nixpkgs.url = "github:Nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-fast.url = "github:NixOS/nixpkgs";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-facter = {
      url = "github:numtide/nixos-facter-modules";
      #inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence = {
      url = "github:nix-community/impermanence";
      #inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak = {
      url = "github:gmodena/nix-flatpak";
      #inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    ezy-tools = {
      url = "github:Ezyrath/ezy-tools";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: let
    makeSystem = import ./lib/makeSystem.nix inputs;
    # absolute path to the repo checkout on the target machine, needed to
    # read gitignored secrets files with --impure
    repoRoot = /etc/nixos;
  in {
    nixosConfigurations = {
      # --- workstations ---
      ezy001wks = makeSystem {
        hostname = "ezy001wks";
        version = "25.11";
        boot = ./boot/secure-boot.nix;
        sopsSecrets = repoRoot + "/secrets/workstation.yaml";
        disk = ./disk/nvme.nix;
        withSSH = false;
        withGraphic = true;
        #withAMD = true;
      };

      ezy002wks = makeSystem {
        hostname = "ezy002wks";
        version = "25.11";
        sopsSecrets = repoRoot + "/secrets/workstation.yaml";
        disk = ./disk/nvme.nix;
        authorizedKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILBev7axXZTXvx4x1r6rNVnhhQtS6gq7eTDlpFOKhJpX ezyrath@ezy002wks"
        ];
        withSSH = false;
        withGraphic = true;
        withNVIDIA = true;
      };

      # --- servers ---
      ezy001srv = makeSystem {
        hostname = "ezy001srv";
        version = "25.11";
        sopsSecrets = repoRoot + "/secrets/server.yaml";
        disk = ./disk/nvme-raid1.nix;
        authorizedKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMF0LY7nv3FuJzI0w1tYOg5hsj6J6GNPgXhwVe3reZHx ezy001srv"
        ];

        withK0s = true;

        extraConfig = {
          services.k0s = {
            enable = true;
            role = "controller+worker";
            clusterName = "k8s.ezyrium.com";
            ha = {
              vipv6 = "fd01::10/16";
              vipInterface = "enp7s0";
              publicInterface = "enp6s0";
              nodes = {
                ezy001srv.ipv6 = "fd01::100";
                #ezy002srv.ipv6 = "fd01::101";
                #ezy003srv.ipv6 = "fd01::102";

                # --- WARNING ---
                # IF add a new node, add is the spf domain record for mail !!!
                # --- WARNING ---
              };
            };
            oidc = {
              issuerUrl = "https://auth.ezyrium.com/realms/master";
              clientId = "kubernetes";
            };
            network = {
              ipv6 = "fd01::100/16";
              extraTCPPublicPorts = [
                "6443"
              ];
            };
          };
        };
      };
    };
  };
}
