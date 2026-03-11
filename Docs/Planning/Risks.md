# Risks

## Scope Risks

- Expanding beyond one strong train route before the first complete match is proven
- Adding too many mechanics before the base tension curve works
- Chasing realism that increases production cost without improving gameplay readability

## Design Risks

- The first minute is too slow or unclear
- Cooperation never forms because sabotage is too strong too early
- Players do not feel enough pressure before extraction
- Rare loot does not meaningfully change player behavior
- Extraction feels unfair rather than brutal-but-readable

## Technical Risks

- Match logic becomes split across too many services without a clear owner
- Client trust leaks into gameplay-significant systems
- PvE threat logic becomes expensive or unreliable
- Round cleanup fails and leaves state behind between matches

## Product Risks

- Atmosphere is not strong enough to differentiate the game
- The concept feels too niche or too punishing for repeat play
- Early monetization pressures the experience too soon
- The project takes too long to reach a playable loop

## Current Mitigation Strategy

- Keep MVP focused on one complete match loop
- Use server authority for loot, sabotage, extraction, and rewards
- Prefer sabotage-driven conflict over large direct-combat systems
- Test first-session clarity before expanding content
