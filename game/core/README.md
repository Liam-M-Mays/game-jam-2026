# game/core/

**What lives here:** the things every part of the game may use.

## The global services

Two exist today. Both are loaded before any scene, under these names.

| Name | File | What it owns |
| --- | --- | --- |
| `Game` | `game.gd` | The session, pause, game speed, and which village is in view. It ticks every village |
| `Events` | `events.gd` | News from the simulation to the UI. Today: village added or removed, village in view, pause, speed |

- Settings, Audio and Data do not exist yet. Toasts join `Events` with #70.
- With no village, `Game` does nothing. So it stays quiet in the old jam game and in the menu.
- `Game` never holds data or rules of a village. Those are in the `Village` object, see [game/village/](../village/README.md).

## Time

- `sim/tick_clock.gd`: turns the seconds of a frame into whole ticks. 20 ticks a second at speed x1, 60 at x3.
- Game speed means more ticks per second. Nothing changes `Engine.time_scale`.
- One slow frame counts as a quarter second at most, so a hitch cannot ask for a pile of ticks.
- `clock.fraction()` says how far the next tick is. The picture will use it to glide between two ticks.
- `sim/tick_timers.gd`: timers that cost nothing while they wait. A thing sets a wake-up tick. A tick only looks at the timers that are due on it. Each village has its own.

## How to use it

```gdscript
Game.new_session()
var village := Game.new_village(1234)   # the seed
Game.show_village(village)
Game.speed = 3.0
Game.paused = true
village.timers.wake_after(village.ticks_for(2.0), my_function)   # in 2 seconds
```

A timer holds on to what is bound into it. Closing a village drops its timers, and `Game.remove_village()` closes it.

## Dev settings

- `dev_settings.gd`: the dev settings and their defaults. Today: the world size (100,000 cells) and the tick rate (20 a second).
- `dev_settings.tres`: the saved values. Open it in the Godot Inspector to change one. Godot only writes a value into the file when it differs from the default.
- Read them in code with `DevSettings.load_settings()`.

## Tests

`tests/`: `test_tick_clock.gd`, `test_tick_timers.gd`, `test_game.gd`, `test_dev_settings.gd`. Run them with `bash .github/ci/run_tests.sh --only=game/core`.

Built by: #60. The rules for this folder are in [game/README.md](../README.md).
