# Technical Specification

## 1. Purpose and scope

This document defines the technical baseline of `RobloxTemplateProject`.

## 2. Runtime architecture

- Platform: Roblox (Luau).
- Project model sync: Rojo (`default.project.json`).
- Logical layers:
  - `client`: local player logic, UI, local input and presentation.
  - `server`: authoritative game logic and secure state changes.
  - `shared`: contracts, constants, pure modules shared between client and server.

### 2.1 Rojo Mapping

Source-to-Datamodel mapping is declared in `default.project.json`:
- `src/shared` -> `ReplicatedStorage/Shared`
- `Packages` -> `ReplicatedStorage/Packages`
- `src/server` -> `ServerScriptService/Server`
- `Packages` -> `ServerScriptService/ServerPackages`
- `src/client` -> `StarterPlayer/StarterPlayerScripts/Client`

## 3. Current code structure

### 3.1 Client

- `src/client/init.client.luau`
  - Client entrypoint script.

### 3.2 Server

- `src/server/init.server.luau`
  - Server entrypoint script.
- `src/server/InfectedService.luau`
  - Server-side infected spawning or behaviour service.
- `src/server/LootService.luau`
  - Server-side loot distribution service.
- `src/server/PlayerStateService.luau`
  - Server-side player state management service.
- `src/server/WeaponService.luau`
  - Server-side weapon logic and validation service.
- `src/server/WorldService.luau`
  - Server-side world state and encounter management service.

### 3.3 Shared

- `src/shared/GameConfig.luau`
  - Shared gameplay configuration and constants.
- `src/shared/Net.luau`
  - Shared networking contracts or remote access helpers.

## 4. Dependencies and toolchain

- Package manager: Wally (`wally.toml`).
- Formatting: StyLua (`rokit.toml`).
- Linting: Selene.
- Tool version pinning: Rokit.

## 5. Event and authority rules

- Client-side presentation and input handling run in `LocalScript`.
- Any gameplay-significant state change (economy, inventory, progression, rewards) must be performed server-side.
- Client-to-server actions must use `RemoteEvent` and strict server validation.

## 6. Coding conventions

- Keep modules single-responsibility by domain (client/server/shared separation).
- Keep shared modules side-effect free where possible.
- Prefer explicit module APIs over implicit globals.
- Avoid tight coupling between presentation code and gameplay logic.

## 7. Build and run workflow

1. Start Rojo server (`rojo serve`) in project root.
2. Connect Roblox Studio to Rojo and sync.
3. Run Play mode to verify client/server entrypoints.
