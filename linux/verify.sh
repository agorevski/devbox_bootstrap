#!/usr/bin/env bash
# Read-only report of what bootstrap.sh installed. Never changes the system.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() {
  cat <<EOF
Usage: ./linux/verify.sh [-h]

Reports which devbox tools are installed. Read-only and non-fatal.
Exit status is 0 when all REQUIRED checks pass, 1 otherwise.
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  "") ;;
  *) usage >&2; exit 2 ;;
esac

REQUIRED_MISSING=0

# run_check REQUIRED(0|1) LABEL CMD [ARGS...]: first line of CMD's stdout is shown as the version.
run_check() {
  local required="$1" label="$2" out rc=0
  shift 2
  out="$("$@" 2>/dev/null)" || rc=$?
  out="${out%%$'\n'*}"
  if (( rc == 0 )); then
    printf '  ok       %-16s %s\n' "$label" "${out:-installed}"
  else
    printf '  MISSING  %-16s %s\n' "$label" "${out:-not installed}"
    if (( required )); then REQUIRED_MISSING=$((REQUIRED_MISSING + 1)); fi
  fi
}
check()   { run_check 0 "$@"; }
require() { run_check 1 "$@"; }

ubuntu_release() { echo "Ubuntu $UBUNTU_VERSION_ID ($UBUNTU_CODENAME)"; }

has_nvidia_gpu() {
  if have lspci; then
    [[ -n "$(lspci | grep -i nvidia)" ]]
  else
    [[ -d /proc/driver/nvidia ]] || have nvidia-smi
  fi
}

nvidia_status() {
  local out count driver
  out="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader)" || return 1
  count="$(printf '%s\n' "$out" | grep -c .)"
  driver="$(printf '%s\n' "$out" | head -n1 | tr -d ' ')"
  echo "driver $driver, $count GPU(s)"
}

cuda_version() {
  local nvcc
  nvcc="$(command -v nvcc 2>/dev/null || true)"
  [[ -n "$nvcc" ]] || nvcc=/usr/local/cuda/bin/nvcc
  [[ -x "$nvcc" ]] || return 1
  "$nvcc" --version | sed -n 's/.*release \([0-9.]*\).*/CUDA \1/p'
}

gh_version() {
  gh --version | head -n1
}

gh_alias_co() {
  gh alias list 2>/dev/null | grep -q '^co:' || return 1
  echo "alias 'co' set"
}

git_status() {
  local v
  v="$(git --version)" || return 1
  if ! git config --global user.name >/dev/null 2>&1; then
    echo "$v (user.name not set)"
    return 1
  fi
  echo "$v (user.name set)"
}

zsh_default() {
  local shell
  shell="$(getent passwd "${USER:-$(id -un)}" | cut -d: -f7)"
  if [[ "$shell" == /usr/bin/zsh || "$shell" == /bin/zsh ]]; then
    echo "login shell $shell"
  else
    echo "login shell is ${shell:-unknown}"
    return 1
  fi
}

zshrc_linked() {
  [[ -L "$HOME/.zshrc" ]] || return 1
  local target
  target="$(readlink -f "$HOME/.zshrc")"
  [[ "$target" == "$DEVBOX_REPO_DIR"/* ]] || return 1
  echo "-> ${target#"$DEVBOX_REPO_DIR"/}"
}

docker_status() {
  local v
  v="$(docker --version)" || return 1
  if ! id -nG | tr ' ' '\n' | grep -qx docker; then
    echo "$v (user not in docker group; log out and back in)"
    return 1
  fi
  echo "$v"
}

conda_version() {
  "$HOME/miniconda3/bin/conda" --version
}

snap_version() {
  snap list "$1" 2>/dev/null | awk -v n="$1" '$1 == n {print $2; found=1} END {exit !found}'
}

java_version() {
  java -version 2>&1
}

ollama_version() {
  ollama --version
}

tailscale_version() {
  tailscale version
}

dotnet_version() {
  dotnet --version | sed 's/^/.NET SDK /'
}

detect_ubuntu
printf 'devbox verify: %s\n\n' "$(ubuntu_release)"

echo "Required"
require "git" git_status
require "gh" gh_version
require "gh alias co" gh_alias_co
require "node" node --version
require "npm" npm --version
require "claude" claude --version
require "copilot" copilot --version
require "opencode" opencode --version
require "zsh default" zsh_default
require "docker" docker_status
if has_nvidia_gpu; then
  require "nvidia-smi" nvidia_status
else
  echo "  skip     nvidia-smi        no NVIDIA GPU detected"
fi

echo
echo "Informational"
if has_nvidia_gpu; then check "cuda" cuda_version; fi
check "uv" uv --version
check "rustc" rustc --version
check "cargo" cargo --version
check "python3" python3 --version
if [[ -x "$HOME/miniconda3/bin/conda" ]]; then
  check "conda" conda_version
else
  echo "  skip     conda             ~/miniconda3 not present"
fi
check "docker compose" docker compose version
check "zshrc symlink" zshrc_linked
check "ollama" ollama_version
check "tailscale" tailscale_version
check "code (snap)" snap_version code
check "dotnet" dotnet_version
check "java" java_version

echo
if (( REQUIRED_MISSING == 0 )); then
  ok "all required checks passed"
  exit 0
fi
printf '%s\n' "$REQUIRED_MISSING required check(s) missing; re-run ./linux/bootstrap.sh or see the readme" >&2
exit 1
