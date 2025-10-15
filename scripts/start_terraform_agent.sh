#!/usr/bin/env bash
# start_terraform_agent.sh
#
# Manage a Terraform Cloud Agent in Docker.
# Usage:
#   ./start_terraform_agent.sh up [--fg]   # start agent (default = background)
#   ./start_terraform_agent.sh down        # stop and remove agent
#   ./start_terraform_agent.sh restart     # restart agent
#   ./start_terraform_agent.sh status      # show container status
#   ./start_terraform_agent.sh logs        # follow agent logs
#
# Env file expected at ./scripts/.env with:
#   TFC_AGENT_NAME=hug-agent-1
#   TFC_AGENT_TOKEN=atlasv1_xxxxxxxxxxxxxxx

set -euo pipefail

IMAGE="hashicorp/tfc-agent:1.25.1"   # pin to latest stable
NAME="tfc-agent"
PLATFORM="linux/amd64"

ENV_FILE="$(dirname "$0")/.env"
if [ -f "$ENV_FILE" ]; then
  set -a
  . "$ENV_FILE"
  set +a
fi

: "${TFC_AGENT_NAME:?TFC_AGENT_NAME must be set in .env}"
: "${TFC_AGENT_TOKEN:?TFC_AGENT_TOKEN must be set in .env}"

container_exists() { docker ps -a --format '{{.Names}}' | grep -qx "$NAME"; }
container_running() { docker ps --format '{{.Names}}' | grep -qx "$NAME"; }

up() {
  local FG=false
  if [[ "${1:-}" == "--fg" ]]; then
    FG=true
  fi

  if container_running; then
    echo "✅ $NAME already running."
    return
  fi
  if container_exists; then
    echo "🧹 Removing stale container…"
    docker rm -f "$NAME" >/dev/null
  fi

  echo "🚀 Starting Terraform Agent: $TFC_AGENT_NAME"

  if [ "$FG" = true ]; then
    echo "📺 Running in foreground (Ctrl+C to stop)"
    exec docker run --rm \
      --name "$NAME" \
      --platform "$PLATFORM" \
      -e TFC_AGENT_TOKEN="$TFC_AGENT_TOKEN" \
      -e TFC_AGENT_NAME="$TFC_AGENT_NAME" \
      "$IMAGE"
  else
    docker run -d \
      --name "$NAME" \
      --platform "$PLATFORM" \
      --pull always \
      --restart unless-stopped \
      -e TFC_AGENT_TOKEN="$TFC_AGENT_TOKEN" \
      -e TFC_AGENT_NAME="$TFC_AGENT_NAME" \
      "$IMAGE" >/dev/null
    echo "✅ Agent started in background (use 'logs' to view output)."
  fi
}

down() {
  if container_exists; then
    echo "🛑 Stopping & removing $NAME…"
    docker rm -f "$NAME" >/dev/null || true
    echo "✅ Removed."
  else
    echo "ℹ️ $NAME not present."
  fi
}

restart() { down; up "$@"; }

status() {
  if container_exists; then
    docker ps -a --filter "name=$NAME" \
      --format "table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.RunningFor}}"
  else
    echo "ℹ️ $NAME not present."
  fi
}

logs() { docker logs -f "$NAME"; }

case "${1:-}" in
  up) up "${2:-}" ;;
  down) down ;;
  restart) restart "${2:-}" ;;
  status) status ;;
  logs) logs ;;
  *)
    echo "Usage: $0 {up [--fg]|down|restart [--fg]|status|logs}"
    exit 1
    ;;
esac
