_: {
  services.flatpak = {
    enable = true;
    #update.onActivation = true;
    packages = [
      # applications
      "com.github.tchx84.Flatseal"
      "org.mozilla.firefox"
      "com.google.Chrome"
      "com.heroicgameslauncher.hgl"
      "com.obsproject.Studio"
      "com.valvesoftware.Steam"
      "dev.vencord.Vesktop"
      "io.github.Qalculate.qalculate-qt"
      "org.audacityteam.Audacity"
      "org.gimp.GIMP"
      "org.blender.Blender"
      "org.kde.krita"
      "org.keepassxc.KeePassXC"
      "org.prismlauncher.PrismLauncher"
      "org.videolan.VLC"
      "org.inkscape.Inkscape"
      "com.rustdesk.RustDesk"
      "org.rncbc.qpwgraph"
      #"org.libreoffice.LibreOffice"

      # runtime dependencies
      "com.github.Matoking.protontricks"
      "runtime/org.freedesktop.Platform.VulkanLayer.lsfgvk/x86_64/25.08"

      #{ flatpakref = "<uri>"; sha256="<hash>"; }
      #{ appId = "APP_ID"; origin = "flathub";  commit=<hash>; }
    ];
    overrides = {
      global = {
        # Force Wayland by default
        # Context.sockets = [
        #   "wayland"
        #   "!x11"
        #   "!fallback-x11"
        # ];

        Environment = {
          XCURSOR_THEME = "breeze_cursors";
        };
      };
    };
  };
}
