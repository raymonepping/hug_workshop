#!/usr/bin/env bash
# start_terraform_agent.sh
# Usage:
#   ./start_terraform_agent.sh up [--fg] [--no-root]
#   ./start_terraform_agent.sh down
#   ./start_terraform_agent.sh restart [--fg] [--no-root]
#   ./start_terraform_agent.sh status
#   ./start_terraform_agent.sh logs

set -euo pipefail

# shellcheck disable=SC2034
VERSION="1.0.0"

IMAGE="hashicorp/tfc-agent:1.25.1"
NAME="tfc-agent"
PLATFORM="linux/amd64"

ENV_FILE="$(dirname "$0")/.env"
if [ -f "$ENV_FILE" ]; then set -a; . "$ENV_FILE"; set +a; fi

: "${TFC_AGENT_NAME:?TFC_AGENT_NAME must be set in .env}"
: "${TFC_AGENT_TOKEN:?TFC_AGENT_TOKEN must be set in .env}"

container_exists() { docker ps -a --format '{{.Names}}' | grep -qx "$NAME"; }
container_running() { docker ps --format '{{.Names}}' | grep -qx "$NAME"; }

canon_path() {
  local p="$1"
  if command -v readlink >/dev/null 2>&1; then
    readlink -f "$p" 2>/dev/null || readlink "$p" 2>/dev/null || echo "$p"
  else
    echo "$p"
  fi
}

file_gid() {
  local p="$1"
  if stat -c '%g' "$p" >/dev/null 2>&1; then stat -c '%g' "$p"
  elif stat -f '%g' "$p" >/dev/null 2>&1; then stat -f '%g' "$p"
  else echo ""; fi
}

# Sets global arrays: DOCKER_MOUNT_ARGS, DOCKER_ENV_ARGS
detect_docker_access() {
  DOCKER_MOUNT_ARGS=()
  DOCKER_ENV_ARGS=()

  local host="${DOCKER_HOST:-}"
  if [[ -n "$host" && "$host" == tcp://* ]]; then
    DOCKER_ENV_ARGS=( -e "DOCKER_HOST=$host" )
    return
  fi

  local sock_path="/var/run/docker.sock"
  if [[ -n "$host" && "$host" == unix://* ]]; then
    sock_path="${host#unix://}"
  fi

  local real_sock; real_sock="$(canon_path "$sock_path")"
  if [ ! -S "$real_sock" ]; then
    echo "❌ Docker socket not found: $real_sock"
    echo "   Start Docker, or export DOCKER_HOST=tcp://host.docker.internal:2375"
    exit 1
  fi

  DOCKER_MOUNT_ARGS=( -v "${real_sock}:/var/run/docker.sock" )

  local gid; gid="$(file_gid "$real_sock" || true)"
  if [[ -n "${gid:-}" && "$gid" =~ ^[0-9]+$ && "$gid" -gt 0 ]]; then
    DOCKER_MOUNT_ARGS+=( --group-add "$gid" )
  fi
}

up() {
  local FG=false RUN_AS_ROOT=true
  for arg in "${@:-}"; do
    case "$arg" in
      --fg)      FG=true ;;
      --no-root) RUN_AS_ROOT=false ;;
    esac
  done

  if container_running; then echo "✅ $NAME already running."; return; fi
  if container_exists; then echo "🧹 Removing stale container…"; docker rm -f "$NAME" >/dev/null; fi

  detect_docker_access

  local COMMON_FLAGS=(
    --name "$NAME"
    --platform "$PLATFORM"
    --pull=always
    -e "TFC_AGENT_TOKEN=$TFC_AGENT_TOKEN"
    -e "TFC_AGENT_NAME=$TFC_AGENT_NAME"
    "${DOCKER_MOUNT_ARGS[@]}"
    "${DOCKER_ENV_ARGS[@]}"
  )
  if [ "$RUN_AS_ROOT" = true ]; then COMMON_FLAGS+=( --user 0:0 ); fi

  echo "🚀 Starting Terraform Agent: $TFC_AGENT_NAME"
  if [ "$FG" = true ]; then
    echo "📺 Foreground mode (Ctrl+C to stop)"
    exec docker run --rm "${COMMON_FLAGS[@]}" "$IMAGE"
  else
    docker run -d --restart=unless-stopped "${COMMON_FLAGS[@]}" "$IMAGE" >/dev/null
    sleep 1
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
  up) shift; up "$@" ;;
  down) down ;;
  restart) shift; restart "$@" ;;
  status) status ;;
  logs) logs ;;
  *) echo "Usage: $0 {up [--fg] [--no-root]|down|restart [--fg] [--no-root]|status|logs}"; exit 1 ;;
esac
