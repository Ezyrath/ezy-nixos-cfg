{
  lib,
  config,
  ...
}: let
  cfg = config.services.k0s;
in {
  config = lib.mkIf cfg.enable {
    # --- SOPS Secrets Configuration ---
    sops.secrets = {
      k0s_keepalived_pass = {};
      k0s_join_token = {};
    };
  };
}
