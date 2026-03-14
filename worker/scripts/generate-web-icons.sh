#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
WORKER_DIR="${SCRIPT_DIR:h}"
PROJECT_ROOT="${WORKER_DIR:h}"
SOURCE_IMAGE="${PROJECT_ROOT}/resource/logo.png"
OUTPUT_DIR="${WORKER_DIR}/generated"

if [[ ! -f "${SOURCE_IMAGE}" ]]; then
  echo "Missing source image: ${SOURCE_IMAGE}" >&2
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"

sizes=(
  "favicon-16x16.png:16"
  "favicon-32x32.png:32"
  "apple-touch-icon.png:180"
  "web-app-manifest-192x192.png:192"
  "web-app-manifest-512x512.png:512"
)

for entry in "${sizes[@]}"; do
  file_name="${entry%%:*}"
  size="${entry##*:}"
  sips -z "${size}" "${size}" "${SOURCE_IMAGE}" --out "${OUTPUT_DIR}/${file_name}" >/dev/null
done

cat > "${OUTPUT_DIR}/site.webmanifest" <<'EOF'
{
  "name": "Local Bridge Checker",
  "short_name": "Local Bridge",
  "description": "Check the local Local Bridge API and desktop file listing from the browser.",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#f4f2ed",
  "theme_color": "#d85f3c",
  "icons": [
    {
      "src": "/web-app-manifest-192x192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "/web-app-manifest-512x512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ]
}
EOF

node "${SCRIPT_DIR}/write-web-icons-module.mjs"

echo "Generated worker web icons from ${SOURCE_IMAGE}"
