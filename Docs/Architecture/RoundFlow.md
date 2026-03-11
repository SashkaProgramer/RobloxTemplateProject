# Round Flow

## Match Owner

`RoundService` is the single authority for match state and phase progression.

## State Sequence

1. `Lobby`
2. `Preparation`
3. `Traversal`
4. `Finale`
5. `Resolved`

## Lobby

- Wait for enough players
- Initialize round data
- Reset temporary state

## Preparation

- Spawn players
- Enable first interactions
- Establish safe opening conditions

## Traversal

- Main match phase
- Loot collection
- Resource pressure
- PvE threat presence
- Limited sabotage opportunities

## Finale

- Extraction becomes available
- Threat pressure increases
- Sabotage value spikes
- Limited extraction capacity becomes decisive

## Resolved

- Determine extracted players
- Calculate secured loot
- Award currency and progression
- Clean up round state
- Prepare next loop

## Transition Rules

- Only the server may advance match phases.
- Player actions may influence pressure and conditions, but not directly force illegal transitions.
- Match cleanup must fully reset temporary state before the next round.
