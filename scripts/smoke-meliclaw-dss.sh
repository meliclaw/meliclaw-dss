#!/usr/bin/env bash
set -euo pipefail

BASE_ADMIN="${BASE_ADMIN:-http://127.0.0.1:23647}"
BASE_S3="${BASE_S3:-http://127.0.0.1:18333}"
BASE_MASTER="${BASE_MASTER:-http://127.0.0.1:19334}"
BASE_FILER="${BASE_FILER:-http://127.0.0.1:18889}"

failures=0

check_http() {
  local name="$1"
  local url="$2"
  local expected="${3:-200}"
  local code
  code="$(curl -fsS -o /dev/null -w '%{http_code}' "$url" || true)"
  if [ "$code" = "$expected" ]; then
    echo "ok: ${name} (${url})"
  else
    echo "fail: ${name} (${url}) expected ${expected}, got ${code:-none}" >&2
    failures=$((failures + 1))
  fi
}

check_http "admin" "$BASE_ADMIN/"
check_http "s3" "$BASE_S3/" "403"
check_http "master" "$BASE_MASTER/"
check_http "filer" "$BASE_FILER/"

if [ "$failures" -ne 0 ]; then
  echo "smoke: ${failures} failure(s)" >&2
  exit 1
fi

echo "smoke: 0 failure(s)"
