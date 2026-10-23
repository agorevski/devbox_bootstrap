#!/usr/bin/env bash
# Interactive restore for a fresh Ubuntu LTS machine. Run as your normal user; sudo is requested when needed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

MODULES=(system devtools shell)
ONLY=()
SKIP=()
RAN=()
DECLINED=()

usage() {
  cat <<EOF
Usage: ./linux/bootstrap.sh [options]

Interactive restore for a fresh Ubuntu 22.04/24.04 machine. Asks before each module.

Options:
  -y, --yes           Answer yes to every prompt (defaults are used)
  -n, --dry-run       Print the actions without changing the system
      --only MODS     Run only these modules (comma list, repeatable)
      --skip MODS     Skip these modules (comma list, repeatable)
  -h, --help          Show this help

Modules (run in this order):
  system     apt packages, NVIDIA driver, snaps, repos
  devtools   Node, Python, Rust, Docker, Claude Code, Copilot CLI, opencode, gh, Ollama
  shell      zsh, bash, git, gh config, ssh
EOF
}

is_module() {
  local m
  for m in "${MODULES[@]}"; do [[ "$m" == "$1" ]] && return 0; done
  return 1
}

# add_modules ARRAY_NAME "a,b,c": validates each name and appends it to ARRAY_NAME.
add_modules() {
  local -n _target="$1"
  local list="$2" m
  local -a parts
  IFS=, read -r -a parts <<<"$list"
  for m in "${parts[@]}"; do
    [[ -n "$m" ]] || continue
    is_module "$m" || die "unknown module '$m' (valid: ${MODULES[*]})"
    _target+=("$m")
  done
}

describe() {
  case "$1" in
    system) echo "apt packages, NVIDIA driver, snaps, repos" ;;
    devtools) echo "Node, Python, Rust, Docker, Claude Code, Copilot CLI, opencode, gh, Ollama" ;;
    shell) echo "zsh, bash, git, gh config, ssh" ;;
  esac
}

is_selected() {
  local m="$1" s found=0
  if (( ${#ONLY[@]} )); then
    for s in "${ONLY[@]}"; do [[ "$s" == "$m" ]] && found=1; done
    (( found )) || return 1
  fi
  for s in "${SKIP[@]}"; do [[ "$s" == "$m" ]] && return 1; done
  return 0
}

while (( $# )); do
  case "$1" in
    -y|--yes) DEVBOX_ASSUME_YES=1 ;;
    -n|--dry-run) DEVBOX_DRY_RUN=1 ;;
    --only|--skip)
      [[ $# -ge 2 ]] || die "$1 requires a module list (see --help)"
      if [[ "$1" == "--only" ]]; then add_modules ONLY "$2"; else add_modules SKIP "$2"; fi
      shift
      ;;
    --only=*) add_modules ONLY "${1#*=}" ;;
    --skip=*) add_modules SKIP "${1#*=}" ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1 (see --help)" ;;
  esac
  shift
done
export DEVBOX_ASSUME_YES DEVBOX_DRY_RUN

if [[ $EUID -eq 0 ]]; then
  die "Run as your normal user; sudo is requested when needed"
fi

detect_ubuntu
log "Detected Ubuntu $UBUNTU_VERSION_ID ($UBUNTU_CODENAME)"
case "$UBUNTU_VERSION_ID" in
  22.04|24.04) ;;
  *) warn "Tested on Ubuntu 22.04 and 24.04; continuing on $UBUNTU_VERSION_ID" ;;
esac

MODULE_FILES=(10-system 20-devtools 30-shell)
for base in "${MODULE_FILES[@]}"; do
  file="$DEVBOX_LINUX_DIR/modules/$base.sh"
  [[ -f "$file" ]] || die "missing module file: linux/modules/$base.sh"
  # shellcheck source=/dev/null
  source "$file"
done
for m in "${MODULES[@]}"; do
  declare -F "module_$m" >/dev/null || die "linux/modules does not define module_$m"
done

if [[ "$DEVBOX_DRY_RUN" != "1" ]]; then
  have sudo || die "sudo is required"
  log "Requesting sudo up-front"
  sudo -v || die "sudo authentication failed"
else
  warn "dry-run: no changes will be made"
fi

for m in "${MODULES[@]}"; do
  if ! is_selected "$m"; then
    log "Skipping $m module (excluded by flags)"
    continue
  fi
  if ask_yn "Run the $m module ($(describe "$m"))?" y; then
    log "Running $m module"
    if ! "module_$m"; then
      die "module '$m' failed; fix the error above and re-run (modules are idempotent)"
    fi
    RAN+=("$m")
  else
    DECLINED+=("$m")
  fi
done

log "Summary"
ok "modules run: ${RAN[*]:-none}"
[[ ${#DECLINED[@]} -gt 0 ]] && warn "modules declined: ${DECLINED[*]}"
if [[ "${NEEDS_REBOOT:-0}" == "1" ]]; then
  warn "Reboot required to finish installing the NVIDIA driver/kernel changes"
fi
log "Log out and back in so docker group membership and the login shell take effect"
log "Verify the result with: ./linux/verify.sh"
if [[ "$DEVBOX_DRY_RUN" == "1" ]]; then
  log "Dry run complete; nothing was changed"
fi
