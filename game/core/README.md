# game/core/

**What lives here:** the things every part of the game may use.

- The global services: Game, Events, Settings, Audio and Data. None exists yet.
- `dev_settings.gd`: the dev settings and their defaults. Today: the world size (100,000 cells) and the tick rate (20 a second).
- `dev_settings.tres`: the saved values. Open it in the Godot Inspector to change one. Godot only writes a value into the file when it differs from the default.
- Read them in code with `DevSettings.load_settings()`.

Built by: #60. The rules for this folder are in [game/README.md](../README.md).
