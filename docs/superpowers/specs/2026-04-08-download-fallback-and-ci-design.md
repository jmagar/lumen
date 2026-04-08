# Download Fallback and Cross-Platform CI

**Date:** 2026-04-08
**Issue:** [ory/lumen#110](https://github.com/ory/lumen/issues/110)
**Status:** Draft

## Problem

The plugin startup scripts (`scripts/run.sh`, `scripts/run.bat`) read the
version from `.release-please-manifest.json` and construct a GitHub release
download URL. If that version has not been released yet (release-please bumps the
manifest before the release workflow completes, or the release job fails), the
download 404s and the plugin fails to start with no recovery path.

There is also no CI coverage verifying that the download scripts actually work
end-to-end on any platform.

## Goals

1. Make the download scripts resilient to manifest/release version mismatches by
   falling back to the latest published release.
2. Add a `version` subcommand so CI (and users) can verify the downloaded binary
   is functional.
3. Add cross-platform CI tests (Linux, macOS, Windows) that exercise the real
   download path against published GitHub releases.

## Non-Goals

- Changing the release-please workflow or manifest management.
- Caching downloaded binaries across CI runs.
- Supporting private repositories or authenticated downloads in the scripts.

## Design

### 1. Fallback in `scripts/run.sh`

The current download block (lines 33-57) attempts a single `curl -fL` for the
manifest-pinned version. The change wraps this in a fallback:

```
1. Read VERSION from .release-please-manifest.json (existing logic)
2. Attempt curl -fL for VERSION
3. If curl fails (non-zero exit):
   a. Log warning to stderr: "Version $VERSION not found, resolving latest release..."
   b. Query GitHub API: curl -sfL https://api.github.com/repos/ory/lumen/releases/latest
   c. Parse tag_name with sed (no jq dependency): sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
   d. If tag_name resolved, retry download with the new version
   e. If API call also fails, exit 1 with error message
```

The fallback only activates on download failure, preserving the current
deterministic manifest-first behavior when releases are healthy.

### 2. Fallback in `scripts/run.bat`

Same logic adapted for Windows batch scripting:

- Use `curl -sfL` to hit the GitHub API endpoint on download failure.
- Parse the JSON response using `findstr` and string manipulation (no external
  JSON tools).
- Retry download with the resolved version.

### 3. `cmd/version.go` — Version Subcommand

New file with a simple `version` subcommand:

```go
package cmd

var buildVersion = "dev"

func init() {
    rootCmd.AddCommand(&cobra.Command{
        Use:   "version",
        Short: "Print the lumen version",
        Run: func(cmd *cobra.Command, args []string) {
            fmt.Println(buildVersion)
        },
    })
}
```

The `buildVersion` variable defaults to `"dev"` and is overridden at build time
via ldflags.

### 4. `.goreleaser.yml` — Ldflags Update

Add version injection to all four build targets:

```yaml
ldflags:
  - -s -w -X github.com/ory/lumen/cmd.buildVersion={{.Version}}
```

This ensures released binaries report their actual version.

### 5. `scripts/test_run.sh` — Offline Fallback Tests

Add test cases to the existing test script:

- **Fallback URL construction**: Given a resolved latest tag, verify the
  constructed download URL matches the expected pattern.
- **Version parsing from API response**: Given a mock JSON string containing
  `"tag_name": "v1.2.3"`, verify `sed` extracts `v1.2.3`.

These tests remain fully offline (no HTTP calls).

### 6. `.github/workflows/ci.yml` — Download Job

New `download` job added to the existing CI workflow:

```yaml
download:
  name: Download (${{ matrix.os }})
  runs-on: ${{ matrix.os }}
  if: github.actor != 'release-please[bot]'
  strategy:
    matrix:
      os: [ubuntu-latest, macos-latest, windows-latest]
  steps:
    - uses: actions/checkout@v4

    # Happy path: set manifest to real latest release, download, verify
    - name: Get latest release tag
      id: latest
      run: |
        TAG=$(curl -sfL https://api.github.com/repos/ory/lumen/releases/latest \
          | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        echo "tag=$TAG" >> "$GITHUB_OUTPUT"
        echo "version=${TAG#v}" >> "$GITHUB_OUTPUT"
      shell: bash

    - name: Set manifest to latest release
      run: printf '{\n  ".": "%s"\n}\n' "${{ steps.latest.outputs.version }}" > .release-please-manifest.json
      shell: bash

    - name: Download via run script (happy path)
      run: scripts/run.sh version
      shell: bash
      if: runner.os != 'Windows'

    - name: Download via run.bat (happy path)
      run: scripts\run.bat version
      shell: cmd
      if: runner.os == 'Windows'

    # Fallback path: set manifest to nonexistent version, verify fallback
    - name: Clear downloaded binary
      run: rm -rf bin/
      shell: bash

    - name: Set manifest to nonexistent version
      run: printf '{\n  ".": "99.99.99"\n}\n' > .release-please-manifest.json
      shell: bash

    - name: Download via run script (fallback path)
      run: scripts/run.sh version
      shell: bash
      if: runner.os != 'Windows'

    - name: Download via run.bat (fallback path)
      run: scripts\run.bat version
      shell: cmd
      if: runner.os == 'Windows'
```

Key properties:
- Uses `GITHUB_TOKEN` implicitly (GitHub Actions provides it), avoiding
  unauthenticated rate limits.
- Tests both the happy path (manifest matches a real release) and the fallback
  path (manifest points to a nonexistent version).
- Verifies the binary is functional by running `lumen version`.
- Runs on all three platforms with `run.bat` for Windows and `run.sh` for
  Linux/macOS.

## File Changes Summary

| File | Change |
|------|--------|
| `scripts/run.sh` | Add fallback block after failed download |
| `scripts/run.bat` | Add fallback block after failed download |
| `scripts/test_run.sh` | Add offline tests for fallback logic |
| `cmd/version.go` | New file: `version` subcommand |
| `.goreleaser.yml` | Add ldflags for version injection |
| `.github/workflows/ci.yml` | New `download` job with 3-OS matrix |

## Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| GitHub API rate limit (60/hr unauthenticated) | Fallback only fires when manifest version is missing; CI uses `GITHUB_TOKEN` for authenticated requests |
| Latest release binary is incompatible with shipped plugin code | Unlikely for patch versions; the alternative (hard crash) is worse. Log a warning so users know they got a fallback version |
| `sed` JSON parsing is fragile | The GitHub API response format for `tag_name` is stable; test covers the parsing |
| Windows `findstr` parsing edge cases | Test the happy and fallback paths in CI on actual Windows runners |
