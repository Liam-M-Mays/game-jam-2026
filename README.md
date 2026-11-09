# Mighty Meeple

A village-building game made with Godot 4.7. It started as a 49-hour entry for the 2026 UNCC Fall 49er Game Jam, and development continues.

You run a village of meeples that lives on the back of a walking giant. Harvest wood, stone and food, build huts and farms, and keep everyone fed.

## Run it

1. Install **Godot 4.7.2** (the standard build, not .NET).
2. Open `project.godot` in Godot and press F5.

The first time you open a fresh clone, Godot prints script errors while it builds its cache. Close the project, open it again, and they are gone.

## How we work

- Nobody pushes to `master`. Work on a branch and open a pull request.
- A pull request needs one approval and green checks before it merges.
- Step-by-step commands are in [CONTRIBUTING.md](CONTRIBUTING.md).

## Where things are

| Path | What lives there |
| --- | --- |
| `assets/` | Everything the game uses: scenes, scripts, shaders, art, audio, fonts |
| `ART/` | Art source files. Today it also holds in-game art, see [docs/art-folders.md](docs/art-folders.md) |
| `Main_Menu.tscn`, `HUD.gd` and the other root scripts | Menus and HUD |
| `docs/` | Architecture diagrams, and how the checks work |
| `.github/` | CI, issue forms, pull request template, code owners |

## More

- [Architecture diagrams](docs/architecture.md)
- [How the automatic checks work](docs/ci.md)
- [Credits and third-party assets](CREDITS.md)

No license has been chosen for this repository yet.
