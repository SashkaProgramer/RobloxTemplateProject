# Hospital Studio Build Guide

## Purpose

This guide defines how to assemble the first playable hospital building in Roblox Studio using the modular hospital kit plan.

Use this together with `Docs/Architecture/ModularHospitalKit.md`.

The target is one authored MVP route that already works with current server code expectations.

## Studio Folder Targets

Use this structure in Studio:

- `Workspace/HospitalRaidWorld`
- `ReplicatedStorage`
- `ReplicatedStorage/HospitalModules`

Recommended module library structure:

- `ReplicatedStorage/HospitalModules/Shell`
- `ReplicatedStorage/HospitalModules/Gameplay`
- `ReplicatedStorage/HospitalModules/Dressing`

Route assembly target:

- `Workspace/HospitalRaidWorld/Zone_01`
- `Workspace/HospitalRaidWorld/Zone_02`
- `Workspace/HospitalRaidWorld/Zone_03`
- `Workspace/HospitalRaidWorld/Zone_04`
- `Workspace/HospitalRaidWorld/Zone_05`

Keep all runtime parts for the first route under `Workspace/HospitalRaidWorld` so current services can register them.

## Fixed Build Standard

- Grid snap: `4`
- Rotation snap: `90`
- Floor height: `0`
- Shell height: `12 studs`
- Standard door opening: `8 x 8 studs`
- Standard corridor clear width: `12 studs`

Pivot rule:

- Every module pivot should sit at floor center.
- Forward direction should face positive `Z`.

## First Module List

Build these first as reusable Studio models:

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

Recommended footprint targets:

- `CorridorStraight_2x`: `12 x 16`
- `CorridorNarrow_2x`: `8 x 16`
- `CorridorTJunction`: `16 x 16`
- `WardSmall`: `24 x 24`
- `ReceptionDesk`: `24 x 16`
- `SurgeryRoom`: `24 x 24`
- `IsolationRoom`: `24 x 24`
- `PharmacyRoom`: `24 x 24`
- `RoofAccess`: `24 x 24`
- `DoorFrameSecurity`: `8 x 4`

## Required Attributes

For each shell module model:

- `ModuleId`
- `ModuleType`
- `FootprintX`
- `FootprintZ`
- `ConnectorCount`

For each zone root model in the assembled world:

- `ZoneId`
- `ZoneDisplayName`

For each door blocker:

- `DoorId`
- `FromZoneId`
- `ToZoneId`
- `IsDoorOpen`
- `IsDoorLocked`

For light parts inside zones:

- `ZoneLight = true`

For objective parts:

- `InteractionId = recover_power`
- `ObjectiveZoneId = Zone_02`, `Zone_03`, or `Zone_04`

For the extraction gate:

- `GateId = ExtractionGate`
- `IsGateOpen = false`

For the extraction pad:

- `InteractionId = extract`
- `ExtractionPad = true`

## Zone Assembly Plan

Build one linear route with `5` zones.

Recommended sequence:

1. `Zone_01` -> `Triage`
2. `Zone_02` -> `Surgery`
3. `Zone_03` -> `Isolation`
4. `Zone_04` -> `Pharmacy`
5. `Zone_05` -> `Roof Access`

Each zone should be one `Model` with a clear floor part set as `PrimaryPart`.

## Placement Layout

Use these route anchors for a first manual assembly:

- `Zone_01` center at `(0, 0, 0)`
- `Door_01` center at `(0, 4, 16)`
- `Zone_02` center at `(0, 0, 32)`
- `Door_02` center at `(0, 4, 48)`
- `Zone_03` center at `(0, 0, 64)`
- `Door_03` center at `(0, 4, 80)`
- `Zone_04` center at `(0, 0, 96)`
- `Door_04` center at `(0, 4, 112)`
- `Zone_05` center at `(0, 0, 128)`

This is not the final art layout.
It is a clean first pass that stays readable and easy to debug.

## Zone Contents

### Zone_01 Triage

Place:

- `ReceptionDesk`
- `WardSmall` or open waiting area shell
- one obvious loot socket near player path
- visible sign for onboarding
- start spawn just before or inside this zone

Purpose:

- safe opening
- first obvious interaction
- clear forward route

### Zone_02 Surgery

Place:

- `SurgeryRoom`
- one central landmark table or lamp rig
- one objective panel with `ObjectiveZoneId = Zone_02`
- enough side cover to break line of sight

Purpose:

- first memorable interior
- clear cooperative pressure

### Zone_03 Isolation

Place:

- `IsolationRoom`
- tighter passage or screen blockers
- one objective panel with `ObjectiveZoneId = Zone_03`
- stronger door-control value

Purpose:

- fear spike
- sabotage readability

### Zone_04 Pharmacy

Place:

- `PharmacyRoom`
- denser shelf layout
- one objective panel with `ObjectiveZoneId = Zone_04`
- higher loot density than earlier zones

Purpose:

- contested loot
- pre-finale pressure

### Zone_05 Roof Access

Place:

- `RoofAccess`
- `ExtractionGate`
- `ExtractionPad`
- narrow readable approach to extraction

Purpose:

- final conflict
- readable extraction state

## Door Setup

For each transition between zones, place one blocker part or door assembly centered in the opening.

Required door IDs:

- `Door_01` between `Zone_01` and `Zone_02`
- `Door_02` between `Zone_02` and `Zone_03`
- `Door_03` between `Zone_03` and `Zone_04`
- `Door_04` between `Zone_04` and `Zone_05`

Recommended blocker size:

- `8 x 8 x 2`

Add one `ProximityPrompt` under each blocker:

- `ActionText = Open Door`
- `ObjectText = Security Door`
- `KeyboardKeyCode = E`
- `HoldDuration = 0.2`

## Objective Setup

Current code expects objectives only in:

- `Zone_02`
- `Zone_03`
- `Zone_04`

Each objective should be a part with:

- `InteractionId = recover_power`
- `ObjectiveZoneId = <zone id>`

Add one `ProximityPrompt`:

- `ActionText = Restore Power`
- `ObjectText = Fuse Panel`
- `KeyboardKeyCode = E`
- `HoldDuration = 0.9`

## Extraction Setup

In `Zone_05` place:

1. Gate blocker part named `ExtractionGate`
2. Extract interaction pad named `ExtractionPad`

Gate blocker suggested size:

- `10 x 9 x 2`

Pad suggested size:

- `10 x 1 x 10`

Add one `ProximityPrompt` under the pad:

- `ActionText = Extract`
- `ObjectText = Roof Evac`
- `KeyboardKeyCode = E`
- `HoldDuration = 1.2`

## Minimal Dressing Pass

Do not overbuild yet.

Add only enough dressing to sell the fantasy and improve route readability:

- zone signs
- beds
- curtains
- surgery lamp
- medicine shelves
- debris piles
- one accent light color per zone

Avoid:

- clutter that blocks player movement unpredictably
- narrow maze geometry
- bespoke room sizes

## Verification Checklist

Before expanding the building, verify:

- every zone is reachable in order
- every zone root has `ZoneId`
- every zone root has `PrimaryPart`
- all door blockers have correct IDs and zone links
- objectives exist in `Zone_02` to `Zone_04`
- extraction gate exists in `Zone_05`
- extraction pad exists in `Zone_05`
- lights marked with `ZoneLight` react correctly
- route is readable in the first minute

## Recommended Next Action

If you are building this now in Studio, do it in this order:

1. Create `Workspace/HospitalRaidWorld`
2. Block out `Zone_01` to `Zone_05` as simple floor-and-wall models
3. Add `Door_01` to `Door_04`
4. Add objective panels in `Zone_02` to `Zone_04`
5. Add `ExtractionGate` and `ExtractionPad`
6. Test with current server code
7. Replace simple greyboxes with reusable module models one by one
