---
name: mm-pull-request
description: Open a pull request on Mighty Meeple the way the team's rules require. Use when a change is ready to go up, or when asked to put work on a branch.
---

# Open a pull request

**Goal:** a pull request into `core-rewrite` that passes the checks and leaves reviewing and merging to people.

The core rewrite is under way, so every pull request goes into the branch `core-rewrite`. `master` is frozen. The plan is issue #57.

The rules behind these steps are in `CONTRIBUTING.md` and `CLAUDE.md`.

## Steps

1. Work in your own worktree or clone, cut from the latest `origin/core-rewrite`. Never stash, reset or switch branches in a checkout that someone else is using.

   ```bash
   git fetch origin
   git worktree add <path> -b <type>/<short-name> origin/core-rewrite
   ```

2. Name the branch `feature/...`, `fix/...`, `art/...` or `chore/...`.
3. Keep it to one part of the plan. A core pull request may be big. A big one comes with a short walkthrough, a demo scene and tests.
4. Run both checks before every push. CI does not run on a push to your own branch. The `mm-godot-check` skill has the commands and the traps.
5. Read the diff of every `.tscn` and `.tres`. Revert any scene you did not mean to change.
6. Commit the `.uid` and `.import` files that Godot made next to new files.
7. Write a commit message that says what changed and why, in one line.
8. Push the branch and open the pull request with `gh pr create --base core-rewrite`. Fill in the template: what changed, the "done" lines of the issue it claims with the proof for each, how a person tests it, and the checklist. Name the issue with "Part of #N". Do not write a closing keyword: the issue is closed by hand after the merge.
9. Stop there. A person reviews and merges. Never approve or merge a pull request yourself.

## Leave people to the person you work for

- Do not request reviews, mention anyone or assign anyone. `CODEOWNERS` decides who GitHub asks.
- Do not address questions to teammates in the pull request, the commits or the comments. Ask the person you are working for.
- If someone comments or reviews, report what they said. Do not reply for your person.

## Rules

- Follow the code conventions in `CLAUDE.md`. Match the style of the file you are editing.
- Game files must not point into `ART/`.
- New code goes in `game/` and `addons/`. Leave the old game in `assets/` and the root scripts alone.
- If the pull request changes the design, update `docs/core-design.md` in the same pull request. `docs/architecture.md` shows the old code and is not updated.
- Do not add lines to `.github/ci/known-problems.txt`.
