{pkgs, ...}: let
  rocms = with pkgs.rocmPackages; [
    rocm-smi
    rocblas
    hipblas
    clr
  ];
in {
  # ROCm support
  systemd.tmpfiles.rules = let
    rocmEnv = pkgs.symlinkJoin {
      name = "rocm-combined";
      paths = rocms;
    };
  in [
    "L+    /opt/rocm   -    -    -     -    ${rocmEnv}"
  ];

  environment.systemPackages = rocms;
}
