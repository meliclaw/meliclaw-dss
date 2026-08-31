# Meliclaw DSS - Deployment Runbook

This document is the operational contract for deploying Meliclaw Distributed Storage Systems (Meliclaw DSS). It follows the VetSync deployment pattern, adapted to a Go storage service.

## Scope

- Repository: `meliclaw/meliclaw-dss`
- Local runtime: Docker/OrbStack project `meliclaw-storage-management`
- Local container: `meliclaw-dss`
- Production host: Scaleway VPS reachable through Tailscale at `root@100.78.234.73`
- Registry target: Scaleway Container Registry `rg.nl-ams.scw.cloud/vetsync/meliclaw-dss`
- Architecture guardrails: Clean Architecture, SOLID, DRY, KISS
- Methodology: SDD/OpenSpec/onp-spec discipline for deploy changes

## Local Run

The local compose avoids the existing `meliclaw-storage-seaweedfs` ports by shifting host ports while keeping Meliclaw DSS internal defaults.

```bash
scripts/run-local-orbstack.sh
```

Endpoints:

| Service | URL |
|---|---|
| Admin UI | `http://127.0.0.1:23647` |
| S3 API | `http://127.0.0.1:18333` |
| Filer UI | `http://127.0.0.1:18889` |
| Master UI | `http://127.0.0.1:19334` |
| Volume UI | `http://127.0.0.1:19340` |
| WebDAV | `http://127.0.0.1:17333` |

## GitHub Actions

Workflow: `.github/workflows/meliclaw-dss-build-deploy.yml`

Pipeline:

```text
verify -> build -> deploy
```

- `verify`: runs admin tests and builds the Go binary.
- `build`: creates and pushes a `linux/arm64` image to Scaleway Container Registry for the Scaleway VPS, then scans it with Trivy.
- `deploy`: manual only, gated by `workflow_dispatch deploy=true`, then connects through Tailscale and runs the VPS blue/green script.

Required GitHub secrets:

| Secret | Purpose |
|---|---|
| `SCW_SECRET_KEY` | Scaleway Container Registry login |
| `TS_AUTHKEY` | Tailscale auth key for the GitHub runner |
| `DEPLOY_SSH_KEY` | Private SSH key accepted by the VPS |

## Image Security Scan

The build job runs `aquasecurity/trivy-action@v0.36.0` against the immutable image digest that was just pushed.

- Platform is pinned with `TRIVY_PLATFORM=linux/arm64`.
- Scan covers OS and library vulnerabilities.
- `CRITICAL` and `HIGH` vulnerabilities fail the build.
- `ignore-unfixed=true` avoids blocking on issues that do not yet have an upstream fix.

## VPS Layout

Expected production layout:

```text
/opt/meliclaw-dss/current -> checked-out release or deployment bundle
/opt/meliclaw-dss/current/scripts/deploy-web.sh
/opt/meliclaw-dss/current/scripts/smoke-meliclaw-dss.sh
/var/lib/meliclaw-dss/data
```

Manual deploy command:

```bash
ssh root@100.78.234.73 \
  "cd /opt/meliclaw-dss/current/scripts && ./deploy-web.sh rg.nl-ams.scw.cloud/vetsync/meliclaw-dss@sha256:<digest>"
```

## Blue/Green Ports

The deploy script alternates colors and binds to localhost only. A reverse proxy can point to the currently active ports recorded in `/opt/meliclaw-dss/ports/current.env`.

| Color | Admin | S3 | Filer | Master | Volume | WebDAV |
|---|---:|---:|---:|---:|---:|---:|
| blue | 23647 | 18333 | 18889 | 19334 | 19340 | 17333 |
| green | 23648 | 18334 | 18890 | 19335 | 19341 | 17334 |

## Smoke Test

`scripts/smoke-meliclaw-dss.sh` validates:

- Admin UI responds.
- S3 endpoint responds with the expected unauthenticated status.
- Master UI responds.
- Filer UI responds.

Failure aborts deployment before the old color is removed.

## SDD Acceptance Criteria

- AC-001: Local OrbStack run MUST use project/group `meliclaw-storage-management`.
- AC-002: Local run MUST NOT bind ports already used by `meliclaw-storage-seaweedfs`.
- AC-003: Production deploy MUST be blue/green and rollback-friendly.
- AC-004: CI MUST publish an immutable image reference by digest.
- AC-005: Deployment MUST happen over Tailscale SSH to the Scaleway VPS.
- AC-006: Operational scripts MUST stay small, explicit, and testable.
- AC-007: CI MUST run Trivy against the pushed image digest before deployment.
