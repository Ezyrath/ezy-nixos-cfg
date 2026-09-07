{
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.services.k0s;
in {
  config = lib.mkIf cfg.enable {
    networking = {
      # Firewall configuration via nftables
      nftables.ruleset = mkAfter (
        let
          # Helper to simplify string interpolation
          accept = ports: "add rule inet filter input tcp dport { ${ports} } accept";
          acceptUdp = ports: "add rule inet filter input udp dport { ${ports} } accept";

          # Determine API port from config or default to 6443
          apiPort =
            if (cfg.config ? spec && cfg.config.spec ? api && cfg.config.spec.api ? port)
            then toString cfg.config.spec.api.port
            else "6443";
        in ''
          # 0. Allow VRRP (Keepalived)
          add rule inet filter input meta l4proto vrrp accept

          # --- k0s Firewall Rules ---

          # 1. Trust Cluster Nodes (Allow full communication between nodes)
          ${lib.concatStringsSep "\n" (
            lib.mapAttrsToList (_: ips: ''
              ${optionalString (ips.ipv6 != "") "add rule inet filter input ip6 saddr ${ips.ipv6} accept"}
            '')
            cfg.ha.nodes
          )}

          # 1.5 Trust Pods (Allow Pods to reach Layer 4 services on Host, e.g. Kubelet for Metrics)
          ${
            optionalString
            (cfg.config ? spec && cfg.config.spec ? network && cfg.config.spec.network ? podCIDR)
            (
              let
                cidr = cfg.config.spec.network.podCIDR;
              in "add rule inet filter input ip6 saddr ${cidr} accept"
            )
          }

          # 1.1 Allow Forwarding for Calico/Kubernetes Pods
          add rule inet filter forward iifname "cali*" accept
          add rule inet filter forward oifname "cali*" accept
          add rule inet filter forward iifname "tunl*" accept
          add rule inet filter forward oifname "tunl*" accept
          add rule inet filter forward iifname "vxlan.calico" accept
          add rule inet filter forward oifname "vxlan.calico" accept
          add rule inet filter forward iifname "wireguard.cali" accept
          add rule inet filter forward oifname "wireguard.cali" accept
          # Allow incoming traffic from physical interface to be forwarded (needed for MetalLB)
          add rule inet filter forward iifname "${cfg.ha.vipInterface}" accept

          # 2. Public Access Rules (For external clients / Load Balancers)

          # Kubernetes API (Controller) - Access from world (or restricted via external firewall)
          ${optionalString (cfg.role != "worker") ''
            ${accept apiPort}  # Kubernetes API (Configured or Default 6443)
            ${accept "9443"}   # k0s controller join API
          ''}

          # NodePorts (Worker) - Access from world for Services
          ${optionalString (cfg.role != "controller") ''
            add rule inet filter input tcp dport 30000-32767 accept
            add rule inet filter input udp dport 30000-32767 accept
          ''}

          # --- Extra Public Ports ---
          ${optionalString (cfg.network.extraTCPPublicPorts != []) ''
            ${accept (concatStringsSep ", " cfg.network.extraTCPPublicPorts)}
          ''}
          ${optionalString (cfg.network.extraUDPPublicPorts != []) ''
            ${acceptUdp (concatStringsSep ", " cfg.network.extraUDPPublicPorts)}
          ''}

          # --- NAT / Masquerade ---
          ${optionalString (cfg.network.ipv6 != null) ''
            table ip nat {
              chain postrouting {
                type nat hook postrouting priority 100; policy accept;
                oifname "${
              if (cfg.ha ? publicInterface && cfg.ha.publicInterface != "")
              then cfg.ha.publicInterface
              else cfg.ha.vipInterface
            }" masquerade
              }
            }
          ''}
        ''
      );

      # Configure IP addresses of the host
      networkmanager.unmanaged = [
        "interface-name:${cfg.ha.vipInterface}"
        "interface-name:cali*"
        "interface-name:tunl*"
        "interface-name:vxlan.calico"
        "interface-name:wireguard.cali"
      ];

      interfaces.${cfg.ha.vipInterface} = {
        useDHCP = false;
        ipv6.addresses = [
          {
            address = head (splitString "/" cfg.network.ipv6);
            prefixLength = toInt (last (splitString "/" cfg.network.ipv6));
          }
        ];
      };
    };
  };
}
