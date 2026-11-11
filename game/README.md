# game/

**What lives here:** the new game, built by the core rewrite. One folder per feature. The plan is issue #57 and the design is [docs/core-design.md](../docs/core-design.md).

The old jam game is in `assets/` and in the scripts of the project root. Nothing in here may call it.

| Folder | What lives there |
| --- | --- |
| `core/` | Game, Events, Settings, Audio, Data, and the dev settings |
| `world/` | The ground world and its generator |
| `village/` | Grid, stock, jobs, and the village object |
| `meeples/` | Meeple rules and the meeple shader |
| `buildings/` | Building rules, and one folder per building kind |
| `nature/` | Trees, rocks, bushes, drops |
| `giant/` | The giant and the map on its back |
| `ui/` | HUD, build menu, building panel, menus |
| `dev/` | Stress tests, debug overlay, preset villages. Nothing here goes into the export |

## Simulation and picture

Inside a feature folder there are two kinds of code, each in its own folder.

- **`sim/`** holds data and rules. It must run with no window. It never touches a node, the camera, the mouse, a sprite, a tween or a sound.
- **`view/`** reads the simulation and draws it. It never changes simulation data. It sends a command.

A file that is neither, such as a data file or a scene, sits in the feature folder itself.

## Every folder has a page

Each folder has a `README.md` like this one. It is the short page for that system: what it does, how to use it, and where its tests are. Update it in the pull request that changes the system.
