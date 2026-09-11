# Meliclaw DSS - Deployment, Support, and Maintenance Runbook

This runbook is the operational contract for Meliclaw Distributed Storage Systems (Meliclaw DSS). It documents local installation, Scaleway VPS deployment, support routines, and maintenance tasks using the same discipline already used by VetSync.

## Scope

- Repository: `https://github.com/meliclaw/meliclaw-dss`
- Local runtime: Docker/OrbStack project `meliclaw-storage-management`
- Local container: `meliclaw-dss`
- Production host: Scaleway VPS reachable through Tailscale at `root@100.78.234.73`
- Production path: `/opt/meliclaw-dss/current`
- Production data path: `/var/lib/meliclaw-dss/data`
- Registry namespace: `rg.nl-ams.scw.cloud/vetsync`
- Registry image: `rg.nl-ams.scw.cloud/vetsync/meliclaw-dss`
- CPU architecture for VPS images: `linux/arm64`
- Architecture guardrails: Clean Architecture, SOLID, DRY, KISS
- Delivery methodology: SDD/OpenSpec/onp-spec discipline for deploy and operations changes

## Local Installation

From the repository root:

```bash
go version
scripts/run-local-orbstack.sh
scripts/smoke-meliclaw-dss.sh
```

The local helper builds `meliclaw/meliclaw-dss:local`, starts Docker Compose, and places the container in the OrbStack project/group `meliclaw-storage-management`.

Local endpoints:

| Service | URL |
|---|---|
| Admin UI | `http://127.0.0.1:23647` |
| S3 API | `http://127.0.0.1:18333` |
| Filer UI | `http://127.0.0.1:18889` |
| Master UI | `http://127.0.0.1:19334` |
| Volume UI | `http://127.0.0.1:19340` |
| WebDAV | `http://127.0.0.1:17333` |

Useful local commands:

```bash
docker compose -f docker/meliclaw-dss-compose.yml ps
docker compose -f docker/meliclaw-dss-compose.yml logs --tail=120
docker compose -f docker/meliclaw-dss-compose.yml down
```

The local port mapping intentionally avoids the existing `meliclaw-storage-seaweedfs` container ports.

## GitHub Actions

Workflow: `.github/workflows/meliclaw-dss-build-deploy.yml`

Pipeline:

```text
verify -> build -> deploy
```

- `verify`: runs admin tests and builds the Go binary.
- `build`: builds a static `linux/arm64` binary, creates the Docker image, pushes `:<commit-sha>` and `:latest` to Scaleway Container Registry, and scans the pushed digest with Trivy.
- `deploy`: manual only, gated by `workflow_dispatch deploy=true`, connects to the VPS through Tailscale, then runs the VPS blue/green deployment script.

Required GitHub secrets:

| Secret | Purpose |
|---|---|
| `SCW_SECRET_KEY` | Scaleway Container Registry login password/token |
| `TS_AUTHKEY` | Tailscale auth key for the GitHub runner |
| `DEPLOY_SSH_KEY` | Private SSH key accepted by the VPS |

The build step must keep the static compile flags:

```bash
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -o docker/weed ./weed
```

Without a static binary, the Alpine runtime image can fail on the VPS with:

```text
/entrypoint.sh: exec: line 118: /usr/bin/weed: not found
```

## Image Security Scan

The build job runs Trivy with:

- Action: `aquasecurity/trivy-action@v0.36.0`
- Platform: `TRIVY_PLATFORM=linux/arm64`
- Image reference: `${IMAGE_NAME}@${digest}`
- Vulnerability types: `os,library`
- Blocking severities: `CRITICAL,HIGH`
- `ignore-unfixed=true`

If Trivy fails, do not deploy the image until the finding is reviewed. Prefer rebuilding from patched base images or patched Go dependencies before suppressing anything.

## First VPS Installation

On the Scaleway VPS:

```bash
mkdir -p /opt/meliclaw-dss /var/lib/meliclaw-dss/data
cd /opt/meliclaw-dss
git clone https://github.com/meliclaw/meliclaw-dss.git current
cd /opt/meliclaw-dss/current
chmod +x scripts/deploy-web.sh scripts/smoke-meliclaw-dss.sh
docker login rg.nl-ams.scw.cloud -u nologin --password-stdin
```

Then deploy an image by digest when possible:

```bash
/opt/meliclaw-dss/current/scripts/deploy-web.sh \
  rg.nl-ams.scw.cloud/vetsync/meliclaw-dss@sha256:<digest>
```

For manual recovery/testing only, `:latest` is also accepted:

```bash
/opt/meliclaw-dss/current/scripts/deploy-web.sh \
  rg.nl-ams.scw.cloud/vetsync/meliclaw-dss:latest
```

## Blue/Green Deployment

The script `scripts/deploy-web.sh` alternates between `meliclaw-dss-blue` and `meliclaw-dss-green`.

| Color | Admin | S3 | Filer | Master | Volume | WebDAV |
|---|---:|---:|---:|---:|---:|---:|
| blue | 23647 | 18333 | 18889 | 19334 | 19340 | 17333 |
| green | 23648 | 18334 | 18890 | 19335 | 19341 | 17334 |

The script:

1. Pulls the requested image.
2. Removes any stale candidate container for the next color.
3. Starts the candidate bound to `127.0.0.1` only.
4. Runs `scripts/smoke-meliclaw-dss.sh` against the candidate ports.
5. Writes the active color to `/opt/meliclaw-dss/current-color`.
6. Writes active ports to `/opt/meliclaw-dss/ports/current.env`.
7. Removes the old color only after smoke succeeds.

If smoke fails, the candidate container is removed and the old live color is kept.

## Tailnet Admin Access

The production Admin UI is exposed inside the Tailscale tailnet with Tailscale Serve. It is not exposed directly to the public internet.

Current tailnet URL:

```text
https://vetsync-vet-br-prd.tail48dc0d.ts.net/
```

Enable or update the proxy:

```bash
tailscale serve --bg --https=443 http://127.0.0.1:23647
```

Check status:

```bash
tailscale serve status
```

Disable:

```bash
tailscale serve --https=443 off
```

When the live color changes to green, update Tailscale Serve to the green Admin port:

```bash
source /opt/meliclaw-dss/ports/current.env
tailscale serve --bg --https=443 "http://127.0.0.1:${MELICLAW_DSS_ADMIN_PORT}"
```

## Smoke Test

Default local smoke:

```bash
scripts/smoke-meliclaw-dss.sh
```

VPS smoke against active ports:

```bash
source /opt/meliclaw-dss/ports/current.env
BASE_ADMIN="http://127.0.0.1:${MELICLAW_DSS_ADMIN_PORT}" \
BASE_S3="http://127.0.0.1:${MELICLAW_DSS_S3_PORT}" \
BASE_MASTER="http://127.0.0.1:${MELICLAW_DSS_MASTER_PORT}" \
BASE_FILER="http://127.0.0.1:${MELICLAW_DSS_FILER_PORT}" \
  /opt/meliclaw-dss/current/scripts/smoke-meliclaw-dss.sh
```

S3 can return `403` when unauthenticated access is denied; the smoke script treats any connected non-`000` status as healthy for S3.

## Support Checks

Container state:

```bash
docker ps -a --filter name=meliclaw-dss --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
docker inspect meliclaw-dss-blue --format '{{.State.Status}} {{.State.ExitCode}} {{.State.Error}}'
docker inspect meliclaw-dss-green --format '{{.State.Status}} {{.State.ExitCode}} {{.State.Error}}'
```

Logs:

```bash
docker logs meliclaw-dss-blue --tail 120
docker logs meliclaw-dss-green --tail 120
```

Active release:

```bash
cat /opt/meliclaw-dss/current-color
cat /opt/meliclaw-dss/ports/current.env
docker image inspect rg.nl-ams.scw.cloud/vetsync/meliclaw-dss:latest \
  --format '{{.Os}}/{{.Architecture}} {{index .RepoDigests 0}}'
```

Network:

```bash
docker network inspect meliclaw-dss-net
tailscale status
tailscale serve status
```

## Rollback

Preferred rollback is to redeploy a known-good immutable digest:

```bash
/opt/meliclaw-dss/current/scripts/deploy-web.sh \
  rg.nl-ams.scw.cloud/vetsync/meliclaw-dss@sha256:<known-good-digest>
```

Do not rely on `:latest` for rollback unless the registry state has already been verified.

## Disk Maintenance

Check available disk:

```bash
df -h /
```

Find top-level disk usage without crossing filesystems:

```bash
du -xhd1 / | sort -h
du -xhd1 /srv | sort -h
du -xhd1 /var | sort -h
du -xhd1 /var/lib/docker | sort -h
```

Docker usage:

```bash
docker system df -v
docker image prune -a
```

Only run `docker image prune -a` when the active containers are healthy, because it removes unused images that could otherwise be useful for quick local rollback.

VetSync WAL archives have previously used most of the VPS disk under:

```text
/srv/vetsync/pg-wal-archive
```

Retention example, keeping five days:

```cron
0 * * * * find /srv/vetsync/pg-wal-archive -type f -mtime +5 -delete >/dev/null 2>&1
```

Before deleting WAL archives, confirm the VetSync backup/PITR policy. Those files belong to VetSync/Postgres, not Meliclaw DSS.

## Registry Maintenance

In Scaleway Container Registry:

- Keep `vetsync-web`; it belongs to the VetSync application.
- Keep `meliclaw-dss:latest`.
- Keep the current Meliclaw DSS digest and at least one known-good rollback digest.
- Old unreferenced Meliclaw DSS versions can be deleted after a successful deployment and smoke test.

The active image should be checked on the VPS before deleting registry versions:

```bash
docker ps --filter name=meliclaw-dss --format '{{.Names}} {{.Image}}'
docker inspect "$(docker ps --filter name=meliclaw-dss --format '{{.Names}}' | head -1)" \
  --format '{{.Image}}'
```

## Troubleshooting

### Pull Access Denied

Symptom:

```text
pull access denied ... repository does not exist or may require docker login
```

Checks:

- Registry endpoint must be `rg.nl-ams.scw.cloud`.
- Namespace must be `vetsync`, not `meliclaw`.
- Image must be `meliclaw-dss`.
- Login must use `nologin` plus a valid Scaleway token.

Correct image:

```text
rg.nl-ams.scw.cloud/vetsync/meliclaw-dss:latest
```

### Image Not Found

Symptom:

```text
rg.nl-ams.scw.cloud/vetsync/meliclaw-dss:latest: not found
```

Cause: the image tag has not been pushed, or the workflow pushed to a different namespace/image.

Fix: verify the GitHub Actions build succeeded and inspect the Scaleway `vetsync/meliclaw-dss` image list.

### Container Restarts With `/usr/bin/weed: not found`

Cause: the binary inside the Alpine runtime image is dynamically linked for a loader not present in the image.

Fix: build the binary statically in CI:

```bash
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -o docker/weed ./weed
```

### Smoke Fails With `000`

`000` means curl could not connect. Check:

```bash
docker ps -a --filter name=meliclaw-dss
docker logs meliclaw-dss-blue --tail 120
docker logs meliclaw-dss-green --tail 120
cat /opt/meliclaw-dss/ports/current.env
```

### Tailscale URL Opens The Wrong Color

Check active ports:

```bash
cat /opt/meliclaw-dss/ports/current.env
tailscale serve status
```

Then repoint Tailscale Serve:

```bash
source /opt/meliclaw-dss/ports/current.env
tailscale serve --bg --https=443 "http://127.0.0.1:${MELICLAW_DSS_ADMIN_PORT}"
```

## SDD Acceptance Criteria

- AC-001: Local OrbStack run MUST use project/group `meliclaw-storage-management`.
- AC-002: Local run MUST NOT bind ports already used by `meliclaw-storage-seaweedfs`.
- AC-003: Production deploy MUST be blue/green and rollback-friendly.
- AC-004: CI MUST publish an immutable image reference by digest.
- AC-005: Deployment MUST happen over Tailscale SSH to the Scaleway VPS.
- AC-006: Operational scripts MUST stay small, explicit, and testable.
- AC-007: CI MUST run Trivy against the pushed image digest before deployment.
- AC-008: Production Admin UI MUST stay tailnet-only unless a separate public exposure spec is approved.
- AC-009: Support documentation MUST include local run, remote install, smoke test, rollback, disk maintenance, and registry cleanup procedures.
