_: {
  networking = {
    #extraHosts =
    #''
    #  127.0.0.1 modules-cdn.eac-prod.on.epicgames.com #Star Citizen EAC workaround
    #'';

    # For dnscrypt
    nameservers = [
      "127.0.0.1"
      "::1"
    ];

    # If using dhcpcd:
    dhcpcd.extraConfig = "nohook resolv.conf";

    # If using NetworkManager:
    networkmanager = {
      enable = true;
      dns = "none";
    };
  };

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # use DNS with dnscrypt
  services.dnscrypt-proxy = {
    enable = true;
    settings = {
      ipv4_servers = true;
      ipv6_servers = true;

      dnscrypt_servers = true;
      odoh_servers = false;
      doh_servers = true;

      require_dnssec = true;
      require_nolog = true;
      require_nofilter = true;

      # listening (actually only local)
      listen_addresses = [
        "127.0.0.1:53"
        "[::1]:53"
      ];

      # server dns for first query (get public-resolver)
      bootstrap_resolvers = [
        "195.10.195.195:53"
        "94.16.114.254:53"
        "[2a03:4000:28:365::1]:53"
        "[2a03:4000:4d:c92:88c0:96ff:fec6:b9d]:53"
      ];
      #netprobe_address = [ "195.10.195.195:53" "[2a03:4000:28:365::1]:53" ];
      ignore_system_dns = true;

      # use cache for latency
      cache = true;
      cache_size = 4096;
      cache_min_ttl = 2400;
      cache_max_ttl = 86400;
      cache_neg_min_ttl = 60;
      cache_neg_max_ttl = 600;

      sources.public-resolvers = {
        urls = [
          "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md"
          "https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md"
        ];
        cache_file = "/var/lib/dnscrypt-proxy/public-resolvers.md";
        minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3"; # gitleaks:allow
        refresh_delay = 72;
      };

      sources.relays = {
        urls = [
          "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/relays.md"
          "https://download.dnscrypt.info/resolvers-list/v3/relays.md"
        ];
        cache_file = "/var/lib/dnscrypt-proxy/relays.md";
        minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3"; # gitleaks:allow
        refresh_delay = 72;
      };

      # You can choose a specific set of servers from https://github.com/DNSCrypt/dnscrypt-resolvers/blob/master/v3/public-resolvers.md
      # server_names = [ ... ];
    };
  };

  systemd.services.dnscrypt-proxy.serviceConfig = {
    StateDirectory = "dnscrypt-proxy";
  };
}
