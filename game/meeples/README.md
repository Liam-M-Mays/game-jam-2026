# game/meeples/

**What lives here:** meeples as rows of data, the rules that move them, and the picture that draws them.

There is no node and no script per meeple. A meeple is a row number in a set of arrays, one set per village.

| Folder | What is in it |
| --- | --- |
| `sim/` | The data and the rules. Runs with no window |
| `view/` | The picture: the view class, the look and the meeple shader |
| `art/` | The meeple art, copied from the jam game |
| `tests/` | The tests. Run them with `bash .github/ci/run_tests.sh --only=game/meeples` |

Built by: #61 (the look) and #64 (the rows, the rules and the view). The rules for this folder are in [game/README.md](../README.md).

## The simulation, in `sim/`

Start reading at `village_meeples.gd`.

| File | What it is |
| --- | --- |
| `village_meeples.gd` | `VillageMeeples`: the part of a village that holds the meeples. Rows, walking, carrying, dying |
| `meeple_wander.gd` | `MeepleWander`: where an idle meeple strolls next, and the list of hangouts |
| `meeple_topple.gd` | `MeepleTopple`: how a dying meeple tips over and fades, as maths |
| `meeple_numbers.gd` | `MeepleNumbers`: every number of the jam game's meeple, in one place |
| `meeple_commands.gd` | `MeepleCommands.Spawn` and `MeepleCommands.Kill`: the two commands |

```gdscript
var meeples := VillageMeeples.new()
village.add_part(Village.MEEPLES, meeples)

var spawn := MeepleCommands.Spawn.new(Vector2(40, 25))   # in art pixels
village.send(spawn)
var meeple := spawn.meeple                                # its id

meeples.walk_to(village, meeple, point)          # a job sends it somewhere
meeples.walk_to(village, meeple, point, thing)   # ... and it stops on that thing's first cell
meeples.carry(meeple, kind, 2)                   # what it shows: two pieces of a kind
meeples.release(village, meeple)                 # its job is over: it wanders
village.send(MeepleCommands.Kill.new(meeple))    # it tips over, fades and is taken out
```

### Rows and ids

- Each array of `VillageMeeples` is one column: `spots[7]` and `hues[7]` belong to the meeple in row 7.
- **A meeple is named by its id, not by its row.** When a meeple is taken out, the last row moves into its place, so the rows stay packed and no row is left behind. `row_of(id)` gives the row of a meeple right now.
- The picture reads the arrays. It never writes to them.
- A part keeps no pointer to its village. The village is handed to every call.

### Units

- A village works in **art pixels**, like `GridLayout`.
- The jam game measured a walk in its own units. **Ten jam units are one art pixel.**
- `MeepleNumbers` holds each jam number and turns it into art pixels once. So the jam game's 100 units a second are 10 art pixels a second.
- **One number is the exception: the reach for changing hangout.** The jam game measured that one distance on the screen side of its scale, where one unit is one art pixel already. So its 100 stays 100 art pixels.

### Walking

- A walk is a straight line. Each tick is one step.
- **On a job: 100 jam units a second. Wandering: 30.** Every meeple walks at the same speed (Decision 21).
- `walk_to` is what a job calls. Jobs come with #65.
- A meeple aims 3 jam units below the point it is sent to, so it is drawn in front of what is there.
- With a thing to stop on, the meeple stops as soon as it stands on any cell of that thing.
- **A walk is over one tick after its last step.** The picture needs that tick to glide the last step in. `meeple_arrived` is sent then.
- After that the meeple waits for its job. `release` lets it go.
- A listener of `meeple_arrived` may send, let go or kill any meeple, also one that arrives on the same tick.
- A meeple that a listener lets go, sends on or kills inside another arrival does not send its own `meeple_arrived` for that tick.

### Waiting costs nothing

- Only the meeples in `walkers` and `dying` are stepped on a tick.
- A meeple that stands still sleeps on one of the village's wake-up timers (`village.timers`).
- `steps` counts every meeple step that was run. A test checks that 500 waiting meeples add nothing to it.

### Wandering

A meeple with nothing to do wanders. These are the jam game's rules.

- Where it went idle is its **home**. The nearest hangout is its **hangout**.
- It stands for a random pause of 1.0 to 3.5 seconds, strolls to a spot, and pauses again.
- With a hangout: the spot is on an empty cell at most 2 steps from it, nudged by up to 12 by 6 jam units. Up to 8 cells are tried. A spot it can reach without crossing a hangout wins. If none is clear, the closest tried spot wins.
- With no hangout, or none with an empty cell near it: a random spot 15 to 60 jam units from its home, on the grid. After 8 tries with no luck it stays put.
- On each stroll there is a 15 percent chance that it picks its hangout again. Near ones are much more likely: the weight of a hangout is 1 / (1 + (distance / 100 art pixels) squared), counted from where the meeple stands. So one 100 art pixels away, about 14 cells, is half as likely as one right here. It also picks again when its hangout is gone.

**A hangout** is a thing on the grid that meeples stroll around. In the jam game these were the finished buildings. Buildings come with #67. Until then, whoever finishes a building calls `meeples.wander.add_hangout(village, thing)`, and `remove_hangout(thing)` when it goes.

- **After a move: remove the hangout and add it again.** The list keeps the place a hangout had when it was added. It does not ask the grid again, so that picking a hangout stays a walk over one array.

### Carrying

- `carry(meeple, kind, amount)` sets what a meeple shows: how many pieces, and the kind as a number.
- It does not touch the stock. Stock is #63.

### Dying

- `kill` freezes the meeple where it is. It tips over to a random side, bounces once, lies still, fades, and is then taken out: about 2 seconds.
- The numbers: 90 degrees in 0.45 s, faster and faster. Back up 0.2 radians in 0.08 s and down again in 0.08 s. Still for 0.6 s. Fade in 0.8 s.
- **There is no tween.** `topples` and `fades` are set on the tick, and the meeple shader draws them.
- `meeple_died` is sent once. The hurt sound of #73 listens to it.

### What the part tells others

| Signal | When |
| --- | --- |
| `meeple_added(row)` | A meeple was added |
| `meeple_removed(meeple, row, moved_from)` | A meeple was taken out. The meeple from `moved_from` is in `row` now |
| `meeple_changed(row)` | Its look changed: walking or standing, its load, or it started to die. This one is for the picture |
| `meeple_died(meeple, spot)` | It started to die |
| `meeple_arrived(meeple)` | It reached the place its job sent it to |
| `closed` | The village was closed |

- A job listens to `meeple_arrived`, not to `meeple_changed`.
- A listener of `meeple_changed` may send, let go or kill the meeple too. When it does that as a walk ends, that walk sends no `meeple_arrived`.

## The picture, in `view/`

| File | What it is |
| --- | --- |
| `meeple_view.gd` | `MeepleView`: reads the rows and feeds the sprite batch |
| `meeple_look.gd` | `MeepleLook`: how a meeple is drawn. The jam game's pictures, colours, bounce and tilt |
| `meeple_batch.gdshader` | The shader that draws a village batch: plain sprites and meeples |

```gdscript
var look := MeepleLook.new()
look.add_to(atlas)          # before atlas.build()
look.shape(rows)            # tells the rows how big a meeple is
batch.setup(rows, MeepleLook.SHADER)
look.dress(batch)

var view := MeepleView.new()
view.load_names = {1: &"wood", 2: &"stone"}   # the look name of each load kind
view.setup(meeples, batch, look)
add_child(view)
```

- **Each meeple is one mover of the [sprite batch](../../addons/sprite_batch/README.md),** with the same number as its row.
- **The glide:** the village steps 20 times a second and the screen draws more often. In every frame a walking meeple is put between the spot it had one tick ago and the spot it has now. `Game.clock.fraction()` says how far between.
- The view only works out the walking and the dying meeples. With nobody walking or dying, it tells the batch nothing.
- **While anybody walks or dies, the batch looks at every mover in each frame,** the standing ones too. The view hands it the places of all meeples, because the batch has no call for a single mover.
- `rows` is a `BatchRows` made with the game's grid numbers and art scale. The view turns art pixels into the pixels of the batch.
- The position of a meeple is the middle of its body, as in the jam game.
- A walking meeple shows the walking pose until its glide is over.
- The topple and the fade glide the same way. A meeple that dies walking falls from the tilt it had, as in the jam game.
- The fade is the alpha of the meeple's colour. The topple uses the second shader number, which is the bounce start of a living meeple.
- `let_go()` stops the view. It runs by itself when the village is closed.

## Tests, in `tests/`

| File | What it checks |
| --- | --- |
| `test_meeple_rows.gd` | Rows and ids, a waiting meeple costs nothing, 10,000 spawns and deaths leave no row behind, carrying, a closed village lets go |
| `test_meeple_walk.gd` | The two speeds, the straight line, the aim, stopping on a thing, the tick a walk is over, a listener that acts inside an arrival |
| `test_meeple_wander.gd` | The wander rules asked by hand: the pause, the stroll around home, hangouts, the spot near a hangout, the 8 points, the 15 percent and the reach |
| `test_meeple_strolls.gd` | The same rules on a meeple that ticks: the 15 percent, where a stroll ends, the home and the hangout after a job |
| `test_meeple_listeners.gd` | A listener of `meeple_changed` that kills, sends on, lets go or closes the village as a walk ends, and the other walks that end on the same tick |
| `test_meeple_dying.gd` | The topple and the fade tick by tick, the side, the freeze, the event |
| `test_meeple_same_seed.gd` | The same seed and commands give the same village, with the picture or without |
| `test_meeple_view.gd` | One mover per row, the glide, the poses, the load, the topple and the fade in the batch |
| `test_meeple_look.gd` | The numbers of the look and its copy of the bounce formula |

- `meeple_test_kit.gd` holds what the tests share.
- The tests prove numbers. **A look is proven by a picture:** see [game/dev/stress/README.md](../dev/stress/README.md).

## Limits

- **Walking is a straight line.** Nothing is walked around. Path-finding is #16.
- **A hangout stands in for a finished building.** A building site in the way does not count as blocking, because nobody tells the meeples about sites yet.
- **A hangout keeps the place it had when it was added.** A thing that is moved has to be removed and added again, or the meeples measure to its old place.
- **The view owns every mover of its batch.** Mover number and meeple row are the same number. So no other part can put its own movers into the batch of a village. Animals would need the batch or the view to change first.
- **While anybody walks or dies, the batch looks at every mover in each frame.** Only a village where everybody stands costs the picture nothing.
- **Picking a hangout looks at every hangout.** That is fine for hundreds. It is not measured for thousands.
- **A dying meeple is stepped on every tick,** for about 41 ticks, also while it lies still.
- **A shirt can be one colour step of 255 off the jam game's.** The batch keeps the colour of a sprite as a 16-bit number.
- **A meeple that lies on its side reaches further out of its box than a standing one.** Right at the edge of the screen it can be left out a little early.
