#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC2034
VERSION="1.0.0"

# construct_container.sh
# Build/push backend & frontend Node/Express images with docker buildx.
#
# Features:
#  - Auto-detect Apple Silicon (arm64) and default to linux/amd64 (A)
#  - Ensure buildx builder exists/selected automatically (B)
#  - Optional multi-arch builds, SBOM & provenance attestations (C)
#  - Uses .env (next to this script) for DOCKERHUB_REPO unless --repo passed
#
# Flags:
#   --backend-dir DIR         (required)
#   --frontend-dir DIR        (required)
#   --repo NAME               (dockerhub namespace; falls back to \$DOCKERHUB_REPO)
#   --version V               (e.g., v1.1.0; optional)
#   --platform PLATFORMS      (e.g., linux/amd64 or linux/amd64,linux/arm64)
#   --push true|false         (default: false)
#   --latest true|false       (also tag :latest, default: false)
#   --multiarch true|false    (default: false; implies --platform linux/amd64,linux/arm64)
#   --sbom true|false         (default: true; requires BuildKit >= 0.10)
#   --provenance true|false   (default: true; adds attestation)
#
# Outputs:
#   repo/hug-backend:<version>   and optionally :latest
#   repo/hug-frontend:<version>  and optionally :latest
#
# Notes:
#  - If multi-arch and not pushing, buildx cannot --load multi-arch into docker; we enforce --push.
#  - If single-arch and not pushing, we use --load to import into local docker.
#  - No secrets baked; run containers with --env-file for backend and bind config.json for frontend.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Load .env from:
#   1) same folder as script (preferred)
#   2) project root fallback
if [[ -f "${SCRIPT_DIR}/.env" ]]; then
  # .env lives next to this script
  # shellcheck disable=SC1090
  source "${SCRIPT_DIR}/.env"
elif [[ -f "${ROOT_DIR}/.env" ]]; then
  # fallback to project root
  # shellcheck disable=SC1090
  source "${ROOT_DIR}/.env"
fi

die() { echo "❌ $*" >&2; exit 1; }

print_help() {
  cat <<EOF
$(basename "$0") v${VERSION}
Build and optionally push backend & frontend images with docker buildx.

Usage:
  $(basename "$0") \\
    --backend-dir DIR \\
    --frontend-dir DIR \\
    [--repo NAME] \\
    [--version V] \\
    [--platform PLATFORMS] \\
    [--push true|false] \\
    [--latest true|false] \\
    [--multiarch true|false] \\
    [--sbom true|false] \\
    [--provenance true|false]

Required:
  --backend-dir DIR         Backend project directory (contains Dockerfile)
  --frontend-dir DIR        Frontend project directory (contains Dockerfile)

Optional:
  --repo NAME               Docker Hub namespace (e.g. repping).
                            Defaults to \$DOCKERHUB_REPO from .env if set.
  --version V               Image version/tag (default: \$VERSION or v1.0.0)
  --platform PLATFORMS      e.g. linux/amd64 or linux/amd64,linux/arm64.
                            If omitted:
                              - On arm64 hosts → defaults to linux/amd64
                              - Else → native platform
  --push true|false         Push images to registry (default: false)
  --latest true|false       Also tag :latest (default: false)
  --multiarch true|false    Build multi-arch manifest (default: false)
                            Implies --platform linux/amd64,linux/arm64.
  --sbom true|false         Attach SBOM attestation (default: true)
  --provenance true|false   Attach provenance attestation (default: true)

Meta:
  -h, --help                Show this help and exit
  -V, --version             Show version and exit

Outputs:
  \${repo}/hug-backend:<version>      (and optionally :latest)
  \${repo}/hug-frontend:<version>     (and optionally :latest)

Notes:
  - Multi-arch builds require --push (buildx cannot --load multi-platform).
  - Single-arch + --push=false uses --load to import into local docker.
  - No secrets are baked:
      * Backend: pass env via --env-file at runtime.
      * Frontend: mount config.json (e.g. apiBase) into the container.

Examples:

  # Simple local build (single-arch, no push)
  $(basename "$0") \\
    --backend-dir ./backend \\
    --frontend-dir ./frontend \\
    --repo repping \\
    --version v1.2.3

  # Multi-arch build with push, latest tag, SBOM & provenance
  $(basename "$0") \\
    --backend-dir ./backend \\
    --frontend-dir ./frontend \\
    --repo repping \\
    --version v1.2.3 \\
    --multiarch true \\
    --push true \\
    --latest true

EOF
}

# ---- defaults ----
BACKEND_DIR=""
FRONTEND_DIR=""
REPO="${DOCKERHUB_REPO:-}"
VERSION="${VERSION:-v1.0.0}"
PLATFORM=""
PUSH="false"
LATEST="false"
MULTIARCH="false"
SBOM="${SBOM:-true}"
PROVENANCE="${PROVENANCE:-true}"

# ---- args ----
args=("$@"); i=0
while [[ $i -lt ${#args[@]} ]]; do
  a="${args[$i]}"
  case "$a" in
    --backend-dir)   BACKEND_DIR="${args[$((i+1))]:-}"; i=$((i+2));;
    --frontend-dir)  FRONTEND_DIR="${args[$((i+1))]:-}"; i=$((i+2));;
    --repo)          REPO="${args[$((i+1))]:-}"; i=$((i+2));;
    --version)       VERSION="${args[$((i+1))]:-}"; i=$((i+2));;
    --platform)      PLATFORM="${args[$((i+1))]:-}"; i=$((i+2));;
    --push)          PUSH="${args[$((i+1))]:-}"; i=$((i+2));;
    --latest)        LATEST="${args[$((i+1))]:-}"; i=$((i+2));;
    --multiarch)     MULTIARCH="${args[$((i+1))]:-}"; i=$((i+2));;
    --sbom)          SBOM="${args[$((i+1))]:-}"; i=$((i+2));;
    --provenance)    PROVENANCE="${args[$((i+1))]:-}"; i=$((i+2));;
    -h|--help)
      print_help
      exit 0
      ;;
    -V|--version|--ver)
      echo "$(basename "$0") v${VERSION}"
      exit 0
      ;;
    *)
      die "Unknown arg: $a (use --help)";
      ;;
  esac
done

[[ -n "$BACKEND_DIR"  ]] || die "--backend-dir is required"
[[ -n "$FRONTEND_DIR" ]] || die "--frontend-dir is required"
[[ -d "$BACKEND_DIR"  ]] || die "Backend dir not found: $BACKEND_DIR"
[[ -d "$FRONTEND_DIR" ]] || die "Frontend dir not found: $FRONTEND_DIR"

# repo fallback
[[ -n "$REPO" ]] || die "--repo not provided and DOCKERHUB_REPO not set in .env"

# ---- buildx ensure ----
ensure_buildx() {
  if ! docker buildx version >/dev/null 2>&1; then
    die "docker buildx not available. Update Docker Desktop or install buildx."
  fi
  local active
  active="$(docker buildx ls | awk '/\*/{print $1}' || true)"
  if [[ -z "$active" ]]; then
    echo "ℹ️  No active buildx builder. Creating 'hug_builder'…"
    docker buildx create --name hug_builder --use >/dev/null
  fi
}
ensure_buildx

# ---- arch logic (A) ----
HOST_UNAME="$(uname -m || echo unknown)"
if [[ -z "$PLATFORM" ]]; then
  if [[ "$MULTIARCH" == "true" ]]; then
    PLATFORM="linux/amd64,linux/arm64"
  else
    if [[ "$HOST_UNAME" == "arm64" || "$HOST_UNAME" == "aarch64" ]]; then
      PLATFORM="linux/amd64"
      echo "ℹ️  Apple Silicon detected → defaulting --platform linux/amd64"
    else
      PLATFORM=""  # native
    fi
  fi
fi

# warn if Apple Silicon and not overriding
if [[ ( "$HOST_UNAME" == "arm64" || "$HOST_UNAME" == "aarch64" ) && "$PLATFORM" != *"linux/amd64"* ]]; then
  echo "⚠️  On Apple Silicon but --platform does not include linux/amd64. Images may not run on x86 hosts."
fi

# multi-arch requires push (buildx cannot --load multi-platform)
if [[ "$MULTIARCH" == "true" && "$PUSH" != "true" ]]; then
  echo "ℹ️  Multi-arch build requested → enabling --push (required for manifest)."
  PUSH="true"
fi

# ---- targets & tags ----
BACKEND_TAG="${REPO}/hug-backend:${VERSION}"
FRONTEND_TAG="${REPO}/hug-frontend:${VERSION}"

echo "📦 Backend image:  ${BACKEND_TAG}"
echo "📦 Frontend image: ${FRONTEND_TAG}"
echo "   Push: ${PUSH}"
[[ -n "$PLATFORM" ]] && echo "   Platform(s): ${PLATFORM}"
[[ "$MULTIARCH" == "true" ]] && echo "   Multi-arch: true"
[[ "$LATEST" == "true" ]] && echo "   Also tag  : latest"
[[ "$SBOM" == "true" ]] && echo "   SBOM      : enabled"
[[ "$PROVENANCE" == "true" ]] && echo "   Provenance: enabled"

# ---- common build args (B,C) ----
build_common=()
[[ -n "$PLATFORM" ]] && build_common+=( --platform "$PLATFORM" )
if [[ "$PUSH" == "true" ]]; then
  build_common+=( --push )
else
  # Only load if single-arch; buildx can't load multi-platform into docker
  if [[ "$PLATFORM" == *","* ]]; then
    die "Cannot --load multi-arch image. Use --push true or set a single --platform."
  fi
  build_common+=( --load )
fi

# SBOM/Provenance (requires BuildKit >= 0.10; Docker Desktop recent versions OK)
if [[ "$SBOM" == "true" ]]; then
  build_common+=( --sbom=true )
fi
if [[ "$PROVENANCE" == "true" ]]; then
  build_common+=( --provenance=true )
fi

# latest tags
backend_tags=( -t "$BACKEND_TAG" )
frontend_tags=( -t "$FRONTEND_TAG" )
if [[ "$LATEST" == "true" ]]; then
  backend_tags+=( -t "${REPO}/hug-backend:latest" )
  frontend_tags+=( -t "${REPO}/hug-frontend:latest" )
fi

# ---- build backend ----
(
  cd "$BACKEND_DIR"
  [[ -f Dockerfile ]] || die "Backend Dockerfile missing at $BACKEND_DIR/Dockerfile"
  docker buildx build . \
    "${backend_tags[@]}" \
    "${build_common[@]}"
)

# ---- build frontend ----
(
  cd "$FRONTEND_DIR"
  [[ -f Dockerfile ]] || die "Frontend Dockerfile missing at $FRONTEND_DIR/Dockerfile"
  docker buildx build . \
    "${frontend_tags[@]}" \
    "${build_common[@]}"
)

echo "✅ Build complete."

# ---- run examples ----
cat <<EOF

Run examples (no secrets baked):

# Backend: pass envs at runtime (uses your existing ./backend/.env)
docker run --rm -it -p 3004:3004 --env-file ./backend/.env \\
  ${REPO}/hug-backend:${VERSION}

# Frontend (Express static): bind a config.json pointing to backend
# Example config.json:
# { "apiBase": "http://localhost:3004", "itemsLimit": 32 }
docker run --rm -it -p 5173:5173 \\
  -v "\$(pwd)/frontend/public/config.json:/app/public/config.json:ro" \\
  ${REPO}/hug-frontend:${VERSION}
EOF
