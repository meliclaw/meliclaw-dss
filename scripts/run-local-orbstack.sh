#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT_DIR/scripts/build-local-image.sh" meliclaw/meliclaw-dss:local

docker compose -f "$ROOT_DIR/docker/meliclaw-dss-compose.yml" up -d

cat <<'INFO'
Meliclaw DSS is starting in the OrbStack project/group meliclaw-storage-management.

Local endpoints:
  Admin UI:      http://127.0.0.1:23647
  S3 API:        http://127.0.0.1:18333
  Filer UI:      http://127.0.0.1:18889
  Master UI:     http://127.0.0.1:19334
  Volume UI:     http://127.0.0.1:19340
  WebDAV:        http://127.0.0.1:17333
INFO
