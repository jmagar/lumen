# Installing Lumen for Codex

Enable Lumen in Codex with native skill discovery plus a registered MCP
server.

## Prerequisites

- [Codex CLI](https://developers.openai.com/codex/cli)
- Git

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/ory/lumen.git ~/.codex/lumen
   ```

2. Create the skills symlink:
   ```bash
   mkdir -p ~/.agents/skills
   ln -s ~/.codex/lumen/skills ~/.agents/skills/lumen
   ```

3. Register the MCP server:
   ```bash
   codex mcp add lumen -- ~/.codex/lumen/scripts/run.cmd stdio
   ```

4. Restart Codex.

## Windows (PowerShell)

```powershell
git clone https://github.com/ory/lumen.git "$env:USERPROFILE\.codex\lumen"
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.agents\skills" | Out-Null
cmd /c mklink /J "$env:USERPROFILE\.agents\skills\lumen" "$env:USERPROFILE\.codex\lumen\skills"
codex mcp add lumen -- "$env:USERPROFILE\.codex\lumen\scripts\run.cmd" stdio
```

## Migrating from the old repo-local plugin

If you previously used the repo-local Codex marketplace package:

1. Remove the old plugin from Codex's plugin UI.
2. Register the MCP server with `codex mcp add` as above.
3. Create the `~/.agents/skills/lumen` symlink.
4. Restart Codex.

## Verify

```bash
codex mcp get lumen
ls -la ~/.agents/skills/lumen
```

## Updating

```bash
cd ~/.codex/lumen && git pull
```

## Uninstalling

```bash
codex mcp remove lumen
rm ~/.agents/skills/lumen
```

Optionally delete the clone: `rm -rf ~/.codex/lumen`.
