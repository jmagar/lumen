#!/usr/bin/env bash
set -euo pipefail

# Codex installs plugins into a cache path, so derive the plugin root from the
# script location instead of depending on an external environment variable.
PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
esac

export LUMEN_BACKEND="${LUMEN_BACKEND:-ollama}"
export LUMEN_EMBED_MODEL="${LUMEN_EMBED_MODEL:-ordis/jina-embeddings-v2-base-code}"

BINARY=""
for candidate in \
  "${PLUGIN_ROOT}/bin/lumen" \
  "${PLUGIN_ROOT}/bin/lumen-${OS}-${ARCH}"; do
  if [ -x "$candidate" ]; then
    BINARY="$candidate"
    break
  fi
done

if [ -z "$BINARY" ]; then
  BINARY="${PLUGIN_ROOT}/bin/lumen-${OS}-${ARCH}"
  REPO="ory/lumen"
  MANIFEST="${PLUGIN_ROOT}/.codex-plugin/plugin.json"
  if [ ! -f "$MANIFEST" ]; then
    echo "Error: .codex-plugin/plugin.json not found in ${PLUGIN_ROOT}" >&2
    exit 1
  fi

  VERSION="v$(sed -n 's/^[[:space:]]*\"version\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p' "$MANIFEST" | head -n 1)"
  if [ -z "$VERSION" ] || [ "$VERSION" = "v" ]; then
    echo "Error: could not read version from ${MANIFEST}" >&2
    exit 1
  fi

  ASSET="lumen-${VERSION#v}-${OS}-${ARCH}"
  URL="https://github.com/${REPO}/releases/download/${VERSION}/${ASSET}"

  echo "Downloading lumen ${VERSION} for ${OS}/${ARCH}..." >&2
  mkdir -p "$(dirname "$BINARY")"
  curl -fL --progress-bar --max-time 300 --retry 3 --retry-delay 2 "$URL" -o "$BINARY"
  chmod +x "$BINARY"
  echo "Installed lumen to ${BINARY}" >&2
fi

exec "$BINARY" "$@"
