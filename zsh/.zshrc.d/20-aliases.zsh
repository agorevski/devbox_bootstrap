# Custom SSH alias (host from DEV_SSH_HOST)
alias sshdev='ssh "$DEV_SSH_HOST"'

# Claude Code model shortcuts
alias claudeh='claude --dangerously-skip-permissions --model claude-haiku-5-5'
alias claudes='claude --dangerously-skip-permissions --model claude-sonnet-5-5'
alias claude='claude --dangerously-skip-permissions --model claude-opus-5-5'

# Local Claude API endpoint
alias claudea='ANTHROPIC_BASE_URL="$CLAUDE_LOCAL_BASE_URL" ANTHROPIC_API_KEY=dummy-key-or-your-token command claude --dangerously-skip-permissions --model qwen3.8-27b'
