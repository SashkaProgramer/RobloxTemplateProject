# Technical Specification

## 1. Purpose and scope

This document defines the technical baseline of `[Project Name]`.

## 2. Runtime architecture

- Platform: Roblox (Luau).
- Project model sync: Rojo (`default.project.json`).
- Logical layers:
  - `client`: local player logic, UI, input, camera, and presentation.
  - `server`: authoritative game logic, validation, rewards, progression, and world state.
  - `shared`: contracts, constants, configuration, and pure modules shared between client and server.

### 2.1 Rojo Mapping

Source-to-Datamodel mapping is declared in `default.project.json`.

Document the current mapping here, for example:

- `src/shared` -> `ReplicatedStorage/Shared`
- `Packages` -> `ReplicatedStorage/Packages`
- `src/server` -> `ServerScriptService/Server`
- `Packages` -> `ServerScriptService/ServerPackages`
- `src/client` -> `StarterPlayer/StarterPlayerScripts/Client`

## 3. Current code structure

### 3.1 Client

- `src/client/[entrypoint].client.luau`
  - Client entrypoint script.
- `src/client/[feature module].luau`
  - `[Short purpose description]`

### 3.2 Server

- `src/server/[entrypoint].server.luau`
  - Server entrypoint script.
- `src/server/[service name].luau`
  - `[Short purpose description]`
- `src/server/[service name].luau`
  - `[Short purpose description]`

### 3.3 Shared

- `src/shared/[module name].luau`
  - `[Short purpose description]`
- `src/shared/[module name].luau`
  - `[Short purpose description]`

## 4. Dependencies and toolchain

- Package manager: Wally (`wally.toml`).
- Formatting: StyLua (`rokit.toml`).
- Linting: Selene (`selene.toml`).
- Tool version pinning: Rokit (`rokit.toml`).
- Additional tools: `[tests / generators / package types / custom scripts]`

## 5. Event and authority rules

- Client-side presentation and input handling run in `LocalScript`.
- Any gameplay-significant state change must be performed server-side.
- Client-to-server actions must use remotes with strict server validation.
- Inventory, economy, progression, rewards, and purchases must never trust the client.
- Shared modules should avoid hidden side effects where possible.

## 6. Coding conventions

- Keep modules single-responsibility by domain.
- Prefer explicit module APIs over implicit globals.
- Avoid tight coupling between presentation code and gameplay logic.
- Prefer reusable services and config modules over duplicated constants.
- Document any non-obvious replication or networking assumptions.

## 7. Build and run workflow

1. Install toolchain dependencies with `rokit install`.
2. Install package dependencies with `wally install`.
3. Start Rojo server with `rojo serve`.
4. Connect Roblox Studio to Rojo and sync.
5. Run Play mode to verify client/server entrypoints.

## 8. Open technical decisions

- `[Decision or risk]`
- `[Decision or risk]`
- `[Decision or risk]`
