tailscaleon() {
  sudo tailscale up "$@"
}

tailscaleoff() {
  sudo tailscale down
}
