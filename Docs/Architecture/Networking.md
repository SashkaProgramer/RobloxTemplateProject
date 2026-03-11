# Networking

## Principle

Clients only request interactions. The server validates position, phase, cooldowns, ownership, and result.

## Candidate Remotes

### Server to Client

- `RoundStateChanged`
- `RoundTimerUpdated`
- `PlayerRoundStateChanged`
- `InventoryUpdated`
- `SabotageFeedback`
- `ExtractionStateChanged`
- `MatchResult`

### Client to Server

- `RequestInteract`
- `RequestPickupLoot`
- `RequestDropLoot`
- `RequestUseItem`
- `RequestSabotage`
- `RequestExtract`

## Validation Rules

- The player must be alive.
- The player must be near the target object.
- The requested interaction must exist on the server.
- The action must be legal in the current phase.
- Cooldowns and resource costs must be enforced server-side.
