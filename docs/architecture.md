# Architecture (as built)

**What this is:** diagrams of the code as it stands, not a plan. They were drawn from `master` at commit `3c9e6c8` on Nov 9, 2026.

**Keep it true:** when a pull request changes the structure, update the matching diagram in the same pull request. The diagrams are plain text, so the change shows up in the diff.

This file is the source of truth. Older copies of the diagrams exist as Figma boards. They are a snapshot from Nov 9, 2026 and are no longer updated:

- [Architecture board (FigJam)](https://www.figma.com/board/VJ8tnLiibSX9ivptyp2nuX)
- [UML class diagrams (Figma)](https://www.figma.com/design/x7lqHkZwWVC6byvmSV2T8q?node-id=1-2)

## Contents

- [The three layers](#the-three-layers)
- [System map](#system-map)
- [Economy loop](#economy-loop)
- [Scene tree of the game scene](#scene-tree-of-the-game-scene)
- [Scene tree of the ground scene](#scene-tree-of-the-ground-scene)
- [From click to finished building](#from-click-to-finished-building)
- [Meeple job lifecycle](#meeple-job-lifecycle)
- [Building construction lifecycle](#building-construction-lifecycle)
- [Game flow between screens](#game-flow-between-screens)
- [Class diagrams](#class-diagrams)

## The three layers

| Layer | What is in it | Where |
| --- | --- | --- |
| World scene | The grid, everything on it, meeples, drops, `BuildSystem`. On the giant all of it hangs under the giant's torso node. On the ground it sits on a round world | `assets/Scenes/Levels/game.tscn`, `assets/Scenes/Levels/ground.tscn`, `assets/Scripts/` |
| Global singletons | `JobSystem`, `Inventory`, `Population` hold the simulation. `GameState` holds hunger, toasts and speed. `Music` and `VillageAudio` are support | The `[autoload]` section of `project.godot` |
| UI scenes | Main menu and HUD | `Main_Menu.tscn`, `assets/hud.tscn`, scripts at the project root |

The world registers with the singletons, and the singletons tell the UI what changed through signals. Three spots break that direction, and the system map shows them as thick arrows.

## System map

Solid arrows are direct calls. Dotted arrows are signals. Thick arrows are simulation code that depends on `GameState`, the same object that drives the HUD.

```mermaid
flowchart LR
    player(["Player"])

    subgraph uiIn ["UI: input side"]
        mainMenu["Main menu"]
        buildMenu["HUD build button and Build menu"]
    end

    subgraph world ["World: game scene on the giant"]
        buildSystem["BuildSystem: placement mode"]
        grid["Grid: cells, map generation"]
        harvestable["Trees, rocks, bushes"]
        drop["Resource drops"]
        building["Buildings"]
        meeple["Meeples"]
    end

    subgraph globals ["Global singletons (autoloads)"]
        jobSystem["JobSystem: waiting jobs, workers, nearest-first matching"]
        inventory["Inventory: stock, drops, pile counts, reservations"]
        population["Population: growth, starvation"]
        gameState["GameState: hunger, toasts, speed"]
        audio["Music and UI sounds"]
    end

    subgraph uiOut ["UI: display side"]
        hud["HUD counters and hunger bar"]
        toastFeed["Toast feed"]
    end

    player -->|"Clicks"| buildMenu
    player -->|"Clicks"| harvestable
    mainMenu -->|"new_game"| gameState
    buildMenu -->|"start_build"| buildSystem
    buildSystem -->|"Places site"| grid
    grid -->|"Spawns"| harvestable
    harvestable -->|"Breaks into"| drop
    harvestable -->|"Queues job"| jobSystem
    building -->|"Posts haul jobs"| jobSystem
    building -->|"Reserves"| inventory
    drop -->|"Registers"| inventory
    jobSystem -->|"Gives jobs once a frame"| meeple
    meeple -->|"Delivers to"| building
    building -->|"Huts spawn"| meeple
    population -->|"Starves or grows"| meeple
    gameState -->|"Reads food"| inventory
    population ==>|"Reads hunger"| gameState
    building ==>|"Calls warn"| gameState
    audio ==>|"Resets speed"| gameState
    inventory -.->|"changed, at most every 150 ms"| hud
    jobSystem -.->|"changed, at most every 150 ms"| hud
    gameState -.->|"hunger_changed"| hud
    gameState -.->|"toast_requested"| toastFeed
```

## Economy loop

The rules as coded today, with the real numbers.

```mermaid
flowchart LR
    tree["Trees and rocks"]
    bush["Berry bushes"]
    farm["Farms, placed next to a barn"]
    drops["Wood and stone drops on the ground"]
    piles["Wood pile and stone pile"]
    site["Construction sites"]
    huts["Huts and Town Hall"]
    food[("Food stock, cap 20 plus 20 per silo")]
    hunger{"Hunger: food per meeple"}
    meeples["Meeples"]
    hall["Town Hall level"]
    unlocks["New buildings unlock"]

    tree -->|"Harvest costs 1 food"| drops
    drops -->|"Hauled one by one"| site
    drops -->|"Stored by pile workers"| piles
    piles -->|"Hauled up to two at a time"| site
    site -->|"Completes"| huts
    bush -->|"Pick: plus 2"| food
    farm -->|"Harvest: plus 1"| food
    food --> hunger
    meeples --> hunger
    hunger -->|"Above 50: grow"| meeples
    hunger -->|"Below 25: starve"| meeples
    huts -->|"Housing capacity"| meeples
    meeples -->|"3, 6, 10, 15 meeples"| hall
    hall --> unlocks
    unlocks --> site
```

## Scene tree of the game scene

How `assets/Scenes/Levels/game.tscn` is nested. The whole village sits under the giant's torso, so it rides the walk cycle.

```mermaid
flowchart TD
    game["Game: root of Levels/game.tscn"]
    walk["Node2D2: giant drift (walk.gd)"]
    step["Node2D: giant step bob (Giant_step.gd)"]
    head["Head, EyeBlack, eyes (Blink.gd)"]
    arms["Arm Foreground, Arm Background (Giant_arm_step.gd)"]
    torso["Torso sprite"]
    yard["Yard: procedural ground (yard_ground.gd)"]
    camera["Camera2D (giant_camera.gd)"]
    back["Back: y-sorted container"]
    grid["Grid (grid.gd)"]
    cells["2,091 cells: plain data, no node"]
    cellLayer["CellLayer: draws the lit cells in one node (cell_layer.gd)"]
    rows["StandingRow per grid row: draws the still trees, rocks and bushes of that row (standing_row.gd)"]
    objects["Buildings, and the trees, rocks and bushes that are hovered, hit, chosen or growing"]
    meeples["Meeples: plain data, one canvas item each, no node"]
    drops["Drops on the ground: plain data, one canvas item each, no node"]
    cursor["Mouse: cell cursor, asks Grid for the cells near the mouse (mouse.gd)"]
    buildSystem["BuildSystem (build_system.gd)"]
    tooltip["ConstructionTooltip, created in code"]
    parallax["5 parallax background layers"]
    hud["HUD: instance of hud.tscn"]
    hudKids["Counters, hunger bar, worker panel, build menu, pause menu, death screen, toast feed"]
    giantAudio["GiantAudio (giant_audio.gd)"]

    game --> walk
    walk --> step
    walk --> arms
    step --> head
    step --> torso
    torso --> yard
    torso --> camera
    torso --> back
    back --> grid
    back --> cursor
    back --> buildSystem
    grid --> cells
    grid --> cellLayer
    grid --> rows
    grid --> objects
    grid --> meeples
    grid --> drops
    buildSystem --> tooltip
    game --> parallax
    game --> hud
    hud --> hudKids
    game --> giantAudio
```

## Scene tree of the ground scene

How `assets/Scenes/Levels/ground.tscn` is nested. The same Grid, Mouse, BuildSystem and HUD, with no giant. The Grid's `world_cells` sets the size of the round world, and the Grid moves the Yard to the world's middle and gives its polygon the world's edge.

```mermaid
flowchart TD
    ground["Ground: root of Levels/ground.tscn (ground_level.gd)"]
    world["World: y-sorted container, scale 0.1"]
    grid["Grid (grid.gd), world_cells = 100,000"]
    cursor["Mouse (mouse.gd)"]
    buildSystem["BuildSystem (build_system.gd)"]
    yard["Yard: noise for the round world (yard_ground.gd)"]
    shape["Yard: Polygon2D in the world's shape, drawn with yard_ground.gdshader"]
    camera["Camera2D (ground_camera.gd): view held inside the world"]
    hud["HUD: instance of hud.tscn"]

    ground --> world
    world --> grid
    world --> cursor
    world --> buildSystem
    ground --> yard
    yard --> shape
    ground --> camera
    ground --> hud
```

## From click to finished building

The order of calls when the player builds a Small Hut. Solid arrows are calls, dashed arrows are return values and signals.

```mermaid
sequenceDiagram
    participant Player
    participant BuildMenu
    participant BuildSystem
    participant Building
    participant Inventory
    participant JobSystem
    participant Meeple
    participant HUD
    participant GameState
    participant ToastFeed

    Player->>BuildMenu: Click Small Hut
    BuildMenu->>BuildSystem: start_build(scene)
    Player->>BuildSystem: Left click on free cells
    BuildSystem->>Building: grid.place, start_construction
    Building->>Inventory: reserve(wood)
    Building->>Inventory: claim_closest(wood), in HaulJob.new
    Building->>JobSystem: add(HaulJob)
    JobSystem->>Meeple: take_job(HaulJob), nearest free meeple, next frame
    Meeple->>Building: deliver(wood)
    Building-->>BuildSystem: completed
    BuildSystem-->>HUD: building_completed
    HUD->>GameState: toast(Small Hut finished)
    GameState-->>ToastFeed: toast_requested
```

## Meeple job lifecycle

From `meeple_movement.gd` and `job_system.gd`. A meeple is either a builder or a worker of one building. Once a frame, `JobSystem.match_jobs` gives each new job to the nearest free builder, and each builder that became free the nearest waiting job. There is no job limit. A worker asks its building for work with `find_work` at most every half second, and never takes the player's jobs. A click on a finished building opens the `WorkerPanel`. Its arrows set the workers of the building's `worker_building()`: a farm or silo gives its barn, and a building with no slots, like a hut, hides them. The add arrow opens a slot, which the nearest free builder takes. The remove arrow drops a slot nobody took yet, or sends a worker back to being a builder. A new building starts with no workers (`Building.STARTS_FULL`). A dead worker's slot opens again.

The panel's Remove button asks first, then calls `Building.remove_building()`. What the building cost pops out as drops, the way a tree's drops do (a site pops out only what was delivered). Its workers go back to being builders, its hauls are recalled, and it leaves every group at once. A pile also drops what it held, and a haul that claimed a drop in it takes one of the dropped drops instead (`JobSystem.hauls_from`, `HaulJob.take_spilled`). A barn removes its farms and silos first. A removed hut leaves its meeples, so the village can be over its room. The Town Hall answers false to `can_remove()`, and its button is dimmed.

```mermaid
stateDiagram-v2
    direction LR
    Wandering: Builder, wandering near buildings
    QueuedJob: Queued job - harvest, haul, collect crop
    WorkerWandering: Worker, wandering
    Work: Work for its building - chop, farm, store
    Dead: Dead - topples and fades out

    [*] --> Wandering: spawned by a hut
    Wandering --> QueuedJob: nearest to a new job, or takes the nearest waiting job
    QueuedJob --> Wandering: job done or cancelled
    Wandering --> WorkerWandering: nearest builder to an open slot
    WorkerWandering --> Work: its building has work
    Work --> WorkerWandering: task done
    Wandering --> Dead: starved
    QueuedJob --> Dead: starved, job requeued
    WorkerWandering --> Dead: starved, slot opens
    Work --> Dead: starved, slot opens
    Dead --> [*]
```

## Building construction lifecycle

These states have no names in code. They are implied by four flags and two groups in `building.gd`.

```mermaid
stateDiagram-v2
    direction LR
    Preview: Preview ghost following the mouse
    Completed: Completed - in group completed_buildings

    [*] --> Preview: BuildSystem.start_build
    Preview --> [*]: Esc or end_build
    Preview --> UnderConstruction: click on free cells and can afford

    state UnderConstruction {
        [*] --> Hauling
        Hauling --> Blocked: next stage not covered
        Blocked --> Hauling: resources become available
        Hauling --> Paused: right-click
        Paused --> Hauling: right-click
    }

    UnderConstruction --> Completed: last stage paid for
    Completed --> [*]
```

## Game flow between screens

```mermaid
stateDiagram-v2
    direction LR
    MainMenu: Main menu - Main_Menu.tscn
    Playing: Playing - Levels/game.tscn
    Ground: Playing on the ground - Levels/ground.tscn
    Paused: Paused - tree paused
    GameOver: Game over - death screen

    [*] --> MainMenu
    MainMenu --> Playing: Start calls new_game
    MainMenu --> Ground: Ground world button calls new_game
    Playing --> Paused: Esc
    Paused --> Playing: Resume
    Paused --> MainMenu: Menu button
    Playing --> GameOver: all meeples died
    GameOver --> Playing: Retry reloads the scene
    GameOver --> MainMenu: Menu button
    MainMenu --> [*]: Quit
```

## Class diagrams

Three diagrams cover 53 of the 57 scripts. The four left out are tiny: `walk.gd`, `Blink.gd`, `menu_meeple.gd` and `resource_ui.gd`.

How to read them:

- A solid arrow with a triangle means "extends".
- A dotted arrow means "holds or uses".
- `+` is public, `#` is meant to be overridden. Private members are left out.
- `<<autoload>>` is a global singleton, `<<resource>>` is a data resource, `<<unnamed>>` is a script without a `class_name`.
- `<<scene>>` is the root script of a scene that the game reads once as a template (`MeepleLook` is `meeple.tscn`, `DropLook` is a drop scene in `Scenes/Resources/Drops`).

### Class diagram 1: world objects

Everything that sits on the grid: the grid itself, harvestables, drops and all building types.

```mermaid
classDiagram
    direction TB
    class Grid {
        +grid_size: int = 50
        +start_building: PackedScene
        +spawnables: Array[PackedScene]
        +generation_seed: int
        +respawn_interval: float
        +cell_at(world_pos): Cell
        +cells_near(world_pos, radius)
        +free_cells_at(pos, width, depth)
        +cells_around(obj, radius)
        +cells_at_offsets(origin, offsets)
        +place(obj, cells)
        +remove(obj)
        +spawn_meeple(at): Meeple
        +add_drop(scene, at): ResourceDrop
        +standing: Array[Standing]
        +wake(item): Harvestable
        +nearest_standing(at, accept): Standing
    }
    class AreaIndex {
        +add(item, at) / remove(item, at) / move(item, from, to)
        +best(from, score, bound): the lowest score, looking near first
    }
    class Standing {
        +kind: Spawnable
        +cells: Array[Cell]
        +position: Vector2
        +wobbles: int
        +stage / regrow_timer / emptied: bushes only
        +node: Harvestable
        +is_free(): bool
    }
    class StandingRow {
        +add(item) / remove(item)
    }
    class Cell {
        +position: Vector2
        +occupant: GridObject or Standing
        +kept_for: Barn or null
        +highlight(alpha, color)
    }
    class CellLayer {
        +set_lit(cell, color)
    }
    class GridObject {
        +area: Area2D
        +footprint, footprint_depth: int
        +hoverable: bool
        +grid: Grid
        +cells: Array[Cell]
        +set_selected(on, tint)
        +flash(color)
        +reject()
        +spawn_effect(scene)
        #_on_clicked()
    }
    class BuildSystem {
        +signal build_started(scene)
        +signal build_ended
        +signal building_placed(building)
        +signal building_completed(building)
        +signal placement_failed(reason, hint)
        +grid: Grid
        +cursor: CellCursor
        +start_build(scene)
        +end_build()
        +is_building(): bool
    }
    class CellCursor {
        +enabled: bool
        +highlight_alpha: float
        +radius: float
        +grid: Grid
    }
    class ResourceDrop {
        +kind: String
        +claimed: bool
        +position: Vector2
        +global_position: Vector2
        +scene_of(kind)$: PackedScene
        +launch()
        +show() / hide()
        +consume()
        +is_in_world(): bool
    }
    class DropLook {
        <<scene>>
        +kind: String
        +launch_distance_min / max: float
        +launch_duration: float
        +draw(item)
    }
    class Harvestable {
        +wobbles_to_break: int
        +wobble_interval: float
        +drops: Dictionary[PackedScene, int]
        +food_cost: int
        +target_count: int
        +respawn_chance: float
        +can_harvest(): bool
        +is_free(): bool
        +claim(job) / release(job)
        +standing: Standing
        +harvest(): bool
        +grow_in()
        +texture_for(item): Texture2D
        +is_still(): bool
    }
    class Building {
        +signal completed
        +signal missing_changed
        +frames: Array[BuildFrame]
        +min_to_start: Dictionary[String, int]
        +required_town_hall_level: int
        +description: String
        +worker_slots: int
        +workers: Array[Meeple]
        +wanted_workers: int
        +costs: Dictionary (computed)
        +start_construction()
        +deliver(kind)
        +complete()
        +toggle_paused()
        +can_afford() / can_start()
        +missing() / next_stage_needs()
        +find_work(worker): Job
        +add_worker(meeple) / lose_worker(meeple)
        +worker_building(): Building
        +add_worker_slot() / remove_worker_slot()
        +can_remove(): bool
        +remove_building()
        +icon(): Texture2D
        +can_place_at() / placement_area()
        +area_at(grid, anchor): Array[Cell]
        +build_after(scene): PackedScene
        +note(): String
    }
    class BuildFrame {
        <<resource>>
        +costs: Dictionary[String, int]
        +total(): int
    }
    class Bush {
        +food_per_harvest: int
        +regrow_time: float
        +empties_to_destroy: int
        +regrow(item, delta): bool
        +texture_for(item): Texture2D
        +can_harvest(): bool
        #_hit(): bool
    }
    class Hut {
        +meeple_capacity: int
        +spawn_meeple()
        +complete()
    }
    class Storage {
        +kind: String
        +max_items: int
        +capacity(): int
        +held(): int
        +has_room(): bool
        +store(drop)
        +claim() / unclaim()
        +take(): ResourceDrop
        +find_work(worker): StoreJob
        +make_store_job(drop): StoreJob
        +remove_building()
    }
    class Lumberjack {
        +chops: PackedScene
        +find_work(worker): ChopJob
    }
    class Barn {
        +base_slots: int = 3
        +plot_offsets: Array[Vector2i]
        +plots: Array[BarnPlot]
        +farm_scene: PackedScene
        +slots(): int
        +has_room_for(plot): bool
        +find_work(worker): FarmJob
        +add_plot(plot)
        +plot_area(): Array[Cell]
        +in_plot_range(cells): bool
        +remove_building()
    }
    class BarnPlot {
        +barn: Barn
        +restricts_placement(): bool
        +placement_area(grid)
        +can_place_at(grid, cells)
        +placement_hint(): String
    }
    class Windmill {
        +extra_barn_slots: int = 1
        +spin_speed: float
        +wheel: Sprite2D
        +complete()
    }
    class StoneHut {
    }
    class TownHall {
        +signal upgraded(new_level)
        +meeples_required: Array[int]
        +level() / max_level()
        +can_upgrade(): bool
        +upgrade(): bool
        +meeples_for_next_level(): int
        +find_town_hall() static
        +current_level() static
        +can_remove(): false
    }
    class Farm {
        +grow_time: float
        +food_per_harvest: int
        +harvest_time: float
        +is_ripe() / can_harvest_now()
        +harvest_crop()
        +grow_stages(): int
    }
    class Silo {
        +food_capacity: int = 20
        +complete()
    }
    GridObject <|-- Harvestable
    GridObject <|-- Building
    Harvestable <|-- Bush
    Building <|-- Hut
    Building <|-- Storage
    Building <|-- Lumberjack
    Building <|-- Barn
    Building <|-- BarnPlot
    Building <|-- Windmill
    Hut <|-- StoneHut
    Hut <|-- TownHall
    BarnPlot <|-- Farm
    BarnPlot <|-- Silo
    Grid ..> Cell : 2,091 cells
    Cell ..> GridObject : occupant
    Cell ..> Standing : occupant
    Grid ..> Standing : trees, rocks, bushes
    Grid ..> AreaIndex : one per kind of tree, rock or bush
    Standing ..> StandingRow : drawn by, while still
    Standing ..> Harvestable : node, while awake
    Cell ..> CellLayer : lit by
    CellCursor ..> Grid : cells_near
    Harvestable ..> ResourceDrop : breaks into
    ResourceDrop ..> DropLook : reads look and numbers
    Building ..> BuildFrame : cost per stage
    BuildSystem ..> Building : previews and places
    BuildSystem ..> CellCursor : cursor
    Barn ..> BarnPlot : plots
```

### Class diagram 2: jobs, meeples and the simulation singletons

How work gets done: the waiting jobs, the six job types, the meeple that runs them, and the two singletons that hold the economy and the population.

```mermaid
classDiagram
    direction TB
    class JobSystem {
        <<autoload>>
        +signal changed
        +workers: Array[Meeple]
        +add(job)
        +match_jobs()
        +worker_freed(worker)
        +finish(job)
        +requeue(job, worker)
        +cancel(job)
        +open_slot(building) / close_slot(building)
        +take_partner(job): HaulJob
        +recall_hauls(site)
        +hauls_from(pile): Array[HaulJob]
        +reset()
    }
    class Job {
        +cancelled: bool
        +place(): Vector2
        +start(worker)
        +update(worker, delta): bool
        +abort(worker)
    }
    class Meeple {
        +job: Job
        +workplace: Building
        +grid: Grid
        +position: Vector2
        +global_position: Vector2
        +tick(delta): bool
        +move_to(pos, stop_cells)
        +stop()
        +leave_workplace()
        +has_arrived(): bool
        +carry(kind, amount)
        +abandon_job()
        +is_free(): bool
        +take_job(job)
        +die()
    }
    class MeepleLook {
        <<scene>>
        +speed: int
        +wander_radius: float
        +draw(item, body_color, frame, head_offset_y)
    }
    class Population {
        <<autoload>>
        +signal all_meeples_died
        +huts: Array[Hut]
        +TICK = 4.0
        +STARVE_BELOW = 25
        +GROW_ABOVE = 50
        +DEATH_CHANCE = 0.25
        +capacity(): int
        +add_hut(hut) / remove_hut(hut)
    }
    class Inventory {
        <<autoload>>
        +signal changed
        +START_STOCK = 10 food
        +BASE_FOOD_CAP = 20
        +count(kind): int
        +available(kind): int
        +add(kind, n) / spend(kind, n)
        +reserve(kind, n)
        +claim_closest(kind, pos): ResourceDrop or Storage
        +shortest_trip_loose(kind, from, to)
        +drop_moved(drop, from, to)
        +food_cap() / food_full()
        +room(kind): int
        +register(drop) / unregister(drop)
        +clear_drops()
        +reset()
    }
    class HarvestJob {
        +target: Harvestable
    }
    class HaulJob {
        +site: Building
        +kind: String
    }
    class ChopJob {
        +target: Harvestable
    }
    class FarmJob {
        +farm: Farm
    }
    class StoreJob {
        +site: Storage
    }
    Job <|-- HarvestJob
    Job <|-- HaulJob
    Job <|-- ChopJob
    Job <|-- FarmJob
    Job <|-- StoreJob
    JobSystem ..> Job : pending and active
    Inventory ..> AreaIndex : one per kind of drop
    Meeple ..> Job : runs one job
    Meeple ..> MeepleLook : reads look and numbers
    Population ..> Meeple : starves
```

### Class diagram 3: UI, audio, camera and the giant

The remaining singletons and everything the player sees. The arrow from `UISounds` to `GameState` is a rule hiding inside an audio script: a warning toast resets the game speed.

```mermaid
classDiagram
    direction TB
    class GameState {
        <<autoload>>
        +signal hunger_changed(value)
        +signal starved
        +signal toast_requested(text, kind)
        +signal speed_changed(speed)
        +hunger: float
        +speed: float
        +SPEEDS = 1, 1.5, 2, 3
        +new_game()
        +toast(text, kind)
        +tip(text) / fact(text) / warn(text)
        +cycle_speed()
        +set_speed_index(i)
    }
    class UISounds {
        <<unnamed>>
    }
    class Music {
        <<autoload>>
        +MENU_SCENE, GAME_SCENE: String
        +play_success_riff()
        +fade_out_game_over(seconds)
    }
    class VillageAudio {
        <<autoload>>
        +LIBRARY: axe, pickaxe, grass, hammer, log, hurt
        +VOICE_COUNT = 6
        +play(sound_name, at)
    }
    class MainMenu {
        <<unnamed>>
        +start_button, credits_button, quit_button
        +credits_panel, credits_back_button
    }
    class HUD {
        <<unnamed>>
        +build_system: BuildSystem
        +build_menu: BuildMenu
        +pause_menu, death_screen: PauseMenu
        +camera: CameraControls
        +labels, hunger_bar, speed_button
        +OPENING_TIPS, TIPS, FUN_FACTS
    }
    class BuildMenu {
        +BUILDINGS: 11 PackedScenes
        +HOTKEYS: 1 to 0 and minus
        +build_system: BuildSystem
        +open() / close()
        +unlocked_names(level)
        +display_name(scene) static
    }
    class WorkerPanel {
        +GROUP: worker_panel
        +open(building) / close()
    }
    class PauseMenu {
        +restart_on_resume: bool
        +resume_button, menu_button, quit_button
        +open() / close()
        +fade_in(seconds, black_seconds)
    }
    class ToastFeed {
        +max_toasts: int = 9
        +lifetime: float = 30
        +push(text, kind)
    }
    class HungerBar {
        <<unnamed>>
        +food_plate, food_label
    }
    class ConstructionTooltip {
        +describe(site) static
        +describe_pile(pile) static
        +site_under_mouse(tree) static
        +pile_under_mouse(tree) static
    }
    class CameraControls {
        +move_speed, min_zoom, max_zoom
        +zoom_by(factor)
        +zoom_to_mouse(factor)
        +is_zoomed_out(): bool
    }
    class GiantPart {
        +signal lifted(index)
        +signal landed(index)
        +lift_time, hang_time, slam_time
        +settle_time, pause_time
        +lands_on(index): bool
        #_pose(index, t): Vector2
    }
    class GiantAudio {
        <<unnamed>>
        +camera: CameraControls
        +feet: Array[GiantPart]
        +crumble_points: Array[Node2D]
    }
    class YardGround {
        +preset, frequency, preview_seed
        +generate(world_seed, is_ground)
        +band_at(world_pos)  (unused)
    }
    class MenuMeepleSpawner {
        +front_layer: Node2D
        +min_delay, max_delay
    }
    class GiantCamera {
        <<unnamed>>
        +wide_position: Vector2
    }
    class GiantStep {
        <<unnamed>>
        +step_height, sway
    }
    class GiantArmStep {
        <<unnamed>>
        +shift_distance, bob_height
        +starts_shifted: bool
    }
    CameraControls <|-- GiantCamera
    GiantPart <|-- GiantStep
    GiantPart <|-- GiantArmStep
    UISounds ..> GameState : resets speed
    Music ..> UISounds : owns
    MainMenu ..> GameState : new_game
    HUD ..> GameState : toasts, hunger
    HUD ..> BuildMenu : opens
    GiantAudio ..> GiantPart : listens to feet
```

