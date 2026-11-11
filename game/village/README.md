# game/village/

**What lives here:** one village as an object that ticks: its grid, its timers, its random numbers, its stock, and the places where jobs, meeples and buildings hang.

Nothing about a village lives in a global. Two villages run side by side, and a test runs one with no window.

## The files

Simulation code is in `sim/`. Picture code is in `view/`. The data files of the resource kinds are in `resources/`.

| File | What it is |
| --- | --- |
| `sim/village.gd` | The `Village` object. Start reading here |
| `sim/village_grid.gd` | The cells of a village, as data in chunks |
| `sim/grid_layout.gd` | The maths of the slanted grid: positions, neighbours, distance, footprints |
| `sim/grid_chunk.gd` | The arrays of 16 by 16 cells |
| `sim/grid_drops.gd` | `GridDrops`: the drops on the ground, as rows. Also finds the closest loose drop |
| `sim/village_stock.gd` | `VillageStock`: the stock of a village. Start reading the stock here |
| `sim/stock_claims.gd` | `StockClaims`: what is reserved for a building site, and which hauler goes for which unit |
| `sim/stock_storages.gd` | `StockStorages`: the piles and silos, as counts |
| `sim/resource_kind.gd` | `ResourceKind`: what a data file of a resource kind holds |
| `resources/wood.tres`, `stone.tres`, `food.tres` | The three resource kinds |
| `view/drop_view.gd` | `DropView`: draws the drops with the sprite batch, each on its spot |
| `sim/village_part.gd` | The base of a part: stock, job board, meeples, buildings |
| `sim/village_command.gd` | The base of a command |

## A village

```gdscript
var village := Game.new_village(1234)          # or Village.new(1234) in a test
village.grid.add_cell(Vector2i(0, 0))
village.add_part(Village.STOCK, my_stock)      # a VillagePart
village.send(my_command)                       # a VillageCommand
village.tick()                                 # Game does this for you
```

- **Tick:** one step. It wakes the timers that are due, then steps each part in the order the parts were hung.
- **Timers:** a timer that wakes is called with the village as its first argument. A part never binds its village into a timer.
- **Seed:** `village.rng` gives every random number of the village. The same seed and the same commands give the same village.
- **Parts:** the four names are `Village.STOCK`, `JOBS`, `MEEPLES` and `BUILDINGS`. The stock is built (see below). The other three are empty until #65, #64 and #67 hang something there.
- **Every part has a `snapshot()`.** A part without one would be left out when two villages are compared, so the base class logs an error.
- **Commands:** the picture never changes the village. It sends a command, which is done at once and says if it was refused.
- **Ids:** `village.new_id()` gives the number that names a thing on the grid.
- **Compare:** `village.snapshot()` is the whole village as plain data. `village.state_hash()` is one number for it: the same village gives the same number, but compare snapshots to be sure two villages differ.
- **Close:** `Game.remove_village()` closes a village. A closed village does not tick, takes no command, no part and no timer, and holds on to nothing.

## The grid

The layout is the one of the jam game.

- Cell (x, y) sits at (x*7 + y*5, y*5) art pixels. The jam game's cell scale of 10 and the giant's 0.1 cancel out.
- A point exactly between two cells goes to the cell on the right, or to the row below. That is the jam game's answer for every cell it had. It only differs on the outer edge of column 0 and row 0, where the jam game had no cell.
- Six neighbours: (1,0), (-1,0), (0,1), (0,-1), (1,-1), (-1,1). Distance is (|dx| + |dy| + |dx+dy|) / 2.
- A cell stores its ground kind, what stands on it, who reserved it, and its loose drops.
- A cell holds one thing at most. A footprint counts right for width and down for depth, 1 to 4 each. One missing or taken cell refuses the whole footprint.
- Cells can have any coordinates, below zero too. A chunk is only made where a cell is added, so a round map costs no more than its cells.

The four questions it answers:

| Question | Call |
| --- | --- |
| Which cell is at a point? | `grid.cell_at(point)` |
| Which cells are free for a footprint at a point? | `grid.free_cells_at(point, width, depth)` |
| Which empty cells lie within N steps of a thing? | `grid.empty_cells_near(thing, steps)` |
| Which cells sit at fixed offsets from a cell? | `grid.cells_at_offsets(cell, offsets)` |

Reserving: `grid.reserve(cells, reserver)` and `grid.release(reserver)`. A reserved cell is only free for its reserver.

## The drops on the ground

A drop is one unit of wood or stone that lies where it fell. Drops are rows: a row holds the kind, the cell and the spot where the drop landed. Each cell also keeps a count per kind.

- There is no cap, and a drop never moves or expires.
- A drop is **loose** until somebody claims it. A claimed drop still lies there, but it is not found any more.
- `grid.drops.closest(kind, point)` finds the closest loose drop. It only looks at the drops on the cells around the point. `grid.drops.looked_at` says how many: 5 at most with 1,000 drops on the 100,000 cell world, 23 at most with 100,000 drops (300 lookups each, in `test_closest_drop.gd`).
- On one cell it looks at the 8 newest loose drops of the kind only (`GridDrops.MOST_LOOKS_PER_CELL`). So a heap of thousands on one cell costs no more. The pick can then be off by less than one cell.
- A row number is used again after its drop is taken. Do not keep one for later: claim the drop.

| Question | Call |
| --- | --- |
| What lies on this cell? | `grid.drops.count_at(cell, kind)`, `grid.drops.has_any(cell)`, `grid.drops.at(cell)` |
| How many lie on the ground? | `grid.drops.total(kind)`, `grid.drops.loose(kind)` |
| Which loose drop is closest? | `grid.drops.closest(kind, point)` |
| What is this drop? | `grid.drops.kind_of(drop)`, `spot_of(drop)`, `cell_of(drop)`, `claimer_of(drop)` |

The plain steps are `add_at(spot, kind)`, `add(cell, kind, count)`, `take(cell, kind, count)`, `remove(drop)`, `claim(drop, claimer)` and `unclaim(drop)`. **Game code makes and takes drops through the stock**, which counts them and keeps the reservations right.

## The stock

Each village has its own stock. It is the part under `Village.STOCK`.

```gdscript
var stock := VillageStock.new(ResourceKind.load_all())
village.add_part(Village.STOCK, stock)
var wood := stock.number_of(&"wood")

stock.drop(wood, spot)                 # one wood lies on the ground. It counts at once
stock.count(wood)                      # ground + piles + carried
stock.add(food, 2)                     # food is a number with a cap. What does not fit is lost
stock.is_full(food)
stock.add_storage(silo_id, food, 20, spot)    # a silo raises the food cap
stock.add_storage(pile_id, wood, 12, spot)    # a pile holds a count
stock.changed.connect(my_function)     # told on every change, with the kind
```

- **Resource kinds are data files** in `resources/`. A kind has a name, a number, and says if it is an item or a banked number.
    - Wood and stone are **items**. Each unit lies on the ground, sits in a pile or is carried. They are never a number in the bank.
    - Food is a **banked number** with a cap: 20, plus the capacity of every silo. A new village starts with 10. Food is never an item.
- **`count(kind)`** is the banked amount plus every unit on the ground, in a pile or carried.
- **`cap(kind)`** is the food cap for food. For wood and stone it is the room in the piles. The ground has no cap, so "have" can be higher than "room".
- **Spending more than there is** empties the stock to zero. It never goes below zero.

### Reservations and claims

`stock.claims` holds two promises. Both are made by an id, never by an object.

- **A reservation:** a building site is promised a number of units of a kind. `available(kind)` is what can still be promised: the unclaimed units minus the reserved ones.
- **A claim:** a hauler is promised one unit in particular, on the ground or in a pile. Nobody else can claim it, so two haulers never go for the same item.

```gdscript
var claims := stock.claims
claims.reserve(site_id, wood)                             # the site asks for one haul
claims.claim_closest(haul_id, site_id, wood, where_the_hauler_stands)
claims.spot_of(haul_id)                                   # where to walk
claims.pick_up(haul_id)                                   # off the ground, or out of the pile. It still counts
claims.hand_over(haul_id)                                 # into the site. It leaves the stock
claims.release(haul_id, where_the_hauler_stands)          # abort: the unit is free again, the reservation is back
```

A trip to a pile: `claims.claim_for_storage(haul_id, pile_id, drop)`, then `pick_up`, then `hand_over`. The drop is locked from the claim until it lands: it counts, but it cannot be promised to a site.

### Drawing the drops

`DropView` puts one sprite into the batch for each drop, with its middle on the spot of the drop.

```gdscript
var sprites := DropView.add_sprites(atlas, ResourceKind.load_all())   # before atlas.build()
var view := DropView.new(rows, sprites)
view.watch(village.grid.drops)
```

- A drop is a thing in the batch, in the grid row of its cell.
- The batch knows a drop by a number below zero (`DropView.thing_of(drop)`), so it never clashes with a thing of the grid.

### Limits of the stock

- **A storage cannot be taken away yet.** What happens to its content belongs to removing a building (#6).
- **Food above the cap stays.** The cap never drops today. If it ever does, the food there is stays, and nothing more fits until it is under the cap again.
- **A drop on the cell of a tree** that lies higher than the foot of the tree is drawn over the trunk. The jam game draws the trunk over it. The batch keeps the things of one cell in the order they came.
- **A lookup with few drops reads more cells.** With 1,000 drops on the big world it reads up to 893 cells to look at 5 drops. Reading a cell is one array read.
- **A listener of `stock.changed` runs on every change.** With thousands of changes a tick, a listener should only set a flag and do its work once a frame.
- **Storages are looked at one by one** when the closest pile is asked for. That is fine while piles are few.

## See it run

Open `game/dev/village_demo/village_demo.tscn` in Godot and press F6. See [its page](../dev/village_demo/README.md).

For the stock and the drops: `game/dev/stock_demo/stock_demo.tscn`. See [its page](../dev/stock_demo/README.md).

## Tests

`tests/`: `test_village.gd`, `test_village_grid.gd`, `test_grid_layout.gd`, `test_grid_questions.gd`, `test_grid_reserve_and_drops.gd`. Run them with `bash .github/ci/run_tests.sh --only=game/village`.

The stock and the drops:

| Test file | What it checks |
| --- | --- |
| `test_resource_kinds.gd` | The three data files, and that the drop pictures are the jam game's |
| `test_grid_drops.gd` | Drops as rows: kind, cell, spot, the count per cell, claiming, no cap |
| `test_closest_drop.gd` | The closest loose drop, and how many drops a lookup looks at with 1,000 and with 100,000 |
| `test_village_stock.gd` | Add, spend, the food cap, what counts, and that every change is told once |
| `test_stock_claims.gd` | Reserve, claim, pick up, hand over, release, and trips to a pile |
| `test_stock_random.gd` | 10,000 random steps: nothing below zero, nothing handed out twice |
| `test_stock_in_village.gd` | The same seed gives the same village, drops never expire, a closed village lets go |
| `test_drop_view.gd` | One sprite for each drop, on its spot |

Built by: #60, #63 and #65. The rules for this folder are in [game/README.md](../README.md).
