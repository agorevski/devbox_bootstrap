# Claude Code through the local Strata proxy. Ports 8080-8083 map to claude0-claude3.
# The API key comes from ANTHROPIC_API_KEY, or ANTHROPIC_AUTH_TOKEN in secrets.env.
_devbox_secret() {
  local key="$1" file="$HOME/.config/devbox/secrets.env"
  [[ -r "$file" ]] || return 1
  grep -E "^${key}=" "$file" | tail -n1 | cut -d= -f2-
}

_claude_on_port() {
  local port="$1" api_key
  shift

  if ! curl -fsS --max-time 3 "http://127.0.0.1:${port}/health" >/dev/null; then
    printf '%s\n' "Strata is not running locally on port ${port}. Start it with ./launch.sh first." >&2
    return 1
  fi

  api_key="${ANTHROPIC_API_KEY:-$(_devbox_secret ANTHROPIC_AUTH_TOKEN)}"

  (
    export ANTHROPIC_BASE_URL="http://127.0.0.1:${port}"
    export ANTHROPIC_MODEL="claude-haiku-4-5-20251001"
    export CLAUDE_CODE_AUTO_COMPACT_WINDOW=245000
    [[ -n "$api_key" ]] && export ANTHROPIC_API_KEY="$api_key"
    command claude --dangerously-skip-permissions "$@"
  )
}

claude0() { _claude_on_port 8080 "$@"; }
claude1() { _claude_on_port 8081 "$@"; }
claude2() { _claude_on_port 8082 "$@"; }
claude3() { _claude_on_port 8083 "$@"; }
