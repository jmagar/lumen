# AGENTS.md

## Repository Expectations

- The repo root is the Claude Code plugin surface. Keep `.claude-plugin/`, `hooks/`, `skills/`, and `scripts/` compatible with Claude.
- The Codex plugin surface lives under `plugins/lumen/`. Keep Codex-only manifests, skills, and wrappers isolated there.
- Do not add a repo-root `.mcp.json` or repo-root `.codex-plugin/`. Claude Code reads repo-root `.mcp.json` as project-scoped MCP config, which would change behavior for this repository.
- When changing plugin metadata for releases, keep `.claude-plugin/plugin.json` and `plugins/lumen/.codex-plugin/plugin.json` aligned unless a difference is intentionally product-specific.

## Commands

- `make build-local` builds the local binary.
- `make test` runs the Go test suite.
- `make lint` runs `golangci-lint`.
