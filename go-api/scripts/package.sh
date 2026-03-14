#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GO_API_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$GO_API_ROOT/dist"

GOOS_VALUE="${GOOS:-$(go env GOOS)}"
GOARCH_VALUE="${GOARCH:-$(go env GOARCH)}"
OUTPUT_NAME="go-api-${GOOS_VALUE}-${GOARCH_VALUE}"

mkdir -p "$DIST_DIR"

(
  cd "$GO_API_ROOT"
  env CGO_ENABLED=1 \
    GOOS="$GOOS_VALUE" \
    GOARCH="$GOARCH_VALUE" \
    go build -ldflags='-linkmode external -s -w' -o "$DIST_DIR/$OUTPUT_NAME" .
)

chmod +x "$DIST_DIR/$OUTPUT_NAME"

echo "Built binary: $DIST_DIR/$OUTPUT_NAME"
