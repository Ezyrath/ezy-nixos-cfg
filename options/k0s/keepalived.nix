{
  lib,
  config,
  ...
}: let
  cfg = config.services.k0s;
in {
  config = lib.mkIf cfg.enable {
    # Enable and configure keepalived for VIP management
    services.keepalived = {
      enable = true;
      openFirewall = true;

      extraGlobalDefs = ''
        router_id ${config.networking.hostName}

        #Email notification settings (optional)
        #notification_email {
        #  acassen@firewall.loc
        #  failover@firewall.loc
        #  sysadmin@firewall.loc
        #}
        #notification_email_from Alexandre.Cassen@firewall.loc
        #smtp_server 192.168.200.1
        #smtp_connect_timeout 30
      '';

      extraConfig = ''
        include ${config.sops.templates."keepalived-vrrp.conf".path}
      '';
    };

    # Define sops template for keepalived VRRP config
    sops.templates."keepalived-vrrp.conf" = {
      content = ''
        vrrp_sync_group VG_1 {
          group {
            VI_6
          }
        }

        vrrp_instance VI_6 {
          state MASTER
          interface ${cfg.ha.vipInterface}
          virtual_router_id 52
          priority 100
          advert_int 1
          authentication {
            auth_type PASS
            auth_pass ${config.sops.placeholder.k0s_keepalived_pass}
          }
          virtual_ipaddress {
            ${cfg.ha.vipv6}
          }
        }
      '';
    };
  };
}
