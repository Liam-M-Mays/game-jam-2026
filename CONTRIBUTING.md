# Contributing

**The short version:** make a branch, push it, open a pull request, get one approval, merge.

This applies to everyone: the three of us, and any AI agent working for one of us.

## The workflow in five steps

1. Get the latest master.

   ```bash
   git switch master
   git pull
   ```

2. Make a branch. Name it `feature/...`, `fix/...`, `art/...` or `chore/...`.

   ```bash
   git switch -c fix/farm-build-mode
   ```

3. Commit as you go, then push the branch.

   ```bash
   git push -u origin fix/farm-build-mode
   ```

4. Open a pull request on GitHub and fill in the template. Add `Closes #12` to link an issue.
5. When a teammate has approved and the checks are green, press **Merge**, then delete the branch.

## What GitHub enforces

- `master` cannot be pushed to, force-pushed or deleted. Changes arrive through pull requests only.
- A pull request needs **1 approval** from someone other than its author.
- The repo owner can merge their own pull requests after reviewing them, but still only through a pull request.
- Two checks run on every pull request: **Repo checks** and **Godot checks**. See [docs/ci.md](docs/ci.md).

## Commit messages

Say what changed and why, in one line. The history is how we find out later why something is the way it is.

| Instead of | Write |
| --- | --- |
| `stuff` | `Stop farms entering build mode when no barn has a free slot` |
| `fix` | `Fix HUD scene after merge: restore the hunger bar node` |
| `push` | `Add stone pile building and its 14-frame sheet` |

## Scenes need extra care

Godot rewrites parts of a `.tscn` file every time it saves, so scenes are where merges go wrong.

- **Tell the team before you work in a shared scene**: `assets/hud.tscn`, `Main_Menu.tscn`, `assets/Scenes/Levels/game.tscn`.
- **Read the diff of every scene before you commit.** If a scene changed and you did not mean to touch it, throw the change away:

  ```bash
  git restore path/to/scene.tscn
  ```

- **Do not commit temporary editor states**, such as nodes you hid or moved to take a screenshot.
- Keep pull requests small. One scene, one purpose.

## New files

- Godot creates a `.uid` file next to every script and a `.import` file next to every asset. **Commit them together with the file.**
- Art the game uses goes in `assets/`. Source files and unused art go in `ART/`. See [docs/art-folders.md](docs/art-folders.md).

## Issues and the board

- Every issue has one type: `feature`, `task`, `art`, `fix`, `chore` or `feedback`. The issue forms set it for you.
- A `feature` is a parent. The `task` and `art` issues it needs hang under it as sub-issues.
- Issues move through five states on the [project board](https://github.com/users/Liam-M-Mays/projects/5): **Proposed**, **Backlog**, **In progress**, **Testing**, **Finished**.
- New ideas and player feedback start in Proposed. They move to Backlog when the team agrees to do them. A `fix` starts in Backlog.
- Put yourself as the assignee when you start. Move the card when the state changes.
- The full rules, with diagrams: [docs/workflow.md](docs/workflow.md).

## Run the checks yourself

```bash
python3 .github/ci/checks.py repo
```

```bash
GODOT="/path/to/Godot" bash .github/ci/run_godot_checks.sh
```

The first one takes a second. The second one takes a few minutes and needs Godot 4.7.2.

## If your push to master was rejected

Your commits are safe. Move them to a branch and open a pull request:

```bash
git switch -c my-work
git push -u origin my-work
```

Then put your local master back in line with GitHub. This only touches your local `master`; your commits stay on `my-work`.

```bash
git switch master
git reset --hard origin/master
```
