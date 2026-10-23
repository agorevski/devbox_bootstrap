# shellcheck shell=bash
# shellcheck source=../lib/common.sh
# Shell, git, gh and SSH configuration. Source, then call module_shell.

_shell_bashrc_block() {
  cat <<'BASHRC_BLOCK'
# PATH entries, only for directories that exist.
[ -d "$HOME/.local/bin" ] && PATH="$HOME/.local/bin:$PATH"
[ -d "$HOME/.npm-global/bin" ] && PATH="$HOME/.npm-global/bin:$PATH"
[ -d "$HOME/bin" ] && PATH="$HOME/bin:$PATH"
[ -d "$HOME/.opencode/bin" ] && PATH="$HOME/.opencode/bin:$PATH"
export PATH

if [ -d /usr/local/cuda ]; then
  export CUDA_HOME=/usr/local/cuda
  export CUDACXX="$CUDA_HOME/bin/nvcc"
  export PATH="$CUDA_HOME/bin:$PATH"
fi

alias home='cd ~/GIT/agorevski'
BASHRC_BLOCK
}

_shell_login_shell() {
  local user="${USER:-$(id -un)}" current
  [[ -x /usr/bin/zsh ]] || { warn "/usr/bin/zsh missing; skipping login shell"; return 0; }
  current="$(getent passwd "$user" | cut -d: -f7)"
  if [[ "$current" == "/usr/bin/zsh" ]]; then ok "login shell already zsh"; return 0; fi
  ask_yn "Make zsh the login shell for $user?" y || { log "keeping login shell $current"; return 0; }
  if ! grep -qxF /usr/bin/zsh /etc/shells; then
    printf '%s\n' /usr/bin/zsh | as_root tee -a /etc/shells >/dev/null
  fi
  if [[ $EUID -eq 0 ]]; then
    as_root chsh -s /usr/bin/zsh "$user"
  else
    run chsh -s /usr/bin/zsh "$user"
  fi
}

_shell_zsh_deploy() {
  local ts file target
  ask_yn "Deploy zsh config from the repo (symlinks)?" y || { log "skipping zsh deploy"; return 0; }
  ts="$(date +%Y%m%d-%H%M%S)"
  for file in "$HOME/.zshrc" "$HOME/.zshrc.d"; do
    if [[ -e "$file" && ! -L "$file" ]]; then
      log "backing up $file to $file.devbox-bak-$ts"
      run mv "$file" "$file.devbox-bak-$ts"
    fi
  done
  # Symlinks into the repo: edits in zsh/ take effect immediately.
  target="$DEVBOX_REPO_DIR/zsh"
  run ln -sfn "$target/.zshrc" "$HOME/.zshrc"
  run ln -sfn "$target/.zshrc.d" "$HOME/.zshrc.d"
  ok "zsh config linked from $target"
}

_shell_bash() {
  if [[ -f "$HOME/miniconda3/bin/conda" ]]; then
    if grep -q '>>> conda initialize >>>' "$HOME/.bashrc" 2>/dev/null; then
      ok "conda already initialized in ~/.bashrc"
    else
      run "$HOME/miniconda3/bin/conda" init bash
    fi
  fi
  _shell_bashrc_block | ensure_block "$HOME/.bashrc" bash-env
  ok "bash env block up to date in ~/.bashrc"
}

_shell_git() {
  local cur_name cur_email name email
  apt_install git
  cur_name="$(git config --global user.name 2>/dev/null || true)"
  cur_email="$(git config --global user.email 2>/dev/null || true)"
  name="$(ask_value 'Git user name' "$cur_name")"
  email="$(ask_value 'Git email' "$cur_email")"
  if [[ -n "$name" && "$name" != "$cur_name" ]]; then run git config --global user.name "$name"; fi
  if [[ -n "$email" && "$email" != "$cur_email" ]]; then run git config --global user.email "$email"; fi

  if ask_yn "Set up gh as the git credential helper?" y; then
    if have gh; then
      local host
      for host in https://github.com https://gist.github.com; do
        run git config --global --unset-all "credential.$host.helper" || true
        run git config --global "credential.$host.helper" '!gh auth git-credential'
      done
    else
      warn "gh not installed; credential helper not set"
    fi
  fi

  ensure_line "$HOME/.config/git/ignore" '**/.claude/settings.local.json'
  run git config --global core.excludesFile "$HOME/.config/git/ignore"
}

_shell_gh() {
  have gh || { log "gh not installed; skipping gh config"; return 0; }
  run gh config set git_protocol https
  run gh alias set --clobber co 'pr checkout'
}

_shell_ssh() {
  local email host
  run mkdir -p "$HOME/.ssh"
  run chmod 700 "$HOME/.ssh"
  [[ -f "$HOME/.ssh/config" ]] || run touch "$HOME/.ssh/config"
  run chmod 600 "$HOME/.ssh/config"

  if [[ -f "$HOME/.ssh/id_ed25519" ]]; then
    ok "SSH key already present"
  elif ask_yn "Generate a new ed25519 SSH key?" n; then
    email="$(git config --global user.email 2>/dev/null || true)"
    run ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -C "$email"
  fi
  log "Keys are never copied. Restore ~/.ssh/authorized_keys and known_hosts from backup if wanted."

  if [[ -n "$(secret_get DEV_SSH_HOST || true)" ]]; then
    ok "DEV_SSH_HOST already set in secrets.env"
  elif ask_yn "Set DEV_SSH_HOST now (used by the sshdev alias)?" n; then
    host="$(ask_value 'SSH host for sshdev')"
    if [[ -n "$host" ]]; then secret_set DEV_SSH_HOST "$host"; fi
  fi
}

module_shell() {
  log "Shell and user configuration"
  apt_install zsh curl git

  _shell_login_shell
  _shell_zsh_deploy
  _shell_bash
  _shell_git
  _shell_gh
  _shell_ssh

  if [[ -d "$HOME/GIT/VoiceStudio" ]]; then
    log "Note: ~/GIT/VoiceStudio found. Its systemd user unit is not installed by this module."
  fi
  ok "shell module done"
}
