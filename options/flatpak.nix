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
      "com.valvesoftware.Steam"
      "org.prismlauncher.PrismLauncher"
      "dev.vencord.Vesktop"
      "com.rustdesk.RustDesk"
      "io.edcd.EDMarketConnector"

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
