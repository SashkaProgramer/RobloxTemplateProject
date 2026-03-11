# Data Model

## PlayerRoundState

```lua
type PlayerRoundState = {
    alive: boolean,
    extracted: boolean,
    currentCarId: string?,
    inventory: { string },
    maxSlots: number,
    carriedValue: number,
    hasRareLoot: boolean,
    temporaryFlags: { [string]: boolean },
}
```

## PlayerProfileData

```lua
type PlayerProfileData = {
    currency: number,
    lifetimeExtractedValue: number,
    unlockedCosmetics: { string },
    ownedItems: { string },
}
```

## LootDef

```lua
type LootRarity = "Common" | "Uncommon" | "Rare"

type LootDef = {
    id: string,
    name: string,
    rarity: LootRarity,
    value: number,
    stackable: boolean,
    tags: { string }?,
}
```

## InteractionContext

```lua
type InteractionContext = {
    objectId: string,
    interactionType: string,
    playerUserId: number,
}
```
