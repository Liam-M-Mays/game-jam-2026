# UI ↔ Backend Guide

A short list of what the UI reads, listens to and calls. The full map of the code, with diagrams, is [`docs/architecture.md`](../docs/architecture.md). Read that first. The longer jam version of this guide, with its list of jam UI issues, was out of date after the rework, so it was cut down to this.

## Quick reference

| You want to show / do | Use | Refresh on |
|---|---|---|
| Wood / stone / food count | `Inventory.count("wood")` | `Inventory.changed` |
| Food cap (`12 / 40`) | `Inventory.food_cap()` / `Inventory.food_full()` | `Inventory.changed` |
| What can still be spent on new builds | `Inventory.available("wood")` | `Inventory.changed` |
| Meeple count | `JobSystem.workers.size()` | `JobSystem.changed` |
| Job count | `JobSystem.job_count()` (there is no job limit) | `JobSystem.changed` |
| The player's waiting jobs, and clearing them | `JobSystem.waiting_player_jobs()` / `JobSystem.clear_waiting_player_jobs()` | `JobSystem.changed` |
| Building costs | `building.costs` (total of every frame) / `building.min_to_start` (needed to place) | static |
| What a site under construction is stuck on | `site.missing()` → `{"wood": 1}`, empty when not stuck | `site.missing_changed` |
| What a site needs for its next stage | `site.next_stage_needs()` | `Inventory.changed` |
| Picture of a building (finished frame) | `building.icon()` → `Texture2D` | static |
| Can place (stock covers `min_to_start`) | `building.can_afford()` | `Inventory.changed` |
| Enter / leave build mode | `build_system.start_build(scene)` / `build_system.end_build()` | `BuildSystem` signals |
| Move a building | `build_system.start_move(building)` | `BuildSystem` signals |
| New game | `GameState.new_game()` (resets `Inventory` and `JobSystem`) | |
| Toast | `GameState.toast(text)`, `tip(text)`, `fact(text)`, `warn(text)` | |
| Hunger | `GameState.hunger` (worked out from food per meeple) | `GameState.hunger_changed` |

`Inventory.changed` and `JobSystem.changed` carry no arguments, and each fires at most once every 150 ms (`Inventory.CHANGED_EVERY_MS`). Connect them and re-read what you need. A counter can show a number up to 150 ms late.

`BuildSystem.placement_failed` carries a `reason` (`BuildSystem.PlacementError`) and a `hint` text.

## Where things are

The file map, the class diagrams and how a click becomes a job are all in [`docs/architecture.md`](../docs/architecture.md). The ground world (`assets/Scenes/Levels/ground.tscn`) and the giant (`assets/Scenes/Levels/game.tscn`) use the same HUD.
