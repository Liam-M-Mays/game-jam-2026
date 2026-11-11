# addons/

**What lives here:** shared tools that know nothing about the game's rules, so each can be tested alone.

| Addon | What it does | Issue |
| --- | --- | --- |
| [Sprite batch](sprite_batch/README.md) | Draws a village as one batch, with its atlas. It also finds the thing under the mouse | #61 |
| [Effects toolkit](effects/README.md) | The outline and the effects: flash, squash, wobble, pop, shake, grow in, blueprint ghost, one-shot sprites, lit cells | #62 |
| Building editor | Add and edit buildings inside Godot | #33 |

The sprite batch and the effects toolkit exist. The building editor does not yet. Each addon gets its own folder with a `README.md`.

The effects toolkit builds on the sprite batch. The sprite batch does not know the effects toolkit.
