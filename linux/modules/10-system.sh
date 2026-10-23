# shellcheck shell=bash
# shellcheck source=../lib/common.sh
# System-level restore module: apt packages, third-party repos, snaps, NVIDIA/CUDA.
# Source this file after lib/common.sh. Defines functions only; nothing runs on source.

NEEDS_REBOOT=0

_system_pkg_installed() {
  dpkg-query -W -f='${db:Status-Status}\n' "$1" 2>/dev/null | grep -qx installed
}

_system_apt_update() {
  as_root env DEBIAN_FRONTEND=noninteractive apt-get update -y
}

_system_base() {
  log "installing base packages"
  apt_install build-essential git curl wget gnupg ca-certificates apt-transport-https \
    software-properties-common zsh tmux htop btop jq ripgrep fzf unzip pipx python3 python3-pip
}

_system_dev_libs() {
  apt_install cmake ninja-build pkg-config libssl-dev libudev-dev libicu-dev dkms \
    opencl-headers ocl-icd-opencl-dev libvulkan-dev vulkan-tools mesa-common-dev \
    libglu1-mesa-dev libasound2-dev libgtk-3-dev libsdl2-dev libx11-dev libxi-dev \
    libxrandr-dev libxinerama-dev libxcursor-dev libxext-dev libxfixes-dev libpulse-dev \
    dos2unix yq nvtop ffmpeg
}

_system_desktop_apps() {
  apt_install xrdp xvfb sshfs ffmpeg fonts-liberation fonts-noto-color-emoji \
    fonts-wqy-zenhei fonts-unifont
  if have systemctl && _system_pkg_installed xrdp; then
    as_root systemctl enable --now xrdp
  fi

  if _system_pkg_installed google-chrome-stable; then
    ok "google-chrome-stable already installed"
    return 0
  fi
  if [[ -f /etc/apt/sources.list.d/google-chrome.sources ]]; then
    log "google-chrome apt source already configured (deb822)"
  else
    add_apt_repo google-chrome \
      https://dl.google.com/linux/linux_signing_key.pub \
      'deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome-stable/ stable main'
  fi
  apt_install google-chrome-stable
}

_system_server_security() {
  apt_install openssh-server fail2ban ufw unattended-upgrades apparmor-utils
  if have systemctl; then
    as_root systemctl enable --now ssh
    as_root systemctl enable --now fail2ban
    as_root systemctl enable --now unattended-upgrades
    # ufw is intentionally not enabled here: enabling it without SSH rules can lock you out.
    warn "ufw installed but not enabled; run 'sudo ufw allow OpenSSH && sudo ufw enable' after review"
  fi

  if _system_pkg_installed tailscale; then
    ok "tailscale already installed"
  else
    add_apt_repo tailscale \
      "https://pkgs.tailscale.com/stable/ubuntu/${UBUNTU_CODENAME}.noarmor.gpg" \
      "deb [signed-by=/usr/share/keyrings/tailscale.gpg] https://pkgs.tailscale.com/stable/ubuntu ${UBUNTU_CODENAME} main"
    apt_install tailscale
  fi
  if have systemctl && _system_pkg_installed tailscale; then
    as_root systemctl enable --now tailscaled
  fi
}

_system_snap() {
  local name="$1"; shift
  if ! have snap; then
    warn "snap not available; skipping snap: $name"
    return 0
  fi
  if snap list "$name" >/dev/null 2>&1; then
    ok "snap already installed: $name"
    return 0
  fi
  log "snap install: $name $*"
  as_root snap install "$name" "$@"
}

_system_snaps() {
  _system_snap code --classic
  _system_snap astral-uv --classic
  _system_snap yq
}

_system_has_nvidia() {
  if ! have lspci; then apt_install pciutils; fi
  # Vendor ID 10de is NVIDIA. A command substitution avoids pipefail/SIGPIPE issues with grep -q.
  have lspci && [[ -n "$(lspci -d 10de: 2>/dev/null)" ]]
}

_system_nvidia_driver() {
  if dpkg-query -W -f='${db:Status-Status}\n' 'nvidia-driver-*' 2>/dev/null | grep -qx installed; then
    ok "NVIDIA driver already installed"
    return 0
  fi
  apt_install ubuntu-drivers-common
  log "installing NVIDIA driver via ubuntu-drivers"
  as_root env DEBIAN_FRONTEND=noninteractive ubuntu-drivers install
  NEEDS_REBOOT=1
}

_system_cuda() {
  if _system_pkg_installed cuda-toolkit-13-4; then
    ok "CUDA toolkit already installed"
    return 0
  fi
  if ! _system_pkg_installed cuda-keyring; then
    local keyring_url="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu${UBUNTU_VERSION_NODOT}/x86_64/cuda-keyring_1.1-1_all.deb"
    local deb="$DEVBOX_STATE_DIR/cuda-keyring_1.1-1_all.deb"
    if [[ "$DEVBOX_DRY_RUN" == "1" ]]; then
      printf '  [dry-run] curl -fsSL %s -o %s\n' "$keyring_url" "$deb"
      printf '  [dry-run] dpkg -i %s\n' "$deb"
    else
      mkdir -p "$DEVBOX_STATE_DIR"
      curl -fsSL "$keyring_url" -o "$deb" || die "failed to download CUDA keyring from $keyring_url"
      as_root dpkg -i "$deb"
    fi
  fi
  _system_apt_update
  apt_install cuda-toolkit-13-4
}

_system_gpu_mode() {
  if ! ask_yn "Set GPU mode to on-demand?" y; then return 0; fi
  apt_install nvidia-prime
  if ! have prime-select; then
    warn "prime-select not available; skipping GPU mode"
    return 0
  fi
  local mode
  mode="$(prime-select query 2>/dev/null || true)"
  if [[ "$mode" == "on-demand" ]]; then
    ok "GPU mode already on-demand"
  else
    as_root prime-select on-demand
  fi
}

_system_nvidia() {
  if ! _system_has_nvidia; then
    ok "no NVIDIA GPU detected; skipping NVIDIA setup"
    return 0
  fi
  log "NVIDIA GPU detected"
  if ask_yn "Install NVIDIA driver (recommended, proprietary)?" y; then
    _system_nvidia_driver
  fi
  if ask_yn "Install CUDA toolkit (13.4)?" y; then
    _system_cuda
  fi
  _system_gpu_mode
}

module_system() {
  detect_ubuntu
  log "Ubuntu ${UBUNTU_VERSION_ID} (${UBUNTU_CODENAME})"
  case "$UBUNTU_VERSION_ID" in
    22.04|24.04) ;;
    *) warn "Ubuntu ${UBUNTU_VERSION_ID} is not a tested LTS (22.04/24.04); continuing" ;;
  esac

  log "apt update"
  _system_apt_update
  if ask_yn "Run apt full-upgrade?" y; then
    as_root env DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y
  fi

  _system_base

  if ask_yn "Install dev libraries and tools?" y; then
    _system_dev_libs
  fi
  if ask_yn "Install desktop apps (xrdp, Chrome, fonts, ...)?" n; then
    _system_desktop_apps
  fi
  if ask_yn "Install server and security packages (ssh, fail2ban, ufw, tailscale)?" n; then
    _system_server_security
  fi
  if ask_yn "Install snap packages (VS Code, uv, yq)?" y; then
    _system_snaps
  fi
  _system_nvidia

  if [[ "$NEEDS_REBOOT" == "1" ]]; then
    warn "A new NVIDIA driver was installed. REBOOT REQUIRED before the GPU works."
  fi
  ok "system module finished"
}
