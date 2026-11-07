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
        nix-citizen.nixosModules.default

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
              (_final: _prev: let
                citizenPkgs = nix-citizen.inputs.nixpkgs.legacyPackages.${system};
                mesa64 = citizenPkgs.mesa;
                mesa32 = citizenPkgs.pkgsi686Linux.mesa;
                lsfgVk = citizenPkgs.lsfg-vk;
                rawWineAstral = nix-citizen.packages.${system}.wine-astral;
                # Fix Star Citizen cursor offset after Alt-Tab / window focus change on Wayland:
                # nix-citizen applies winewayland-prefer-relative-pointer.patch (keeping
                # pointer.relative_mode = TRUE permanently) but blacklists LUG's companion
                # winewayland-no-enter-move-if-relative.patch. Without it, pointer_handle_enter
                # calls pointer_handle_motion_internal(sx, sy) on every wl_pointer::enter,
                # shifting Win32's cursor position while WM_INPUT receives (0, 0).
                wineAstralPatched =
                  citizenPkgs.runCommand "${rawWineAstral.name}-wayland-enter-fix" {
                    inherit (rawWineAstral) pname version meta passthru;
                  } ''
                    mkdir -p "$out/lib/wine"
                    cp -a "${rawWineAstral}/bin" "$out/bin"
                    cp -a "${rawWineAstral}/lib/wine/x86_64-unix" "$out/lib/wine/x86_64-unix"
                    ln -s "${rawWineAstral}/include" "$out/include"
                    ln -s "${rawWineAstral}/share" "$out/share"
                    ln -s "${rawWineAstral}/lib/wine/i386-windows" "$out/lib/wine/i386-windows"
                    ln -s "${rawWineAstral}/lib/wine/x86_64-windows" "$out/lib/wine/x86_64-windows"

                    so="$out/lib/wine/x86_64-unix/winewayland.so"
                    chmod u+w "$so"
                    orig=$(od -An -tx1 -j $((0x128d2)) -N 32 "$so" | tr -d ' \n')
                    expected="4489f78b75d44883c4085b415c415d415e415f5d31c031c931d24531c04531c9"
                    if [ "$orig" != "$expected" ]; then
                      echo "Unexpected bytes in winewayland.so at 0x128d2: $orig" >&2
                      exit 1
                    fi
                    # Check pointer.relative_mode (0x160) and jump to return epilogue (0x128f7) if active
                    printf '\x83\xbb\x60\x01\x00\x00\x00\x75\x1c\x44\x89\xf7\x8b\x75\xd4\x48\x83\xc4\x08\x5b\x41\x5c\x41\x5d\x41\x5e\x41\x5f\x5d\x31\xc0\x90' \
                      | dd of="$so" bs=1 seek=$((0x128d2)) conv=notrunc status=none
                    chmod u-w "$so"
                  '';
              in {
                ezy-tools = ezy-tools.packages.${system}.default;
                ezy-tools-dev = ezy-tools.packages.${system}.dev;
                inherit
                  (nix-citizen.packages.${system})
                  lug-helper
                  ;
                wine-astral = wineAstralPatched;
                rsi-launcher = nix-citizen.packages.${system}.rsi-launcher.override (
                  {
                    wine = wineAstralPatched;
                  }
                  // nixpkgs.lib.optionalAttrs (!withNVIDIA) {
                    extraEnvVars = {
                      VK_DRIVER_FILES = "${mesa64}/share/vulkan/icd.d/radeon_icd.x86_64.json:${mesa32}/share/vulkan/icd.d/radeon_icd.i686.json:${mesa64}/share/vulkan/icd.d/intel_icd.x86_64.json:${mesa32}/share/vulkan/icd.d/intel_icd.i686.json";
                      VK_ADD_IMPLICIT_LAYER_PATH = "${lsfgVk}/share/vulkan/implicit_layer.d";
                      LIBGL_DRIVERS_PATH = "${mesa64}/lib/dri:${mesa32}/lib/dri";
                      __EGL_VENDOR_LIBRARY_DIRS = "${mesa64}/share/glvnd/egl_vendor.d:${mesa32}/share/glvnd/egl_vendor.d";
                      LIBVA_DRIVERS_PATH = "${mesa64}/lib/dri:${mesa32}/lib/dri";
                    };
                  }
                );
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
