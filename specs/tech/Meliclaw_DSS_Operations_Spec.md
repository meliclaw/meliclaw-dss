# Meliclaw DSS Operations Spec

## Status

Accepted for current single-node local and Scaleway VPS operation.

## Intent

Define the support, maintenance, and installation behavior expected for Meliclaw DSS in both local developer environments and the remote Scaleway VPS environment.

## Context

Meliclaw DSS is deployed as a containerized Go storage service. The production host is the existing Scaleway VPS used by VetSync, reachable through Tailscale. The project must remain easy to operate by following the same operational style as VetSync: explicit scripts, blue/green release, smoke tests, registry images, and documented recovery steps.

## Environments

| Environment | Purpose | Runtime | Access |
|---|---|---|---|
| Local | Development and validation | OrbStack/Docker Compose | `127.0.0.1` ports |
| VPS | Production-style remote deployment | Docker on Scaleway Ubuntu | Tailscale SSH and Tailscale Serve |
| GitHub Actions | Build, scan, publish, optional deploy | GitHub hosted runners | Secrets and Tailscale action |

## Local Requirements

- The local command MUST be `scripts/run-local-orbstack.sh`.
- The local Docker Compose project MUST be `meliclaw-storage-management`.
- The local container MUST be named `meliclaw-dss`.
- The local image SHOULD be `meliclaw/meliclaw-dss:local`.
- The local deployment MUST avoid port conflicts with any existing SeaweedFS container.
- The local smoke test MUST be executable with `scripts/smoke-meliclaw-dss.sh`.

## Remote Requirements

- The VPS root path MUST be `/opt/meliclaw-dss`.
- The checked-out repository path MUST be `/opt/meliclaw-dss/current`.
- Persistent data MUST live under `/var/lib/meliclaw-dss/data`.
- Deployment MUST be performed with `scripts/deploy-web.sh`.
- Deployment MUST accept an immutable digest reference.
- Deployment MAY accept `:latest` for manual recovery or testing.
- The active color MUST be written to `/opt/meliclaw-dss/current-color`.
- The active port map MUST be written to `/opt/meliclaw-dss/ports/current.env`.
- Candidate containers MUST be removed if smoke fails.
- The previous live container MUST remain available until the candidate passes smoke.

## Registry Requirements

- Registry endpoint MUST be `rg.nl-ams.scw.cloud`.
- Namespace MUST be `vetsync`.
- Image name MUST be `meliclaw-dss`.
- The full mutable tag is `rg.nl-ams.scw.cloud/vetsync/meliclaw-dss:latest`.
- Production deploys SHOULD use `rg.nl-ams.scw.cloud/vetsync/meliclaw-dss@sha256:<digest>`.
- The project MUST NOT delete or mutate the `vetsync-web` image because it belongs to VetSync.

## CI Requirements

- GitHub Actions MUST build for `linux/arm64`.
- The runtime binary MUST be built with `CGO_ENABLED=0 GOOS=linux GOARCH=arm64`.
- GitHub Actions MUST push both the commit SHA tag and `latest`.
- GitHub Actions MUST report the immutable image digest.
- GitHub Actions MUST run Trivy against the pushed digest.
- Trivy MUST fail the build for `CRITICAL` and `HIGH` findings unless the finding is unfixed upstream and explicitly tolerated by the workflow.
- Deployment from CI MUST be manually gated with `workflow_dispatch`.

## Access Requirements

- SSH deployment MUST go through Tailscale to `root@100.78.234.73`.
- Admin UI access MUST be tailnet-only by default.
- Tailscale Serve SHOULD proxy HTTPS 443 to the active local Admin port.
- Public internet exposure requires a separate reviewed spec.

## Maintenance Requirements

- Operators MUST be able to inspect active containers, logs, ports, image digests, and Tailscale Serve status from documented commands.
- Operators MUST be able to run smoke tests after every deploy.
- Operators SHOULD keep the current image digest plus at least one known-good rollback digest in Scaleway Container Registry.
- Operators SHOULD prune unused Docker images only after verifying the live container is healthy.
- Disk usage MUST be monitored because the shared VPS also contains VetSync data.
- VetSync WAL archive cleanup MUST be treated as VetSync/Postgres maintenance and requires backup/PITR awareness.

## Acceptance Criteria

- AC-001: A developer can start Meliclaw DSS locally with one script and see it in OrbStack under `meliclaw-storage-management`.
- AC-002: A developer can run smoke tests locally without manual port discovery.
- AC-003: A VPS operator can bootstrap `/opt/meliclaw-dss/current` from the GitHub repository.
- AC-004: A VPS operator can deploy a registry digest with `scripts/deploy-web.sh`.
- AC-005: Failed smoke tests do not replace the live color.
- AC-006: The active ports can be discovered from `/opt/meliclaw-dss/ports/current.env`.
- AC-007: The Admin UI can be reached through the Tailscale Serve URL after deployment.
- AC-008: The workflow blocks on high or critical Trivy findings.
- AC-009: The documentation explains how to distinguish `vetsync-web` from `meliclaw-dss` in the registry.
- AC-010: The documentation includes disk support commands and warns that `/srv/vetsync/pg-wal-archive` belongs to VetSync/Postgres.

## Non-Goals

- Multi-node Meliclaw DSS cluster orchestration.
- Public Admin UI exposure.
- Automated VetSync WAL archive deletion policy.
- Replacing VetSync deployment automation.
- Changing the underlying object storage behavior inherited from the upstream project.

## Operational References

- Runbook: `specs/tech/Meliclaw_DSS_Deployment_Runbook.md`
- Workflow: `.github/workflows/meliclaw-dss-build-deploy.yml`
- Local compose: `docker/meliclaw-dss-compose.yml`
- Local launcher: `scripts/run-local-orbstack.sh`
- Blue/green deploy: `scripts/deploy-web.sh`
- Smoke test: `scripts/smoke-meliclaw-dss.sh`
