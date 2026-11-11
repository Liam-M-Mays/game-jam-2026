# Contributing

**The short version:** make a branch from `core-rewrite`, push it, open a pull request into `core-rewrite`, get Liam's approval, merge.

This applies to everyone: the three of us, and any AI agent working for one of us.

## This branch is the core rewrite

You are reading the copy of this file on the branch `core-rewrite`. The core of the game is being rewritten here. The plan is issue #57 and the design is [docs/core-design.md](docs/core-design.md).

- All rework goes into `core-rewrite` through pull requests.
- `master` is frozen until the rework is done and works. It keeps the jam game as a fallback. The one exception is art that only touches `ART/`. That follows the copy of this file on `master`.
- When art lands on `master`, `master` is merged into `core-rewrite`. It never goes the other way before the switch (issue #77).
- Liam reviews every pull request. A core pull request may be big. Parts are preferred. A big one comes with a short walkthrough, a demo scene and tests. Once the core works, one pull request does one thing again.
- New code goes in `game/` and `addons/`. The old game in `assets/` and the root scripts stays as it is until issue #36 removes it.

## The workflow in five steps

1. Get the latest `core-rewrite`.

   ```bash
   git switch core-rewrite
   git pull
   ```

2. Make a branch. Name it `feature/...`, `fix/...`, `art/...` or `chore/...`.

   ```bash
   git switch -c feature/village-tick
   ```

3. Commit as you go, then push the branch.

   ```bash
   git push -u origin feature/village-tick
   ```

4. Open a pull request on GitHub with `core-rewrite` as the base, and fill in the template. Write "Part of #60" to link the issue.

   ```bash
   gh pr create --base core-rewrite
   ```

5. When Liam has approved and the checks are green, the pull request is merged and the branch deleted.
6. Close the issue by hand once its last pull request is merged. GitHub only closes issues by itself from the default branch.

## What GitHub enforces

- `master` and `core-rewrite` cannot be pushed to, force-pushed or deleted. Changes arrive through pull requests only.
- A pull request needs **1 approval** from someone other than its author.
- The repo owner can merge their own pull requests after reviewing them, but still only through a pull request.
- Two checks run on every pull request: **Repo checks** and **Godot checks**. See [docs/ci.md](docs/ci.md).
- The checks do not run on a push to your own branch. Run both yourself before every push.

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

- Godot creates a `.uid` file next to every script and a `.import` file next to every asset. **Commit them together with the file.** The one exception is `ART/`: CI does not ask for these files there.
- Art the old game uses is in `assets/`. Art the new game uses goes in `game/`. Source files and unused art go in `ART/`. See [docs/art-folders.md](docs/art-folders.md).

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

## If your push to core-rewrite was rejected

Your commits are safe. Move them to a branch and open a pull request:

```bash
git switch -c my-work
git push -u origin my-work
```

Then put your local `core-rewrite` back in line with GitHub. This only touches your local `core-rewrite`; your commits stay on `my-work`.

```bash
git switch core-rewrite
git reset --hard origin/core-rewrite
```
