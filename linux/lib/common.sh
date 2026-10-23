# shellcheck shell=bash
# Shared helpers for devbox_bootstrap Linux scripts. Source, do not execute.
# Requires bash >= 4. Works on any Ubuntu LTS release (22.04, 24.04, ...).

set -o pipefail

DEVBOX_LINUX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC2034 # consumed by modules that source this file
DEVBOX_REPO_DIR="$(cd "$DEVBOX_LINUX_DIR/.." && pwd)"
DEVBOX_STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/devbox"
DEVBOX_SECRETS_FILE="$DEVBOX_STATE_DIR/secrets.env"
DEVBOX_ASSUME_YES="${DEVBOX_ASSUME_YES:-0}"
DEVBOX_DRY_RUN="${DEVBOX_DRY_RUN:-0}"

if [[ -t 1 ]]; then
  C_BLUE=$'\033[1;34m'; C_GREEN=$'\033[1;32m'; C_YELLOW=$'\033[1;33m'; C_RED=$'\033[1;31m'; C_OFF=$'\033[0m'
else
  C_BLUE=''; C_GREEN=''; C_YELLOW=''; C_RED=''; C_OFF=''
fi

log()  { printf '%s==>%s %s\n' "$C_BLUE" "$C_OFF" "$*"; }
ok()   { printf '%s ok%s  %s\n' "$C_GREEN" "$C_OFF" "$*"; }
warn() { printf '%swarn%s  %s\n' "$C_YELLOW" "$C_OFF" "$*" >&2; }
die()  { printf '%serror%s %s\n' "$C_RED" "$C_OFF" "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

# Run a command, or only print it when DEVBOX_DRY_RUN=1.
run() {
  if [[ "$DEVBOX_DRY_RUN" == "1" ]]; then
    printf '  [dry-run] %s\n' "$*"
    return 0
  fi
  "$@"
}

# Run as root: prefixes sudo when not already root.
as_root() {
  if [[ $EUID -eq 0 ]]; then run "$@"; else run sudo "$@"; fi
}

# ask_yn "Question" [default: y|n]. Honors DEVBOX_ASSUME_YES=1.
ask_yn() {
  local prompt="$1" default="${2:-n}" reply hint
  if [[ "$default" == "y" ]]; then hint="[Y/n]"; else hint="[y/N]"; fi
  if [[ "$DEVBOX_ASSUME_YES" == "1" ]]; then
    [[ "$default" == "y" ]]
    return
  fi
  read -r -p "$prompt $hint " reply </dev/tty || reply=""
  reply="${reply:-$default}"
  [[ "$reply" =~ ^[Yy]$ ]]
}

# ask_value "Prompt" "default" -> echoes the answer.
ask_value() {
  local prompt="$1" default="${2:-}" reply
  if [[ "$DEVBOX_ASSUME_YES" == "1" ]]; then
    printf '%s\n' "$default"
    return 0
  fi
  if [[ -n "$default" ]]; then
    read -r -p "$prompt [$default]: " reply </dev/tty || reply=""
  else
    read -r -p "$prompt: " reply </dev/tty || reply=""
  fi
  printf '%s\n' "${reply:-$default}"
}

# Sets UBUNTU_CODENAME, UBUNTU_VERSION_ID (e.g. 24.04) and UBUNTU_VERSION_NODOT (e.g. 2404).
detect_ubuntu() {
  [[ -r /etc/os-release ]] || die "Cannot read /etc/os-release"
  # shellcheck disable=SC1091
  . /etc/os-release
  [[ "${ID:-}" == "ubuntu" || "${ID_LIKE:-}" == *ubuntu* ]] || die "This script supports Ubuntu only (found ${ID:-unknown})"
  UBUNTU_CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
  UBUNTU_VERSION_ID="${VERSION_ID}"
  UBUNTU_VERSION_NODOT="${VERSION_ID//./}"
  [[ -n "$UBUNTU_CODENAME" ]] || die "Could not determine Ubuntu codename"
  export UBUNTU_CODENAME UBUNTU_VERSION_ID UBUNTU_VERSION_NODOT
}

# Install apt packages that are not yet installed. Skips packages with no candidate on this release.
apt_install() {
  local pkgs=() p
  for p in "$@"; do
    if dpkg -s "$p" >/dev/null 2>&1; then continue; fi
    if apt-cache policy "$p" 2>/dev/null | grep -q 'Candidate: (none)'; then
      warn "apt package not available on this release, skipping: $p"
      continue
    fi
    pkgs+=("$p")
  done
  if (( ${#pkgs[@]} )); then
    log "apt install: ${pkgs[*]}"
    as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}"
  else
    ok "apt packages already present: $*"
  fi
}

# Add a third-party apt repo with a dearmored key (idempotent).
# usage: add_apt_repo NAME KEY_URL REPO_LINE
add_apt_repo() {
  local name="$1" key_url="$2" repo_line="$3"
  local keyring="/usr/share/keyrings/${name}.gpg"
  local list="/etc/apt/sources.list.d/${name}.list"
  if [[ -f "$list" ]]; then ok "apt repo already configured: $name"; return 0; fi
  apt_install ca-certificates curl gnupg
  log "adding apt repo: $name"
  if [[ "$DEVBOX_DRY_RUN" == "1" ]]; then
    printf '  [dry-run] add %s to %s\n' "$repo_line" "$list"
    return 0
  fi
  local tmpkey
  tmpkey="$(mktemp)"
  curl -fsSL "$key_url" -o "$tmpkey" || die "failed to fetch key for $name"
  if grep -q 'BEGIN PGP' "$tmpkey"; then
    sudo gpg --dearmor -o "$keyring" --yes "$tmpkey" || die "failed to dearmor key for $name"
  else
    sudo install -m 0644 "$tmpkey" "$keyring"
  fi
  rm -f "$tmpkey"
  printf '%s\n' "$repo_line" | sudo tee "$list" >/dev/null
  as_root env DEBIAN_FRONTEND=noninteractive apt-get update -y
}

# Ensure a line exists in a file (idempotent). usage: ensure_line FILE LINE
ensure_line() {
  local file="$1" line="$2"
  if [[ -f "$file" ]] && grep -qxF "$line" "$file"; then return 0; fi
  if [[ "$DEVBOX_DRY_RUN" == "1" ]]; then printf '  [dry-run] append to %s: %s\n' "$file" "$line"; return 0; fi
  mkdir -p "$(dirname "$file")"
  printf '%s\n' "$line" >>"$file"
}

# Write or replace a managed block in FILE. Block body is read from stdin.
# usage: ensure_block FILE BLOCK_NAME < body
ensure_block() {
  local file="$1" name="$2" begin end content tmp
  begin="# >>> devbox ${name} >>>"
  end="# <<< devbox ${name} <<<"
  content="$(cat)"
  if [[ "$DEVBOX_DRY_RUN" == "1" ]]; then printf '  [dry-run] manage block %s in %s\n' "$name" "$file"; return 0; fi
  mkdir -p "$(dirname "$file")"
  touch "$file"
  tmp="$(mktemp)"
  awk -v b="$begin" -v e="$end" '
    $0 == b {skip=1; next}
    $0 == e {skip=0; next}
    !skip {print}
  ' "$file" >"$tmp"
  {
    cat "$tmp"
    printf '\n%s\n%s\n%s\n' "$begin" "$content" "$end"
  } >"$file.devbox.tmp" && mv "$file.devbox.tmp" "$file"
  rm -f "$tmp"
}

# Secrets live in $DEVBOX_SECRETS_FILE (mode 600), never in the repo.
secret_get() {
  local key="$1"
  [[ -f "$DEVBOX_SECRETS_FILE" ]] || return 1
  grep -E "^${key}=" "$DEVBOX_SECRETS_FILE" | tail -n1 | cut -d= -f2-
}

secret_set() {
  local key="$1" value="$2" tmp
  if [[ "$DEVBOX_DRY_RUN" == "1" ]]; then printf '  [dry-run] store secret %s\n' "$key"; return 0; fi
  mkdir -p "$DEVBOX_STATE_DIR"
  chmod 700 "$DEVBOX_STATE_DIR"
  touch "$DEVBOX_SECRETS_FILE"
  chmod 600 "$DEVBOX_SECRETS_FILE"
  tmp="$(mktemp)"
  grep -vE "^${key}=" "$DEVBOX_SECRETS_FILE" >"$tmp" || true
  printf '%s=%s\n' "$key" "$value" >>"$tmp"
  mv "$tmp" "$DEVBOX_SECRETS_FILE"
  chmod 600 "$DEVBOX_SECRETS_FILE"
}
