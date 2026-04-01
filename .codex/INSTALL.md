# Installing Lumen for Codex

Enable Lumen in Codex with native skill discovery plus a registered MCP
server.

## Prerequisites

- [Codex CLI](https://developers.openai.com/codex/cli)
- Git

## Installation

1. Clone the repository:
   ```bash
   CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
   git clone https://github.com/ory/lumen.git "$CODEX_HOME/lumen"
   ```

2. Create the skills symlink:
   ```bash
   mkdir -p "$CODEX_HOME/skills"
   ln -s "$CODEX_HOME/lumen/skills" "$CODEX_HOME/skills/lumen"
   ```

3. Register the MCP server:
   ```bash
   codex mcp add lumen -- "$CODEX_HOME/lumen/scripts/run.sh" stdio
   ```

4. Restart Codex.

## Windows (PowerShell)

```powershell
$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE ".codex" }
git clone https://github.com/ory/lumen.git "$codexHome\lumen"
New-Item -ItemType Directory -Force -Path "$codexHome\skills" | Out-Null
cmd /c mklink /J "$codexHome\skills\lumen" "$codexHome\lumen\skills"
codex mcp add lumen -- "$codexHome\lumen\scripts\run.cmd" stdio
```

## Migrating from the old repo-local plugin

If you previously used the repo-local Codex marketplace package:

1. Remove the old plugin from Codex's plugin UI.
2. Register the MCP server with `codex mcp add` as above.
3. Create the `$CODEX_HOME/skills/lumen` symlink.
4. Restart Codex.

## Verify

```bash
codex mcp get lumen
ls -la "${CODEX_HOME:-$HOME/.codex}/skills/lumen"
```

## Updating

```bash
cd "${CODEX_HOME:-$HOME/.codex}/lumen" && git pull
```

## Uninstalling

```bash
codex mcp remove lumen
rm "${CODEX_HOME:-$HOME/.codex}/skills/lumen"
```

Optionally delete the clone: `rm -rf "${CODEX_HOME:-$HOME/.codex}/lumen"`.
