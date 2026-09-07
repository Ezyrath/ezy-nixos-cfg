_: {
  networking = {
    nftables.enable = true;
    firewall.enable = false;

    nftables.ruleset = ''
      flush ruleset

      table inet filter {
        chain input {
          type filter hook input priority 0; policy drop;

          iifname "lo" accept
          iifname "virbr0" accept

          icmp type echo-request limit rate 5/second burst 10 packets accept
          icmpv6 type echo-request limit rate 5/second burst 10 packets accept
          icmpv6 type { nd-neighbor-solicit, nd-neighbor-advert, nd-router-advert } accept

          tcp dport 22 accept

          ct state established,related accept
        }

        chain forward {
          type filter hook forward priority 0; policy drop;

          iifname "virbr0" accept

          ct state established,related accept
        }
      }
    '';
  };

  services.fail2ban = {
    enable = true;
    maxretry = 3;
    bantime = "24h"; # Ban IPs for one day on the first ban
    bantime-increment = {
      enable = true; # Enable increment of bantime after each violation
      multipliers = "1 2 4 8 16 32 64";
      maxtime = "168h"; # Do not ban for more than 1 week
      overalljails = true; # Calculate the bantime based on all the violations
    };
    # Fail2Ban integration with nftables
    banaction = "nftables-multiport";
    banaction-allports = "nftables-allports";
    jails = {
      sshd = {
        settings = {
          backend = "systemd";
          mode = "aggressive";
        };
      };
    };
  };
}
