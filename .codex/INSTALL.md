# Installing Lumen for Codex

Enable Lumen in Codex with native skill discovery. This no-MCP marketplace
variant does not register a bundled MCP server; it expects the Lumen MCP tools
to be available through your configured gateway, such as Labby.

## Prerequisites

- [Codex CLI](https://developers.openai.com/codex/cli)
- Git
- A configured Lumen MCP upstream in your gateway when you want live
  `semantic_search`, `index_status`, or `health_check` tools

## Installation

1. Install the plugin from the Dendrite marketplace, or clone the repository if
   you are wiring it manually:
   ```bash
   CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
   git clone https://github.com/jmagar/lumen.git "$CODEX_HOME/lumen"
   ```

2. Create the skills symlink for a manual install:
   ```bash
   mkdir -p "$HOME/.agents/skills"
   ln -s "$CODEX_HOME/lumen/skills" "$HOME/.agents/skills/lumen"
   ```

3. Ensure your gateway exposes the Lumen upstream, then restart Codex.

## Windows (PowerShell)

```powershell
$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE ".codex" }
git clone https://github.com/jmagar/lumen.git "$codexHome\lumen"
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.agents\skills" | Out-Null
cmd /c mklink /J "$env:USERPROFILE\.agents\skills\lumen" "$codexHome\lumen\skills"
```

## Migrating from the old repo-local plugin

If you previously used the repo-local Codex marketplace package:

1. Remove the old plugin from Codex's plugin UI.
2. Remove any old direct `codex mcp add lumen` registration if your gateway now
   provides Lumen.
3. Create the `~/.agents/skills/lumen` symlink for a manual install.
4. Restart Codex.

## Verify

```bash
ls -la "$HOME/.agents/skills/lumen"
```

## Updating

```bash
cd "${CODEX_HOME:-$HOME/.codex}/lumen" && git pull
```

## Uninstalling

```bash
rm "$HOME/.agents/skills/lumen"
```

Optionally delete the clone: `rm -rf "${CODEX_HOME:-$HOME/.codex}/lumen"`.
