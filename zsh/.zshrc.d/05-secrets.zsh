# Load machine-local secrets written by devbox (never stored in the repo).
if [[ -f "$HOME/.config/devbox/secrets.env" ]]; then
  set -a
  source "$HOME/.config/devbox/secrets.env"
  set +a
fi
