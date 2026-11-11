# game/nature/

**What lives here:** trees, rocks, bushes and the drops they leave.

So far it holds the data files of the five kinds. The rules, such as chopping and regrowth, come with #66.

## The files

| File | What it is |
| --- | --- |
| `kinds/tree.tres`, `rock.tres`, `big_tree.tres`, `bush.tres`, `big_rock.tres` | One data file per kind: its name, its footprint and its sprite |
| `nature_kind.gd` | `NatureKind`: the script of a data file |
| `nature_kinds.gd` | `NatureKinds`: loads the five data files |
| `art/bush.png` | A copy of the bush sheet from `ART/`, which game files may not use |

## The five kinds

The numbers are the jam game's.

| Kind | Cells wide | Sprite, in art pixels | From the cell to the middle of the sprite |
| --- | --- | --- | --- |
| `tree` | 1 | 6 by 8 | (0, -3) |
| `rock` | 1 | 4 by 4 | (0, -1) |
| `big_tree` | 2 | 10 by 12 | (3, -5) |
| `bush` | 2 | 16 by 10, the full bush | (3, -1) |
| `big_rock` | 2 | 10 by 6 | (3, -2) |

- Every kind is one row deep.
- The tree and rock sprites are cut from `assets/Art/Environment/Starter_sprites.png`, for now.
- A data file holds no harvest number yet. Hits to break, drops, food and regrowth come with #66. The four other pictures of the bush come with it too.

## Using it

```gdscript
for kind in NatureKinds.all():        # in the order of the jam game's spawn list
	print(kind.kind_name, kind.width)
NatureKinds.find(&"big_tree")         # one kind, or null
NatureKinds.index_of(&"bush")         # its place in the list: a world stores a kind as this number
```

A new kind is a new data file and one more line in `NatureKinds.FILES`, at the end.

## Tests

`tests/test_nature_kinds.gd`. Run it with `bash .github/ci/run_tests.sh --only=game/nature`.

`game/dev/worldgen/nature_compare.tscn` draws the five kinds next to the jam game's own scenes and counts the pixels that differ. See [its page](../dev/worldgen/README.md).

Built by: #48 (the data files) and #66 (the rules). The rules for this folder are in [game/README.md](../README.md).
