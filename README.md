# Ragdoll Noob

A Roblox remake of the Flash game *Ragdoll Achievement*, starring the classic noob.
Up to 4 players each get their own room and noob, and have 90 seconds to do the most damage.

## Running it

1. In a terminal in this folder, run `rojo serve`.
2. In Roblox Studio, open the place, then the **Rojo** plugin, and click **Connect**.
3. Press **Play**.

## Where things are

| Folder | Ends up in Studio as | What's in it |
| --- | --- | --- |
| `src/server` | ServerScriptService.Server | Rounds, rooms, the noob ragdoll, weapons, saving, achievements |
| `src/client` | StarterPlayerScripts.Client | Camera, on-screen menus, placing/dragging weapons |
| `src/shared` | ReplicatedStorage.Shared | Settings, weapon and achievement lists, 3D weapon models |

The lobby and rooms are built by code (`src/server/WorldBuilder.luau`), so the place file stays empty.

## Selling weapons for Robux

Weapons are sold as Game Passes (bought once, kept forever).

1. Publish the game, then on create.roblox.com open it → **Monetization → Passes → Create a Pass**.
2. Give it a name, picture and price, and turn on **Item for Sale**.
3. Copy the pass's ID number and paste it into that weapon's `gamePassId` in `src/shared/Weapons.luau`.

A weapon with `gamePassId = 0` shows as "not for sale yet".

## Adding things

- **Weapon:** add it to `src/shared/Weapons.luau`, a model in `src/shared/ItemModels.luau`, and what it does in `src/server/Items.luau`.
- **Achievement:** add it to `src/shared/Achievements.luau`, and award it in `src/server/AchievementService.luau`.
