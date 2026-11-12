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
- [From click to finished building](#from-click-to-finished-building)
- [Meeple job lifecycle](#meeple-job-lifecycle)
- [Building construction lifecycle](#building-construction-lifecycle)
- [Game flow between screens](#game-flow-between-screens)
- [Class diagrams](#class-diagrams)

## The three layers

| Layer | What is in it | Where |
| --- | --- | --- |
| World scene | The grid, everything on it, meeples, drops, `BuildSystem`. All of it hangs under the giant's torso node | `assets/Scenes/Levels/game.tscn`, `assets/Scripts/` |
| Global singletons | `JobSystem`, `Inventory`, `Population` hold the simulation. `GameState` holds hunger, toasts and speed. `Music`, `VillageAudio`, `DevSpeed` are support | The `[autoload]` section of `project.godot` |
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
        jobSystem["JobSystem: job queue, workers"]
        inventory["Inventory: stock, drops, reservations"]
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
    meeple -->|"Takes jobs"| jobSystem
    meeple -->|"Delivers to"| building
    building -->|"Huts spawn"| meeple
    population -->|"Starves or grows"| meeple
    gameState -->|"Reads food"| inventory
    population ==>|"Reads hunger"| gameState
    building ==>|"Calls warn"| gameState
    audio ==>|"Resets speed"| gameState
    inventory -.->|"changed"| hud
    jobSystem -.->|"changed"| hud
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
    jobs["Job capacity: meeples plus 3"]
    hall["Town Hall level"]
    unlocks["New buildings unlock"]

    tree -->|"Harvest costs 1 food"| drops
    drops -->|"Hauled one by one"| site
    drops -->|"Stored by idle meeples"| piles
    piles -->|"Hauled up to two at a time"| site
    site -->|"Completes"| huts
    bush -->|"Pick: plus 2"| food
    farm -->|"Harvest: plus 1"| food
    food --> hunger
    meeples --> hunger
    hunger -->|"Above 50: grow"| meeples
    hunger -->|"Below 25: starve"| meeples
    huts -->|"Housing capacity"| meeples
    meeples --> jobs
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
    objects["Harvestables, buildings, drops"]
    meeples["Meeples: plain data, one canvas item each, no node"]
    cursor["Mouse: cell cursor, asks Grid for the cells near the mouse (mouse.gd)"]
    buildSystem["BuildSystem (build_system.gd)"]
    tooltip["ConstructionTooltip, created in code"]
    parallax["5 parallax background layers"]
    hud["HUD: instance of hud.tscn"]
    hudKids["Counters, hunger bar, build menu, pause menu, death screen, toast feed"]
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
    grid --> objects
    grid --> meeples
    buildSystem --> tooltip
    game --> parallax
    game --> hud
    hud --> hudKids
    game --> giantAudio
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
    Building->>JobSystem: add(HaulJob)
    Meeple->>JobSystem: take()
    JobSystem-->>Meeple: HaulJob
    Meeple->>Inventory: claim_closest(wood)
    Inventory-->>Meeple: ResourceDrop
    Meeple->>Building: deliver(wood)
    Building-->>BuildSystem: completed
    BuildSystem-->>HUD: building_completed
    HUD->>GameState: toast(Small Hut finished)
    GameState-->>ToastFeed: toast_requested
```

## Meeple job lifecycle

From `meeple_movement.gd` and `job_system.gd`. A meeple drops idle work the moment any queued job exists.

```mermaid
stateDiagram-v2
    direction LR
    Wandering: Wandering near buildings
    QueuedJob: Queued job - harvest, haul, collect crop
    IdleWork: Idle work - chop, farm, store
    Dead: Dead - topples and fades out

    [*] --> Wandering: spawned by a hut
    Wandering --> QueuedJob: JobSystem.take
    Wandering --> IdleWork: a building offers idle work
    IdleWork --> QueuedJob: a queued job appears
    IdleWork --> Wandering: idle job ends
    QueuedJob --> Wandering: job done or cancelled
    Wandering --> Dead: starved
    QueuedJob --> Dead: starved, job requeued
    IdleWork --> Dead: starved
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
    Paused: Paused - tree paused
    GameOver: Game over - death screen

    [*] --> MainMenu
    MainMenu --> Playing: Start calls new_game
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
- `<<scene>>` is the root script of a scene that the game reads once as a template (`MeepleLook` is `meeple.tscn`).

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
    }
    class Cell {
        +position: Vector2
        +occupant: GridObject
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
        +signal placement_failed(reason)
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
        +storage: Storage
        +surplus_time: float
        +launch(grid)
        +expire()
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
        +harvest(): bool
        +grow_in()
    }
    class Building {
        +signal completed
        +signal missing_changed
        +frames: Array[BuildFrame]
        +min_to_start: Dictionary[String, int]
        +required_town_hall_level: int
        +description: String
        +costs: Dictionary (computed)
        +start_construction()
        +deliver(kind)
        +complete()
        +toggle_paused()
        +can_afford() / can_start()
        +missing() / next_stage_needs()
        +claim_idle_job(worker): IdleJob
        +icon(): Texture2D
        +can_place_at() / placement_area()
        #has_idle_work() / _make_idle_job()
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
        +has_room(): bool
        +store(drop) / take(drop)
        +first_unclaimed(): ResourceDrop
        +make_store_job(drop): StoreJob
    }
    class Lumberjack {
        +chops: PackedScene
        #has_idle_work(worker): bool
        #_make_idle_job(): ChopJob
    }
    class Barn {
        +base_slots: int = 3
        +plot_offsets: Array[Vector2i]
        +plots: Array[BarnPlot]
        +slots(): int
        +has_room_for(plot): bool
        +add_plot(plot)
        +plot_area(): Array[Cell]
        +in_plot_range(cells): bool
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
    Cell ..> CellLayer : lit by
    CellCursor ..> Grid : cells_near
    Harvestable ..> ResourceDrop : breaks into
    Building ..> BuildFrame : cost per stage
    BuildSystem ..> Building : previews and places
    BuildSystem ..> CellCursor : cursor
    Barn ..> BarnPlot : plots
```

### Class diagram 2: jobs, meeples and the simulation singletons

How work gets done: the job queue, the six job types, the meeple that runs them, and the two singletons that hold the economy and the population.

```mermaid
classDiagram
    direction TB
    class JobSystem {
        <<autoload>>
        +signal changed
        +signal job_rejected(job)
        +signal worker_idle(worker, offers)
        +workers: Array[Meeple]
        +EXTRA_JOBS = 3
        +add(job): bool
        +take(): Job
        +finish(job)
        +requeue(job, worker)
        +cancel(job)
        +find_idle_job(worker): IdleJob
        +take_partner(job): HaulJob
        +recall_hauls(site)
        +capacity() / has_room(n)
        +reset()
    }
    class Job {
        +cancelled: bool
        +start(worker)
        +update(worker, delta): bool
        +abort(worker)
    }
    class Meeple {
        +job: Job
        +grid: Grid
        +position: Vector2
        +global_position: Vector2
        +tick(delta): bool
        +move_to(pos, stop_cells)
        +stop()
        +has_arrived(): bool
        +carry(kind, amount)
        +abandon_job()
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
        +MAX_GROUND_DROPS = 30
        +count(kind): int
        +available(kind): int
        +add(kind, n) / spend(kind, n)
        +reserve(kind, n) / unreserve(kind, n)
        +claim_closest(kind, pos): ResourceDrop
        +claim_reserved(drop) / release(drop)
        +closest_loose(kind, pos)
        +food_cap() / food_full()
        +register(drop) / unregister(drop)
        +reset()
    }
    class HarvestJob {
        +target: Harvestable
    }
    class HaulJob {
        +site: Building
        +kind: String
    }
    class CollectCropJob {
        +farm: Farm
    }
    class IdleJob {
        +site: Building
        +end()
    }
    class ChopJob {
        +target: Harvestable
    }
    class FarmJob {
    }
    class StoreJob {
    }
    Job <|-- HarvestJob
    Job <|-- HaulJob
    Job <|-- CollectCropJob
    Job <|-- IdleJob
    IdleJob <|-- ChopJob
    IdleJob <|-- FarmJob
    IdleJob <|-- StoreJob
    JobSystem ..> Job : pending and active
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
    class DevSpeed {
        <<autoload>>
        +FAST = 3.0
        +KEY = X
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
        +site_under_mouse(tree) static
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

