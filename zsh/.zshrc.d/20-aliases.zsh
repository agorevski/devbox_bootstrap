# Custom SSH alias (host from DEV_SSH_HOST)
alias sshdev='ssh "$DEV_SSH_HOST"'

# Claude Code model shortcuts
alias claudeh='claude --dangerously-skip-permissions --model claude-haiku-5-5'
alias claudes='claude --dangerously-skip-permissions --model claude-sonnet-5-5'
alias claude='claude --dangerously-skip-permissions --model claude-opus-5-5'

# Local Claude API endpoint
alias claudea='ANTHROPIC_BASE_URL="$CLAUDE_LOCAL_BASE_URL" ANTHROPIC_API_KEY=dummy-key-or-your-token command claude --dangerously-skip-permissions --model qwen3.8-27b'

# Copilot CLI with local model settings
alias copilot='copilot --model claude-haiku-5.5 --context long_context --reasoning-effort medium --yolo'

# Launch OpenCode with the local OpenAI-compatible Qwen agent
alias opencode='OPENCODE_CONFIG="$HOME/.config/opencode/local-qwen.json" "$HOME/.opencode/bin/opencode" --agent local-qwen'
