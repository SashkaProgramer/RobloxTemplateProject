# RobloxTemplateProject

A clean, public Roblox starter template for teams and solo developers.

Build with Luau, sync with Rojo, manage tools with Rokit, and scale from prototype to production without rebuilding your project structure.

## Why this template

- Clear `client/server/shared` architecture from day one
- Pinned CLI tool versions for reproducible setup
- Minimal defaults with no forced gameplay dependencies
- Ready to clone and start coding immediately

## What is included

- Rojo project mapping in `default.project.json`
- Standard source layout: `src/client`, `src/server`, `src/shared`
- Pinned CLI toolchain in `rokit.toml`
- Luau linting with `selene.toml`
- Wally package setup in `wally.toml`

## Prerequisites

Install these tools first:

1. Roblox Studio
2. Git
3. VS Code
4. Rokit

Install Rokit on Windows (PowerShell):

```powershell
Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression
```

## Quick start

Run from the repository root:

```powershell
rokit install
wally install
rojo serve
```

Then in Roblox Studio:

1. Open your place file.
2. Connect to Rojo.
3. Verify the tree synced.
4. Start Play mode.

## Common commands

```powershell
wally install
selene src
```

## Recommended VS Code extensions

1. `JohnnyMorganz.stylua`
2. `JohnnyMorganz.luau-lsp`
3. `evaera.vscode-rojo`
4. `Kampfkarren.selene-vscode` (optional, inline lint diagnostics)

## Project structure

- `src/client` - local player scripts, UI, input
- `src/server` - authoritative gameplay logic
- `src/shared` - shared modules, constants, contracts
- `Docs` - template documentation

## Optional dependencies

This template ships with no gameplay dependencies by default.

Add common packages when needed:

```powershell
wally add evaera/promise@4.0.0
wally add --server alreadypro/profileservice@1.0.4
```

## License

MIT. See `LICENSE`.

## Documentation

- `Docs/ProjectOverview.md`
- `Docs/TechnicalSpec.md`
