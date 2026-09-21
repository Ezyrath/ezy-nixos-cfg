{
  lib,
  pkgs,
  ...
}: let
  sshConfig = ''
    Host git.ezyrium.com
      User git
      ProxyCommand /usr/bin/cloudflared access ssh --hostname %h
  '';
in {
  home = {
    packages = [
      pkgs.ezy-tools
      pkgs.ezy-tools-dev
    ];

    # Generate SSH known_hosts file with strict permissions (600) to avoid "Bad owner or permissions"
    # error caused by symlinks.
    activation.writeKnownHosts = lib.hm.dag.entryAfter ["writeBoundary"] ''
      mkdir -p $HOME/.ssh
      chmod 700 $HOME/.ssh
      rm -f $HOME/.ssh/known_hosts
      cp -f /etc/ssh/ssh_known_hosts $HOME/.ssh/known_hosts
      chmod 600 $HOME/.ssh/known_hosts
    '';

    # Generate SSH config file with strict permissions (600) to avoid "Bad owner or permissions"
    # error caused by symlinks to the world-readable Nix store (owned by nobody/root).
    activation.writeSshConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
      mkdir -p $HOME/.ssh
      chmod 700 $HOME/.ssh
      rm -f $HOME/.ssh/config
      cat <<EOF > $HOME/.ssh/config
      ${sshConfig}
      EOF
      chmod 600 $HOME/.ssh/config
    '';
  };

  programs.bash = {
    enable = true;
    initExtra = ''
      export VISUAL="vi"
      export EDITOR="$VISUAL"

      # ~/.local/bin
      export PATH="$PATH:''${HOME}/.local/bin"

      # prompt
      if [ -z "$name" ]; then
          PS1="\[\e[93m\]┌───(\u@\h) \[\e[37m\]\w\n\[\e[93m\]└─§> \[\e[0m\]"
      else
          PS1="\[\e[92m\]┌───(\u@''${name}) \[\e[37m\]\w\n\[\e[92m\]└─§> \[\e[0m\]"
      fi
    '';
  };

  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      user.name = "Ezyrath";
      user.email = "9325242+Ezyrath@users.noreply.github.com";
      init.defaultBranch = "main";
    };
    signing.signByDefault = true;
    signing.key = "E0DFB748B8F1E946";
  };

  # create config (libvirt/qemu)
  xdg.configFile."libvirt/qemu.conf" = {
    text = ''
      # Adapted from /var/lib/libvirt/qemu.conf
      # Note that AAVMF and OVMF are for Aarch64 and x86 respectively
      nvram = [ "/run/libvirt/nix-ovmf/AAVMF_CODE.fd:/run/libvirt/nix-ovmf/AAVMF_VARS.fd", "/run/libvirt/nix-ovmf/OVMF_CODE.fd:/run/libvirt/nix-ovmf/OVMF_VARS.fd" ]
    '';
  };

  # create config (pipewire) - create virtual microphone/speakers
  xdg.configFile."pipewire/pipewire.conf.d/91-virtual-cable.conf" = {
    text = ''
      context.objects = [
        { factory = adapter
          args = {
            factory.name     = support.null-audio-sink
            node.name        = "virtual-source"
            node.description = "Virtual Source"
            media.class      = "Audio/Source/Virtual"
            audio.position   = "FL,FR"
          }
        }
        { factory = adapter
          args = {
            factory.name     = support.null-audio-sink
            node.name        = "virtual-sink"
            node.description = "Virtual Sink"
            media.class      = "Audio/Sink"
            audio.position   = "FL,FR"
          }
        }
        { factory = adapter
          args = {
            factory.name     = support.null-audio-sink
            node.name        = "virtual-source-to-speakers"
            node.description = "Virtual Source connected to Speakers (Hidden)"
            media.class      = "Audio/Source/Virtual"
            audio.position   = "FL,FR"
          }
        }
      ]
    '';
  };
}
