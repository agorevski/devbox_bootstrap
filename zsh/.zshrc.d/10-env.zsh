\export PATH="$HOME/.local/bin:$PATH"

# Alias python/pip to python3/pip3
alias python=python3
alias pip=pip3

source "$HOME/.cargo/env"

# Show user, host, and current directory in zsh prompts.
PROMPT='%n@%m:%~%# '

export CUDA_HOME=/usr/local/cuda-13.4
export CUDACXX="$CUDA_HOME/bin/nvcc"
export PATH="$CUDA_HOME/bin:$PATH"
