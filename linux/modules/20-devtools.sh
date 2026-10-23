# shellcheck shell=bash
# shellcheck source=../lib/common.sh
# Developer toolchains. Source this file, then call module_devtools. Defines functions only.

# True when the tool is on PATH, or when dry-run is on (so the planned commands still print).
_devtools_tool_ready() {
  [[ "$DEVBOX_DRY_RUN" == "1" ]] || have "$1"
}

# Fetch an https installer and pipe it into an interpreter. usage: _devtools_curl_pipe URL INTERP [ARGS...]
_devtools_curl_pipe() {
  local url="$1" interp="$2"
  shift 2
  if [[ "$DEVBOX_DRY_RUN" == "1" ]]; then
    printf '  [dry-run] curl -fsSL %s | %s -s -- %s\n' "$url" "$interp" "$*"
    return 0
  fi
  curl --proto '=https' --tlsv1.2 -fsSL "$url" | "$interp" -s -- "$@"
}

_devtools_nodejs() {
  local installed=0
  if have node && [[ "$(node -v 2>/dev/null)" == v22.* ]]; then
    ok "Node.js 22 already installed: $(node -v)"
    installed=1
  elif ask_yn "Install Node.js 22 via NodeSource?" y; then
    add_apt_repo nodesource https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
      "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main"
    apt_install nodejs
    installed=1
  fi
  (( installed )) || return 0

  if ask_yn "Use per-user npm global prefix ~/.npm-global?" y; then
    if _devtools_tool_ready npm; then
      run npm config set prefix "$HOME/.npm-global"
    else
      warn "npm not found; skipping npm prefix"
    fi
  fi

  _devtools_npm_global @anthropic-ai/claude-code claude
  _devtools_npm_global netlify-cli netlify
}

# usage: _devtools_npm_global PACKAGE BINARY
_devtools_npm_global() {
  local pkg="$1" bin="$2"
  if have "$bin"; then
    ok "npm global $pkg already present"
    return 0
  fi
  ask_yn "Install npm global package $pkg?" n || return 0
  if ! _devtools_tool_ready npm; then
    warn "npm not found; skipping $pkg"
    return 0
  fi
  run npm install -g "$pkg"
}

_devtools_miniconda() {
  local url="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
  # Scratch file lives in the devbox state dir rather than mktemp (/tmp is not allowed here).
  local installer="$DEVBOX_STATE_DIR/Miniconda3-latest-Linux-x86_64.sh"
  run mkdir -p "$DEVBOX_STATE_DIR"
  run curl -fsSL -o "$installer" "$url" || { warn "failed to download Miniconda"; return 1; }
  run bash "$installer" -b -p "$HOME/miniconda3" || { warn "Miniconda install failed"; return 1; }
  run rm -f "$installer"
}

_devtools_python() {
  if [[ -x "$HOME/miniconda3/bin/conda" ]]; then
    ok "Miniconda already installed at $HOME/miniconda3"
  elif ask_yn "Install Miniconda3 into $HOME/miniconda3?" y; then
    _devtools_miniconda
  fi

  if have uv; then
    ok "uv already installed: $(uv --version 2>/dev/null)"
  elif ask_yn "Install uv (Astral)?" y; then
    _devtools_curl_pipe https://astral.sh/uv/install.sh sh
  fi

  if have heretic; then
    ok "heretic-llm already installed"
  elif ask_yn "Install pipx-managed heretic-llm?" n; then
    apt_install pipx
    run pipx install heretic-llm
  fi
}

_devtools_rust_toolchain_present() {
  have rustup && rustup toolchain list 2>/dev/null | grep -q '^1\.95\.0-'
}

_devtools_rust() {
  # Load cargo/rustup onto PATH for this process if they are already installed.
  if [[ -f "$HOME/.cargo/env" ]]; then
    # shellcheck disable=SC1091
    . "$HOME/.cargo/env"
  fi

  if have rustup; then
    ok "rustup already installed: $(rustup --version 2>/dev/null | head -n1)"
  elif ask_yn "Install Rust via rustup (default profile, stable)?" y; then
    _devtools_curl_pipe https://sh.rustup.rs sh -y --profile default
    if [[ -f "$HOME/.cargo/env" ]]; then
      # shellcheck disable=SC1091
      . "$HOME/.cargo/env"
    fi
  else
    return 0
  fi

  if _devtools_rust_toolchain_present; then
    ok "Rust toolchain 1.95.0 already installed"
  elif ask_yn "Install Rust toolchain 1.95.0?" n; then
    run rustup toolchain install 1.95.0
  fi

  if _devtools_tool_ready rustup && rustup target list --installed 2>/dev/null | grep -qx wasm32-unknown-unknown; then
    ok "wasm32-unknown-unknown target already installed"
  elif ask_yn "Add rustup target wasm32-unknown-unknown?" n; then
    run rustup target add wasm32-unknown-unknown
  fi

  if have mdbook; then
    ok "mdbook already installed"
  elif ask_yn "cargo install mdbook 0.4.52?" n; then
    if _devtools_tool_ready cargo; then
      run cargo install mdbook --version 0.4.52
    else
      warn "cargo not found; skipping mdbook"
    fi
  fi
}

_devtools_java() {
  if have javac; then
    ok "JDK already installed: $(javac -version 2>&1)"
  elif ask_yn "Install OpenJDK 21 (headless)?" n; then
    apt_install openjdk-21-jdk-headless
  fi
}

_devtools_dotnet_ready() {
  have dotnet && dotnet --list-sdks 2>/dev/null | grep -q '^8\.0\.' && dotnet --list-sdks 2>/dev/null | grep -q '^10\.0\.'
}

_devtools_dotnet() {
  if _devtools_dotnet_ready; then
    ok ".NET SDKs 8.0 and 10.0 already installed"
  elif ask_yn "Install .NET SDKs 8.0 and 10.0 (Microsoft repo)?" n; then
    add_apt_repo microsoft-prod https://packages.microsoft.com/keys/microsoft.asc \
      "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/ubuntu/${UBUNTU_VERSION_ID}/prod ${UBUNTU_CODENAME} main"
    apt_install dotnet-sdk-8.0 dotnet-sdk-10.0
  fi
}

_devtools_docker() {
  if have docker; then
    ok "Docker already installed: $(docker --version 2>/dev/null)"
  elif ask_yn "Install Docker CE from the Docker apt repo?" y; then
    add_apt_repo docker https://download.docker.com/linux/ubuntu/gpg \
      "deb [arch=amd64 signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME} stable"
    apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  else
    return 0
  fi

  as_root systemctl enable --now docker

  local me
  me="$(id -un)"
  if id -nG "$me" | tr ' ' '\n' | grep -qx docker; then
    ok "$me already in docker group"
  else
    as_root usermod -aG docker "$me"
    warn "Added $me to the docker group. Log out and back in before using docker without sudo."
  fi
}

_devtools_ai_cli() {
  if have claude; then
    ok "Claude Code already installed: $(claude --version 2>/dev/null)"
  elif ask_yn "Install Claude Code (native installer)?" y; then
    _devtools_curl_pipe https://claude.ai/install.sh bash
    log "Claude Code installs to ~/.local/bin, which must be on PATH (handled by the shell module)."
  fi

  if have copilot; then
    ok "GitHub Copilot CLI already installed"
  elif ask_yn "Install GitHub Copilot CLI?" y; then
    _devtools_curl_pipe https://gh.io/copilot-install bash
  fi

  if have opencode; then
    ok "opencode already installed"
  elif ask_yn "Install opencode?" y; then
    _devtools_curl_pipe https://opencode.ai/install bash
  fi

  if have gh; then
    ok "GitHub CLI already installed: $(gh --version 2>/dev/null | head -n1)"
  elif ask_yn "Install GitHub CLI (gh) from the GitHub apt repo?" y; then
    add_apt_repo githubcli https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      "deb [arch=amd64 signed-by=/usr/share/keyrings/githubcli.gpg] https://cli.github.com/packages stable main"
    apt_install gh
  fi
}

_devtools_ollama_up() {
  have ollama && ollama list >/dev/null 2>&1
}

_devtools_ollama_has() {
  have ollama && ollama list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$1"
}

_devtools_ollama() {
  if have ollama; then
    ok "Ollama already installed: $(ollama --version 2>/dev/null | tail -n1)"
  elif ask_yn "Install Ollama?" y; then
    _devtools_curl_pipe https://ollama.com/install.sh sh
  else
    return 0
  fi

  if systemctl cat ollama >/dev/null 2>&1; then
    as_root systemctl enable --now ollama
  fi

  if [[ "$DEVBOX_DRY_RUN" != "1" ]]; then
    local _
    for _ in {1..10}; do
      _devtools_ollama_up && break
      sleep 1
    done
    if ! _devtools_ollama_up; then
      warn "Ollama server is not responding; skipping model pulls"
      return 0
    fi
  fi

  local entry model size
  for entry in \
    "qwen3-coder:30b|18GB" \
    "qwen3.5:27b|17GB" \
    "qwen2.5vl:32b|21GB" \
    "llava:latest|4.7GB" \
    "moondream:latest|1.7GB"; do
    model="${entry%%|*}"
    size="${entry##*|}"
    if _devtools_ollama_has "$model"; then
      ok "Ollama model already pulled: $model"
    elif ask_yn "Pull Ollama model $model (~$size download)?" n; then
      run ollama pull "$model"
    fi
  done
}

_devtools_bun() {
  if have bun; then
    ok "Bun already installed"
  elif ask_yn "Install Bun?" n; then
    _devtools_curl_pipe https://bun.sh/install bash
  fi
}

_devtools_go() {
  if have go; then
    ok "Go already installed: $(go version 2>/dev/null)"
  elif ask_yn "Install Go (golang-go from apt)?" n; then
    apt_install golang-go
  fi
}

module_devtools() {
  detect_ubuntu
  log "Developer toolchains (Ubuntu $UBUNTU_VERSION_ID, $UBUNTU_CODENAME)"
  _devtools_nodejs
  _devtools_python
  _devtools_rust
  _devtools_java
  _devtools_dotnet
  _devtools_docker
  _devtools_ai_cli
  _devtools_ollama
  _devtools_bun
  _devtools_go
}
