# UI ↔ Backend Guide

A quick map of the gameplay code, written for hooking up UI: what to read, which signals to listen to, and what to call. The last section lists the things in the current UI scripts that need changing to work with it.

---

## TL;DR

| You want to show / do | Use | Refresh on |
|---|---|---|
| Wood / stone / food count | `Inventory.count("wood")` | `Inventory.changed` |
| What can still be spent on new builds | `Inventory.available("wood")` | `Inventory.changed` |
| Meeple count | `JobSystem.workers.size()` | `JobSystem.changed` |
| Job queue (`3 / 4`) | `JobSystem.job_count()` / `JobSystem.capacity()` | `JobSystem.changed` |
| Building costs | `building.costs` (total of every frame) / `building.min_to_start` (needed to place) | static |
| What a site under construction is stuck on | `site.missing()` → `{"wood": 1}`, empty when not stuck | `site.missing_changed` |
| Can place (has `min_to_start`) | `building.can_afford()` / `building.can_start()` | `Inventory.changed` + `JobSystem.changed` |
| Enter / leave build mode | `build_system.start_build(scene)` / `build_system.end_build()` | — |
| Build mode events | `BuildSystem` signals (below) | — |
| Queue-full feedback | `JobSystem.job_rejected` | — |
| New game | `Inventory.reset()` + `JobSystem.reset()` | — |
| Toast | `GameState.toast("text")` | (yours) |
| Hunger | `GameState.hunger` (yours) | `GameState.hunger_changed` |

`Inventory.changed` and `JobSystem.changed` carry no arguments. Connect them and re-read whatever you need.

> ⚠️ `GameState.wood/stone/meeple` are **not** connected to the real game. Meeples chopping trees changes `Inventory`, not `GameState`. Read resources from `Inventory` and meeples from `JobSystem`.

---

## Autoloads (globals)

| Name | Script | What it is |
|---|---|---|
| `JobSystem` | `assets/Scripts/Jobs/job_system.gd` | Job queue + worker (meeple) registry + job cap |
| `Inventory` | `assets/Scripts/Resources/inventory.gd` | All resource counts |
| `GameState` | `Game_State.gd` | UI-side state (hunger, toasts) |
| `Population` | `assets/Scripts/Meeple/population.gd` | Meeple cap (= completed huts), starvation deaths, respawns |

### `Inventory`

```gdscript
signal changed

func count(kind: String) -> int        # total owned: drops on the ground + stored
func available(kind: String) -> int    # count minus what queued builds have reserved
func add(kind: String, amount: int)    # add to stored stock (food uses this)
func reset()                           # clear stored stock + reservations (new game)
```

- **Kinds right now:** `"wood"`, `"stone"`, `"food"`. Kinds are just strings, so a new one appears the first time something adds or drops it. `count()` on an unknown kind returns `0`.
- **Wood and stone are physical.** Each one is a `ResourceDrop` node on the grid, and `count` is how many exist. A build doesn't subtract when it's placed. Meeples carry the drops to the site, so the count goes down delivery by delivery.
- **Food is a plain number.** Starts at 10 (`Inventory.START_STOCK`). Bushes call `add("food", n)`. A harvest charges the harvestable's `food_cost` (set per scene) when it finishes, clamped at 0.
- **`count` vs `available`:** use `count` for the corner counter. After a hut is placed, `available` drops immediately, but `count` only drops as meeples haul.

### `JobSystem`

```gdscript
signal changed
signal job_rejected(job: Job)          # something tried to queue a job while full

const EXTRA_JOBS := 3
var workers: Array[Meeple]             # every meeple alive
func capacity() -> int                 # workers.size() + EXTRA_JOBS
func job_count() -> int                # pending + in-progress
func has_room(amount := 1) -> bool
func reset()                           # drop every job (new game)
```

`changed` fires when a job is queued, finished or cancelled, and when a meeple spawns or is removed. `job_rejected` fires when the player clicks a tree or rock with a full queue. The object also flashes red and shakes in the world on its own.

Both autoloads outlive scene changes. **Call `Inventory.reset()` and `JobSystem.reset()` when starting a new game**, or jobs pointing at the old map's trees carry over. Meeples and drops unregister themselves when their scene is freed, so only those two calls are needed.

---

## `BuildSystem`

`assets/Scripts/Buildings/build_system.gd`, class `BuildSystem`. It's a node in the game scene at `Node2D2/Node2D/Torso/Back/BuildSystem`.

```gdscript
signal build_started(scene: PackedScene)
signal build_ended                              # left build mode (placed, cancelled or end_build())
signal building_placed(building: Building)      # site placed, hauling starts
signal building_completed(building: Building)   # last delivery landed, building done
signal placement_failed(reason: BuildSystem.PlacementError)

enum PlacementError { NONE, BLOCKED, CANT_AFFORD, QUEUE_FULL }

func start_build(scene: PackedScene)   # enter build mode with this building (swaps if already in it)
func end_build()                       # leave build mode (no-op if not in it)
func is_building() -> bool
```

How it behaves:

- **In build mode** a ghost preview follows the mouse, green when it can be placed and red when it can't.
- **Left-click** places the building, and placing always **exits build mode**. Placing needs `min_to_start` to be available. Each sprite frame has its own cost (`frames` on the scene). Meeples keep hauling whatever the unbuilt frames still need, and the building advances a frame whenever the resources delivered so far cover the next frame's cost. When the next frame can't be paid for with what's delivered or on the way, the blueprint turns red until more resources show up. `building_completed` fires on the last frame. A hut also spawns a meeple at that point.
- **A failed click** (blocked cells, can't afford, queue full) makes the preview flash red and shake, emits `placement_failed(reason)`, and stays in build mode.
- **Esc** calls `end_build()` and marks the event handled, so your HUD's `_unhandled_input` never sees that Esc. Outside build mode, Esc passes through to the HUD normally.
- **Playtest hotkeys** (the `HOTKEYS` dict at the top of the file): `2` small hut, `3` stone hut, `4` barn, `5` farm, `6` stone pile, `7` wood pile, `8` lumberjack.
- **The town hall is not buildable.** It's the starting building (`grid.tscn` → `start_building`), so leave it out of the build menu.
- `BuildSystem` is `PAUSABLE`. Start placement from a menu, then **unpause**, or the preview won't follow the mouse.

### Getting a reference

The cleanest option is an export on your HUD, assigned on the HUD instance in the game scene:

```gdscript
@export var build_system: BuildSystem
```

Then set it in the inspector on the `HUD` node of `Brady_Scene` / `game.tscn`, pointing at `.../Torso/Back/BuildSystem`. Pass it down to the build menu from `HUD._ready()`.

### Build menu example

```gdscript
const BUILDINGS: Array[PackedScene] = [
	preload("res://assets/Scenes/Buildings/small_hut.tscn"),
	preload("res://assets/Scenes/Buildings/lumberjack.tscn"),
]

var build_system: BuildSystem
var _templates := {}   # PackedScene -> Building (never added to the tree; just data)

func _ready() -> void:
	for scene in BUILDINGS:
		_templates[scene] = scene.instantiate()
	Inventory.changed.connect(_refresh)
	JobSystem.changed.connect(_refresh)

func _refresh() -> void:
	for button in building_list.get_children():
		var b: Building = _templates[button.get_meta("scene")]
		button.disabled = not b.can_start()          # afford + queue room for the hauls
		button.text = "Hut  %s" % _cost_text(b.costs)

func _on_building_pressed(scene: PackedScene) -> void:
	build_system.start_build(scene)
	close()                                          # unpauses so placement works

func _cost_text(costs: Dictionary) -> String:
	var parts := []
	for kind in costs:
		parts.append("%d %s" % [costs[kind], kind])
	return " / ".join(parts)
```

Free the templates in `_exit_tree` (`for b in _templates.values(): b.free()`). Costs live on each building scene (`frames` and `min_to_start` in the inspector), so the menu stays correct whenever they're retuned.

---

## Feature hookups

### Resource counter

```gdscript
func _ready() -> void:
	Inventory.changed.connect(_refresh)
	JobSystem.changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	wood_label.text = str(Inventory.count("wood"))
	stone_label.text = str(Inventory.count("stone"))
	food_label.text = str(Inventory.count("food"))
	meeple_label.text = str(JobSystem.workers.size())
	job_label.text = "%d / %d" % [JobSystem.job_count(), JobSystem.capacity()]
```

`Inventory.changed` can fire several times in one frame (a tree breaking spawns several drops). If you animate counters, debounce with a dirty flag checked in `_process`.

### Toasts

All of these come from backend signals, so the UI never has to poll:

```gdscript
build_system.building_completed.connect(func(b): GameState.toast("Hut finished!"))
build_system.placement_failed.connect(_on_placement_failed)
JobSystem.job_rejected.connect(func(_job): GameState.toast("Too many jobs queued"))

func _on_placement_failed(reason: BuildSystem.PlacementError) -> void:
	match reason:
		BuildSystem.PlacementError.CANT_AFFORD: GameState.toast("Not enough resources")
		BuildSystem.PlacementError.QUEUE_FULL: GameState.toast("Too many jobs queued")
		BuildSystem.PlacementError.BLOCKED: GameState.toast("Can't build there")
```

New meeple: watch `JobSystem.changed` and compare `workers.size()` with the last value, or toast on `building_completed` for huts (`b is Hut`).

### Hunger bar

There's no hunger in the backend. `GameState.hunger` is the only hunger system, so the bar works as-is. Food does exist (`Inventory.count("food")`, from bushes), but nothing eats it yet. Connecting the two is a design call (do meeples eat from stock? at what rate?), not a missing hook.

---

## Clicks passing through the HUD (known, not fixed yet)

**The problem:** in build mode, clicking a HUD button also places the building under the cursor.

**Why:** Godot sends input in this order:

```
_input  →  GUI (Controls)  →  _shortcut_input  →  _unhandled_key_input  →  _unhandled_input  →  physics picking (Area2D)
```

`BuildSystem` reads its placement click in `_input`, which runs before any `Control` gets a chance to consume it. Tree and rock clicks are fine, because they go through physics picking, which comes after GUI.

**Whose fix:** the backend's, not the UI's. The fix is to move the left-click branch of `BuildSystem._input` into `_unhandled_input`. Esc can stay in `_input` so it still beats the HUD's pause handler. After that, any `Control` that stops the mouse (default for `Button`, `Panel`, `TextureButton`) swallows the click and the world never sees it.

**What the UI side needs to do** (true either way):

- Interactive panels and buttons: `mouse_filter = STOP` (the default). These block world clicks, which is intended.
- Decorative or full-screen containers (toast feed, layout roots, margin containers): `mouse_filter = IGNORE`. Otherwise they eat every world click, including tree selection. `ToastFeed` already does this.

---

## Issues in the current UI scripts

None of these were edited. They're listed so they can be changed when convenient.

1. **`HUD._update_counters()` reads `GameState.wood/stone/meeple`.** Those never change during play. Read `Inventory.count(...)` and `JobSystem.workers.size()` instead, and refresh on `Inventory.changed` + `JobSystem.changed` rather than `GameState.resources_changed`.
2. **`Build_Menu.gd` uses placeholder dictionaries** (`"wood": 10` etc.). Real costs live on the building scenes (the hut is 1 wood + 1 stone). Use `PackedScene`s and read `building.costs` (see the build menu example).
3. **`Build_Menu._on_building_pressed` calls `GameState.spend()`.** The backend pays by hauling, so charging in the menu means paying twice, and `GameState` isn't the real stock anyway. Call `build_system.start_build(scene)` and drop the `spend` and `can_afford` calls.
4. **`building_chosen(Dictionary)` has no listener**, and the backend needs a `PackedScene`. It can be replaced by the `start_build` call above.
5. **The "Built %s" toast fires when the menu button is pressed**, before anything exists. Toast on `build_system.building_completed`, or on `building_placed` ("Hut placed").
6. **Hunger always ends in `starved`.** `GameState.hunger` drains and nothing calls `feed()`, so the starving toast fires at about 3 min 20 s every game. See [Hunger bar](#hunger-bar).
7. **`GameState.reset()` doesn't reset the game systems.** Add `Inventory.reset()` and `JobSystem.reset()` alongside it (main menu start). Leftover jobs from a previous map can crash the next one.
8. **`Main_Menu.GAME_SCENE` is `res://game.tscn`.** The real path is `res://assets/Scenes/Levels/game.tscn`. `Pause_Menu.MAIN_MENU_SCENE` points to a `main_menu.tscn` that doesn't exist yet.
9. **`hud.tscn` only contains `ToastFeed`.** `HUD.gd` isn't attached yet, and its exported nodes (labels, `hunger_bar`, `build_button`, `build_menu`, `pause_menu`) don't exist. Once it's attached, every export needs assigning, or `_ready()` errors on null.
10. **`Toast_Feed.gd` still has the `T` test key** (`_unhandled_input` spawning "Test toast N"). It will fire in real play.
11. **`Brady_Scene` has two counters:** the old `UI` node (`resource_ui.gd`) plus the HUD. Delete the `UI` node once the HUD shows the same info.
12. **`Brady_Scene`'s `Back` node is missing `y_sort_enabled = true`** (it's on in `game.tscn`). Without it, meeples, trees and buildings layer in creation order instead of by height.
13. **Project convention:** no comments in code except `TODO`s.
14. **`Build_Menu.BUILDINGS` preloads `hut_build.tscn`, which no longer exists.** That hut became the town hall (`town_hall.tscn`, start building only, not buildable). Swap it for `small_hut.tscn` (and add `lumberjack.tscn` etc.).

---

## File map

```
assets/Scripts/
  Env/grid.gd                 Grid: cells, map generation, place()/remove(), starting town hall
  Env/grid_object.gd          Base for anything on cells: outline, hover, flash, reject()
  Env/cell.gd
  Resources/harvestable.gd    Trees / rocks: click to queue, hit, break into drops
  Resources/bush.gd           Harvestable that adds food instead of breaking
  Resources/inventory.gd      autoload Inventory
  Resources/resource_drop.gd  Physical wood/stone on the ground
  Buildings/building.gd       Costs, haul jobs, construction frames, completed signal
  Buildings/hut.gd            Spawns a meeple when completed (town hall, small hut, stone hut)
  Buildings/storage.gd        Stone / wood piles: idle job hauls loose drops in
  Buildings/lumberjack.gd     Idle job: one meeple at a time chops the free tree closest to the building
  Buildings/build_system.gd   class BuildSystem: build mode, preview, placement
  Jobs/job_system.gd          autoload JobSystem
  Jobs/job.gd, harvest_job.gd, haul_job.gd
  Jobs/idle_job.gd, store_job.gd, chop_job.gd   Building-owned idle work (runs only when the queue is empty)
  Meeple/meeple_movement.gd   class Meeple
  UI/resource_ui.gd           Old placeholder counter (the "UI" node). Safe to delete once HUD covers it
```
