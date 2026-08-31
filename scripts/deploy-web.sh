#!/usr/bin/env bash
set -euo pipefail

IMAGE_REF="${1:?usage: deploy-web.sh <registry/image@sha256:digest-or-tag>}"
APP_NAME="${APP_NAME:-meliclaw-dss}"
ROOT_DIR="${ROOT_DIR:-/opt/meliclaw-dss}"
DATA_DIR="${DATA_DIR:-/var/lib/meliclaw-dss/data}"
LIVE_PORTS_DIR="${ROOT_DIR}/ports"
NETWORK_NAME="${NETWORK_NAME:-meliclaw-dss-net}"

mkdir -p "$ROOT_DIR" "$DATA_DIR" "$LIVE_PORTS_DIR"
docker network inspect "$NETWORK_NAME" >/dev/null 2>&1 || docker network create "$NETWORK_NAME" >/dev/null

current_color=""
if [ -f "$ROOT_DIR/current-color" ]; then
  current_color="$(cat "$ROOT_DIR/current-color")"
fi

if [ "$current_color" = "blue" ]; then
  next_color="green"
  old_color="blue"
  host_admin_port=23648
  host_s3_port=18334
  host_filer_port=18890
  host_master_port=19335
  host_volume_port=19341
  host_webdav_port=17334
else
  next_color="blue"
  old_color="green"
  host_admin_port=23647
  host_s3_port=18333
  host_filer_port=18889
  host_master_port=19334
  host_volume_port=19340
  host_webdav_port=17333
fi

next_container="${APP_NAME}-${next_color}"
old_container="${APP_NAME}-${old_color}"

echo "pull: ${IMAGE_REF}"
docker pull "$IMAGE_REF"

echo "replace candidate: ${next_container}"
docker rm -f "$next_container" >/dev/null 2>&1 || true
docker run -d \
  --name "$next_container" \
  --network "$NETWORK_NAME" \
  --restart unless-stopped \
  -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-admin}" \
  -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-secret}" \
  -e S3_BUCKET="${S3_BUCKET:-meliclaw-dss}" \
  -e GODEBUG="${GODEBUG:-fips140=off}" \
  -p "127.0.0.1:${host_webdav_port}:7333" \
  -p "127.0.0.1:${host_s3_port}:8333" \
  -p "127.0.0.1:${host_filer_port}:8888" \
  -p "127.0.0.1:${host_master_port}:9333" \
  -p "127.0.0.1:${host_volume_port}:9340" \
  -p "127.0.0.1:${host_admin_port}:23646" \
  -v "${DATA_DIR}:/data" \
  "$IMAGE_REF" \
  mini -dir=/data

echo "wait: ${next_container}"
for _ in $(seq 1 60); do
  if curl -fsS "http://127.0.0.1:${host_admin_port}/" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

BASE_ADMIN="http://127.0.0.1:${host_admin_port}" \
BASE_S3="http://127.0.0.1:${host_s3_port}" \
BASE_MASTER="http://127.0.0.1:${host_master_port}" \
BASE_FILER="http://127.0.0.1:${host_filer_port}" \
  "${ROOT_DIR}/current/scripts/smoke-meliclaw-dss.sh"

echo "$next_color" > "$ROOT_DIR/current-color"
cat > "$LIVE_PORTS_DIR/current.env" <<PORTS
MELICLAW_DSS_COLOR=${next_color}
MELICLAW_DSS_ADMIN_PORT=${host_admin_port}
MELICLAW_DSS_S3_PORT=${host_s3_port}
MELICLAW_DSS_FILER_PORT=${host_filer_port}
MELICLAW_DSS_MASTER_PORT=${host_master_port}
MELICLAW_DSS_VOLUME_PORT=${host_volume_port}
MELICLAW_DSS_WEBDAV_PORT=${host_webdav_port}
PORTS

if docker inspect "$old_container" >/dev/null 2>&1; then
  echo "stop old: ${old_container}"
  docker rm -f "$old_container" >/dev/null
fi

echo "done: ${next_color} is live"
