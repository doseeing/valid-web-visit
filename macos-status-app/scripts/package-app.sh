#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$APP_ROOT/.." && pwd)"
MACOS_SIGN_IDENTITY="${MACOS_SIGN_IDENTITY:-}"

if [[ ! -d "$PROJECT_ROOT/go-api" ]]; then
  echo "缺少 go-api 目录。" >&2
  exit 1
fi

if ! command -v go >/dev/null 2>&1; then
  echo "go 未安装，无法编译 Go API。" >&2
  exit 1
fi

if [[ -z "$MACOS_SIGN_IDENTITY" ]]; then
  MACOS_SIGN_IDENTITY="$(
    security find-identity -v -p codesigning 2>/dev/null \
      | sed -n 's/.*"\(.*\)"/\1/p' \
      | head -n 1
  )"
fi

cd "$APP_ROOT"

swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)"
GO_API_BIN_DIR="$PROJECT_ROOT/.tmp/macos-package"
GO_API_BIN="$GO_API_BIN_DIR/go-api"
APP_BUNDLE="$APP_ROOT/dist/HonoStatusApp.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
RUNTIME_DIR="$RESOURCES_DIR/runtime"

mkdir -p "$GO_API_BIN_DIR"
(
  cd "$PROJECT_ROOT/go-api"
  env CGO_ENABLED=1 GOCACHE="$PROJECT_ROOT/.tmp/go-build" GOTMPDIR="$PROJECT_ROOT/.tmp/go-tmp" \
    go build -ldflags='-linkmode external -s -w' -o "$GO_API_BIN" .
)

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RUNTIME_DIR"

cp "$BIN_PATH/HonoStatusApp" "$MACOS_DIR/HonoStatusApp"
chmod +x "$MACOS_DIR/HonoStatusApp"

cp "$GO_API_BIN" "$RUNTIME_DIR/go-api"
chmod +x "$RUNTIME_DIR/go-api"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>HonoStatusApp</string>
  <key>CFBundleIdentifier</key>
  <string>com.codex.HonoStatusApp</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>HonoStatusApp</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

if [[ -n "$MACOS_SIGN_IDENTITY" ]]; then
  codesign --force --deep --sign "$MACOS_SIGN_IDENTITY" "$APP_BUNDLE"
else
  codesign --force --deep --sign - "$APP_BUNDLE"
  echo "未找到可用的 macOS 签名身份，已回退到 ad-hoc 签名。" >&2
fi

echo "已生成 App: $APP_BUNDLE"
