# ezy-nixos-cfg

[![built with nix](https://builtwithnix.org/badge.svg)](https://builtwithnix.org)
[![CI](https://github.com/Ezyrath/ezy-nixos-cfg/actions/workflows/ci.yml/badge.svg)](https://github.com/Ezyrath/ezy-nixos-cfg/actions/workflows/ci.yml)
[![Deps Update](https://github.com/Ezyrath/ezy-nixos-cfg/actions/workflows/flake-update.yml/badge.svg)](https://github.com/Ezyrath/ezy-nixos-cfg/actions/workflows/flake-update.yml)

Declarative, reproducible NixOS configurations for workstations and servers.

---

## 🖥️ System Architecture

Each system is built using the declarative [`makeSystem`](./lib/makeSystem.nix) generator, combining:

* **Filesystem & State**: Ephemeral root on `tmpfs`, Btrfs subvolumes on LUKS encryption via [Disko](./disk), and persistent state with [Impermanence](https://github.com/nix-community/impermanence) (`/persist`).
* **Secrets Management**: Runtime decryption via [sops-nix](https://github.com/Mic92/sops-nix) using Age keys.
* **Security & Network**: Strict `nftables` rulesets, `fail2ban` intrusion prevention, and local encrypted DNS with DNSCrypt-proxy.
* **Desktop & Apps**: KDE Plasma 6 managed via [plasma-manager](https://github.com/nix-community/plasma-manager), Wayland by default, isolated Flatpaks, and virtual audio cables via PipeWire.
* **Clustering**: High-availability Kubernetes via [k0s](https://k0sproject.io) with Keepalived VRRP and HAProxy.

### Configured Hosts

| Hostname        | Type        | Disk Layout         | Boot / Security          | Highlights                                       |
|:----------------|:------------|:--------------------|:-------------------------|:-------------------------------------------------|
| **`ezy001wks`** | Workstation | NVMe (LUKS + Btrfs) | Lanzaboote (Secure Boot) | KDE Plasma 6, Flatpaks, PipeWire Virtual Cable   |
| **`ezy002wks`** | Workstation | NVMe (LUKS + Btrfs) | systemd-boot             | KDE Plasma 6, Flatpaks, NVIDIA drivers           |
| **`ezy001srv`** | Server      | NVMe Dual RAID-1    | systemd-boot             | k0s Controller + Worker, Keepalived VIP, HAProxy |

---

## 📂 Repository Layout

```text
.
├── boot/             # Bootloader configurations (systemd-boot & Lanzaboote Secure Boot)
├── default/          # Base system configuration and local networking
├── disk/             # Disko storage partitioning layouts (NVMe, RAID-1, VM)
├── firewall/         # nftables firewall rules and fail2ban jails
├── home/             # Home Manager modules (desktop, dotfiles, audio)
├── lib/              # Modular makeSystem helper
├── options/          # Feature flags and service toggles
│   └── k0s/          # Kubernetes clustering, Keepalived, and HAProxy
├── flake.nix         # Flake inputs and host outputs
├── generate.sh       # Interactive provisioning wizard (Age key, SOPS, initrd key)
└── .pre-commit-config.yaml # Pre-commit linters (Alejandra, Statix, Deadnix, MegaLinter)
```

---

## 🚀 Deployment

### 1. Provision Secrets & Hardware Configuration

Run the interactive setup wizard [`generate.sh`](./generate.sh) to generate the required Age keys, initialize `.sops.yaml`, encrypt host secrets, and generate the initrd SSH recovery key:

```bash
./generate.sh
```

### 2. Deploy via NixOS-Anywhere

Deploy to target hardware over SSH with automatic partitioning and hardware fact detection:

```bash
nixos-anywhere \
  --flake .#<HOSTNAME> \
  --generate-hardware-config nixos-facter ./facter.json \
  --extra-files ./deploy \
  --target-host root@<TARGET_IP>
```

---

## 🔐 Secrets Management (SOPS & Age)

Secrets are encrypted with [SOPS](https://github.com/getsops/sops) and decrypted at boot time by `sops-nix`:

### Manual Key Generation

```bash
mkdir -p deploy/persist/var/lib/sops
age-keygen > deploy/persist/var/lib/sops/key.age
chmod 0400 deploy/persist/var/lib/sops/key.age
```

### Creating & Editing Secrets

```bash
export SOPS_AGE_KEY_FILE="$(pwd)/deploy/persist/var/lib/sops/key.age"

# Create a new encrypted file for a host type
sops secrets/workstation.yaml
sops secrets/server.yaml
```

---

## 🛡️ Secure Boot Setup (Lanzaboote)

For hosts using Secure Boot (`boot = ./boot/secure-boot.nix`):

```bash
# Connect to the deployed machine
ssh -A user@<HOST_IP>

# Initialize sbctl keys
sudo sbctl create-keys
sudo sbctl setup --migrate
sudo reboot

# Verify status
sudo sbctl verify
sudo reboot

# In UEFI firmware: restore factory keys & enable Secure Boot
# Then enroll keys with Microsoft certificates:
sudo sbctl enroll-keys --microsoft
sudo reboot

# Confirm active Secure Boot
bootctl status
```

---

## 🔄 Maintenance & Updates

### Rebuilding System

```bash
cd /etc/nixos
git pull
sudo nixos-rebuild switch --impure
```

### Updating Flake Dependencies

```bash
nix flake update
git add flake.lock
git commit -m "chore(deps): update flake dependencies"
git push
```

*(Weekly automated PRs are also submitted automatically by GitHub Actions).*

### Nix Store Garbage Collection

```bash
# Delete older generations
sudo nix-env --delete-generations +3 --profile /nix/var/nix/profiles/system

# Collect garbage and optimise store
sudo nix-collect-garbage -d
sudo nix-store --optimise -v
```

---

## ☸️ k0s Cluster Operations

### Retrieve Kubeconfig

```bash
sudo k0s kubeconfig admin > ~/.kube/config
chmod 0600 ~/.kube/config
```

### Cluster Verification

```bash
kubectl get nodes -o wide
kubectl get pods -A
```

### Resetting Node

```bash
sudo systemctl stop k0s
sudo k0s reset
sudo rm -rf /var/lib/k0s /etc/k0s /var/lib/kubelet /etc/cni/net.d
sudo reboot
```
