# Meliclaw DSS Specs

This directory contains the technical and operational specs for Meliclaw Distributed Storage Systems.

## Current Specs

| Document | Purpose |
|---|---|
| `tech/Meliclaw_DSS_Deployment_Runbook.md` | Local install, Scaleway VPS deployment, support checks, maintenance, troubleshooting, and rollback. |
| `tech/Meliclaw_DSS_Operations_Spec.md` | SDD-style operational requirements and acceptance criteria for local and remote environments. |

## Operating Principles

- Keep deployment and maintenance changes spec-driven.
- Prefer small explicit scripts over hidden manual state.
- Keep the Scaleway VPS deployment tailnet-first.
- Preserve VetSync resources and data boundaries when sharing the VPS.
- Document every new port, secret, registry path, and recovery path before relying on it operationally.
