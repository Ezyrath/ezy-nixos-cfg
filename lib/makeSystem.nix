inputs: {
  system ? "x86_64-linux",
  hostname,
  version,
  sopsSecrets,
  disk,
  boot ? ../boot/boot.nix,
  firewall ? ../firewall/basic.nix,
  authorizedKeys ? [],
  withSSH ? true,
  withGraphic ? false,
  withAMD ? false,
  withNVIDIA ? false,
  withPrinter ? false,
  withK0s ? false,
  extraConfig ? {},
}:
with inputs;
  nixpkgs.lib.nixosSystem {
    inherit system;

    modules =
      [
        # --- modules general ---
        sops-nix.nixosModules.sops
        lanzaboote.nixosModules.lanzaboote
        disko.nixosModules.disko
        nixos-facter.nixosModules.facter
        impermanence.nixosModules.impermanence
        home-manager.nixosModules.home-manager
        nix-flatpak.nixosModules.nix-flatpak

        ../default/configuration.nix
        ../default/network.nix

        # --- module specific ---
        disk
        boot
        firewall
      ]
      # additional configuration per system
      ++ [
        {
          config = {
            # --- main configuration ---
            networking.hostName = hostname;
            system.stateVersion = version;

            # --- SSH configuration ---
            services.openssh.enable = withSSH;
            boot.initrd.network.enable = withSSH;
            boot.initrd.network.ssh.enable = withSSH;
            users.users.ezyrath.openssh.authorizedKeys.keys = authorizedKeys;

            # --- home-manager configuration ---
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              # avoid activation failures when a managed dotfile (e.g. mimeapps.list
              # rewritten by KDE's default-applications UI) has been replaced by a
              # plain file instead of the expected symlink
              backupFileExtension = "backup";
              sharedModules = [
                plasma-manager.homeModules.plasma-manager
                {home.stateVersion = version;}
              ];
              users.ezyrath = {
                imports =
                  [
                    ../home/ezyrath.nix
                  ]
                  ++ (nixpkgs.lib.lists.optionals withGraphic [
                    ../home/ezyrath-graphic.nix
                  ]);
              };
              users.root = {
                imports = [
                  ../home/root.nix
                ];
              };
            };

            # --- sops secrets ---
            sops.defaultSopsFile = sopsSecrets;

            # --- nixpkgs overlays for stable, fast channels and custom packages ---
            nixpkgs.overlays = [
              (_final: _prev: {
                ezy-tools = ezy-tools.packages.${system}.default;
              })
              (final: _prev: {
                stable = import nixpkgs-stable {
                  inherit system;
                  config.allowUnfree = final.config.allowUnfree;
                };
              })
              (final: _prev: {
                fast = import nixpkgs-fast {
                  inherit system;
                  config.allowUnfree = final.config.allowUnfree;
                };
              })
            ];
          };
        }
      ]
      ++ (nixpkgs.lib.lists.optionals withGraphic [
        ../options/graphic.nix
        ../options/flatpak.nix
      ])
      ++ (nixpkgs.lib.lists.optional withAMD ../options/amd.nix)
      ++ (nixpkgs.lib.lists.optional withNVIDIA ../options/nvidia.nix)
      ++ (nixpkgs.lib.lists.optional withPrinter ../options/printer.nix)
      ++ (nixpkgs.lib.lists.optional withK0s ../options/k0s/k0s.nix)
      ++ [extraConfig];
  }
