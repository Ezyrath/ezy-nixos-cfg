{
  lib,
  config,
  ...
}: let
  cfg = config.services.k0s;
in {
  config = lib.mkIf cfg.enable {
    # Enable and configure HAProxy for load balancing the Kubernetes API servers
    services.haproxy = {
      enable = true;

      config = ''
        global
          log /dev/log    local1 notice

        defaults
          log     global
          mode    tcp             # Use TCP for the Kubernetes API
          option  tcplog
          option  dontlognull
          timeout connect 5s
          timeout client  600s    # Long timeout for Kubernetes
          timeout server  600s

        frontend kubernetes-api
          bind [::]:6443 v4v6     # It listens ONLY on the VIP!
          mode tcp
          default_backend kube-masters

        backend kube-masters
          mode tcp
          balance roundrobin      # Distributes load evenly

          # Auto-generated from cfg.nodes
          ${lib.concatStringsSep "\n" (
          lib.mapAttrsToList (name: ips: ''
            ${
              if ips.ipv6 != ""
              then "server ${name}-v6 [${ips.ipv6}]:6442 check"
              else ""
            }
          '')
          cfg.ha.nodes
        )}
      '';
    };
  };
}
