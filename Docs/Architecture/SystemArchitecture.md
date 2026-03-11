# System Architecture

## Runtime Model

The project should follow a server-authoritative match architecture.

- `client`: presentation, input, HUD, local feedback
- `server`: match flow, loot authority, sabotage validation, threat logic, extraction rules
- `shared`: configs, definitions, remote names, data contracts

## Core Server Services

- `RoundService`
  - owns match phases, timers, start/end, extraction resolution
- `WorldService`
  - owns train cars, doors, power states, interactive objects
- `LootService`
  - owns loot definitions, spawn points, pickup/drop validation, loot valuation
- `PlayerStateService`
  - owns per-player round state and status flags
- `InfectedService`
  - owns PvE threat logic and noise-driven reactions
- `SabotageService`
  - owns sabotage requests and validation
- `RewardService`
  - owns post-match rewards and persistent currency

## Shared Modules

- `GameConfig`
- `Net`
- `RoundDefs`
- `LootDefs`
- `InteractionDefs`

## Architecture Principles

- Server decides all gameplay-significant outcomes.
- Clients request actions; they do not author outcomes.
- Modules should own one domain clearly.
- Match flow should not be split across multiple authorities.
