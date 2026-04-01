# Installing Lumen for OpenCode

Install Lumen as an OpenCode plugin from git. The plugin registers the shared
skills directory and a local MCP server automatically.

## Prerequisites

- [OpenCode.ai](https://opencode.ai) installed

## Installation

Add Lumen to the `plugin` array in your `opencode.json`:

```json
{
  "plugin": ["lumen@git+https://github.com/ory/lumen.git"]
}
```

Restart OpenCode. The plugin registers:

- the shared `skills/` directory from this repository
- a local `mcp.lumen` server that runs `scripts/run.sh stdio` on macOS/Linux
  and `scripts/run.cmd stdio` on Windows

## Verify

```bash
opencode mcp list
```

Then ask OpenCode to use the `doctor` or `reindex` skill, or call the Lumen
MCP tools directly.

## Updating

Restart OpenCode after updating the git ref in `opencode.json`, or pin a tag:

```json
{
  "plugin": ["lumen@git+https://github.com/ory/lumen.git#v0.0.26"]
}
```

## Uninstalling

Remove the `lumen@git+https://github.com/ory/lumen.git` entry from
`opencode.json` and restart OpenCode.
