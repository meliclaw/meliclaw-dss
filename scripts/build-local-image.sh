#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_TAG="${1:-meliclaw/meliclaw-dss:local}"

cd "$ROOT_DIR"

echo "Building Meliclaw DSS binary..."
CGO_ENABLED=0 \
GOOS=linux \
GOARCH="${GOARCH:-arm64}" \
GOCACHE="${GOCACHE:-/tmp/meliclaw-gocache}" \
GOMODCACHE="${GOMODCACHE:-/tmp/meliclaw-gomodcache}" \
go build -o docker/weed ./weed

echo "Building Docker image ${IMAGE_TAG}..."
docker build -f docker/Dockerfile.local -t "$IMAGE_TAG" docker

echo "Built ${IMAGE_TAG}"
