# Modular Hospital Kit Plan

## Purpose

This plan defines how to replace the current repeated box-like hospital layout with a modular, authored hospital kit that is faster to build, easier to iterate, and better suited for a tense Roblox extraction loop.

The goal is not to build a full realistic hospital first.
The goal is to build a strong, scary, readable playable hospital slice for MVP.

## Build Strategy

- Build a modular kit, not one-off handcrafted rooms.
- Start with greybox-quality modules and verify gameplay before heavy art polish.
- Author one strong hospital route first.
- Add variation through dressing, blockers, lighting, and gameplay state, not through full procedural generation.

## Grid Rules

- Use one fixed build grid for all modules.
- Recommended base unit: `4 studs`.
- Keep module dimensions aligned to that grid.
- Keep floor height and door heights identical across the kit.
- Keep pivots predictable and consistent for all modules.

## Connector Standard

Lock this standard before building more content.

- `1 cell = 4 studs`
- Standard shell height: `3 cells = 12 studs`
- Standard door opening: `2 cells wide x 2 cells tall = 8 x 8 studs`
- Standard corridor clear width: `3 cells = 12 studs`
- Standard module depth should use `4-cell` increments where possible
- All connectors should sit on the same floor plane
- All forward-facing connectors should preserve the same local orientation

Recommended connector placement rules:

- Module pivot at floor center
- Forward connection on positive `Z`
- Back connection on negative `Z`
- Left/right branch connectors only on modules intentionally built for branching
- Door blockers should be centered on connector openings, not offset inside rooms

## Kit Layers

### 1. Shell

These modules define structure and navigation.

- Straight corridor
- Narrow emergency corridor
- T-junction
- Door frame module
- Ward shell
- Operating room shell
- Nurse station shell
- Pharmacy/storage shell
- Isolation room shell
- Stair or roof-access shell

### 2. Gameplay

These modules define interaction and flow.

- Door sockets
- Objective sockets
- Loot sockets
- Threat spawn sockets
- Sabotage sockets
- Extraction gate area
- Choke-point blockers

### 3. Dressing

These modules define atmosphere and variation.

- Beds
- Curtains
- Lockers
- Medicine shelves
- Gurneys
- Wheelchairs
- Ceiling lamps
- Broken panels
- Cable bundles
- Debris piles
- Blood trails
- Signage

## MVP Module Set

Build these first before expanding the kit:

1. `CorridorStraight_2x`
2. `CorridorNarrow_2x`
3. `CorridorTJunction`
4. `WardSmall`
5. `ReceptionDesk`
6. `SurgeryRoom`
7. `IsolationRoom`
8. `PharmacyRoom`
9. `RoofAccess`
10. `DoorFrameSecurity`

This is enough to build the first authored hospital route.

## Authoring Rules

- Every module should be a `Model`.
- Every module should have a `PrimaryPart`.
- Every module should use the same orientation convention.
- Keep connectors and openings readable.
- Avoid bespoke dimensions unless they are intentionally part of the kit.

Recommended attributes or tags for modules and sockets:

- `ZoneId`
- `ZoneDisplayName`
- `DoorSocket`
- `LootSocket`
- `ThreatSocket`
- `ObjectiveSocket`
- `SabotageSocket`
- `LightSocket`

## Module Contract

Treat each module as a reusable authored unit, not just geometry.

Required for every shell module:

- `Model` with `PrimaryPart`
- `ModuleId` attribute
- `ModuleType` attribute
- `FootprintX` attribute in grid cells
- `FootprintZ` attribute in grid cells
- `ConnectorCount` attribute

Recommended child folders:

- `Geometry`
- `Sockets`
- `Blockers`
- `Lights`
- `Markers`

Recommended connector markers:

- `Attachment` or small anchored marker part named `Connector_*`
- `ConnectorId` attribute
- `ConnectorDirection` attribute such as `North`, `South`, `East`, `West`
- `ConnectorKind` attribute such as `Corridor`, `Door`, `Gate`

Recommended gameplay socket markers:

- `LootSocket_*`
- `ThreatSocket_*`
- `ObjectiveSocket_*`
- `SabotageSocket_*`
- `LightSocket_*`

These should be marker parts or attachments with no gameplay authority by themselves.
Server systems should resolve and validate them.

## World Assembly Contract

The authored route should still produce a world shape that current services can understand.

Current server code already expects:

- zone models with `ZoneId`
- optional `ZoneDisplayName`
- door blockers with `DoorId`, `FromZoneId`, `ToZoneId`
- door state attributes `IsDoorOpen`, `IsDoorLocked`
- zone light parts with `ZoneLight = true`
- extraction gate with `GateId` and `IsGateOpen`
- objective parts using `InteractionId = recover_power` and `ObjectiveZoneId`

This means the first modular-kit pass should preserve those attributes even if the assembly method changes.
Do not rewrite `WorldService` first unless the module contract truly forces it.

## Route Design Rules

- Build one authored route with `5-7` sections for MVP.
- Do not try to build a full hospital campus first.
- Each section should have a clear gameplay identity.
- Each section should have one memorable landmark.
- Each section should support either pressure, loot, sabotage, or extraction progression.

Recommended section identities:

1. Triage
2. Surgery
3. Isolation
4. Pharmacy
5. Roof Access

## MVP Route Blueprint

Use one authored route with this progression:

1. `Triage`
   Safe onboarding, first obvious loot, clear forward door
2. `Surgery`
   Wider operating space, first strong landmark, first meaningful pressure
3. `Isolation`
   Tighter visibility, higher fear, strong door sabotage value
4. `Pharmacy`
   Denser loot space, more contested movement, objective pressure
5. `Roof Access`
   Narrow final push, readable extraction gate, decisive conflict

Support spaces between those landmarks should come from corridor modules, not custom ad hoc filler rooms.

## Layout Principles

- Early route should be readable and safe enough to onboard the player.
- Mid route should increase uncertainty and split pressure.
- Late route should narrow options and create decisive conflict.
- Long sightlines should be used intentionally, not everywhere.
- Choke points should be readable and contestable.
- Avoid maze-like confusion in MVP.

## Variation Strategy

Do not rely on making dozens of unique room meshes.
Reuse the same modules with different state and dressing.

Variation sources:

- Lighting on or off
- Door open or jammed
- Medical clutter level
- Debris level
- Blood and damage level
- Loot socket activation
- Objective socket activation
- Different blocker placement

## Workflow

1. Build modules in Roblox Studio on the fixed grid.
2. Assemble one playable route manually from the module set.
3. Validate movement, combat space, extraction pressure, and readability.
4. Add socket markers for loot, objectives, sabotage, and threats.
5. Add dressing pass after gameplay flow is proven.
6. Add tooling or assembly helpers only after the module standard is stable.

## Current Repository Status

The repository already contains a temporary linear hospital world in `src/server/HospitalWorldService.luau`.

That implementation is useful as a gameplay greybox because it already provides:

- `5` sequential zones
- zone signage and landmark flavor
- door blockers between zones
- objective prompts in middle zones
- extraction gate and extraction pad
- attributes consumed by `WorldService`

But it is still a disposable generator, not the final modular kit:

- dimensions are not yet locked to the final module grid
- room structure is authored in code instead of reusable Studio modules
- connectors are implicit rather than standardized
- sockets are partially hardcoded instead of kit-driven

Treat it as a transition scaffold, not as the permanent world-building method.

## Migration Plan

Move in these steps:

1. Lock the module grid and connector standard from this document.
2. Build the first shell modules in Studio as reusable `Model`s.
3. Recreate the current `5`-section route manually using those modules.
4. Preserve existing zone, door, light, objective, and extraction attributes so `WorldService` keeps working.
5. Replace hardcoded room geometry in `HospitalWorldService` with either:
   - a thin route assembler that places prebuilt modules, or
   - a static authored route already present in Workspace/ReplicatedStorage
6. Only after the route works, move loot/threat/objective placement to socket-driven spawn resolution.

## Immediate Build Order

Build these in Studio first:

1. `CorridorStraight_2x`
2. `CorridorNarrow_2x`
3. `CorridorTJunction`
4. `WardSmall`
5. `SurgeryRoom`
6. `IsolationRoom`
7. `PharmacyRoom`
8. `RoofAccess`
9. `DoorFrameSecurity`
10. `ReceptionDesk`

Then assemble the MVP route before adding more rooms.

## What Not To Do

- Do not build the entire hospital as one giant handcrafted map first.
- Do not start with final art polish before route readability is proven.
- Do not use fully procedural layout generation for the MVP critical path.
- Do not create one-off rooms with incompatible dimensions.
- Do not spend time on realism that does not improve tension or gameplay clarity.

## Recommended Next Steps

1. Update the temporary hospital dimensions to respect the locked `4-stud` module grid or mark them as deprecated.
2. Build the first `6-8` core modules in Studio using the module contract above.
3. Assemble one authored route that preserves current `ZoneId` and `DoorId` world attributes.
4. Move objective, loot, threat, and sabotage placement to explicit socket markers.
5. Only after that, decide whether a module assembler tool is worth implementing.

## Retrieval Note

If a future chat asks about the modular hospital kit, use this file as the primary project reference before proposing world-building changes.

For actual Studio assembly of the first building, use `Docs/Architecture/HospitalStudioBuildGuide.md`.
