\export PATH="$HOME/.local/bin:$PATH"

# Alias python/pip to python3/pip3
alias python=python3
alias pip=pip3

if [[ -f "$HOME/.cargo/env" ]]; then
  source "$HOME/.cargo/env"
fi

# Show user, host, and current directory in zsh prompts.
PROMPT='%n@%m:%~%# '

if [[ -d /usr/local/cuda ]]; then
  export CUDA_HOME=/usr/local/cuda
  export CUDACXX="$CUDA_HOME/bin/nvcc"
  export PATH="$CUDA_HOME/bin:$PATH"
fi
