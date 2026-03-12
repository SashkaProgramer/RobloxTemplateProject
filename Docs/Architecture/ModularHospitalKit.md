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

## What Not To Do

- Do not build the entire hospital as one giant handcrafted map first.
- Do not start with final art polish before route readability is proven.
- Do not use fully procedural layout generation for the MVP critical path.
- Do not create one-off rooms with incompatible dimensions.
- Do not spend time on realism that does not improve tension or gameplay clarity.

## Recommended Next Steps

1. Define the final module grid and connector standard.
2. Build the first `6-8` core modules in Studio.
3. Assemble one authored route from those modules.
4. Add gameplay sockets to the route.
5. Only after that, decide whether a module assembler tool is worth implementing.

## Retrieval Note

If a future chat asks about the modular hospital kit, use this file as the primary project reference before proposing world-building changes.
