---
name: mm-pull-request
description: Open a pull request on Mighty Meeple the way the team's rules require. Use when a change is ready to go up, or when asked to put work on a branch.
---

# Open a pull request

**Goal:** one small pull request that does one thing, passes the checks, and leaves reviewing and merging to people.

The rules behind these steps are in `CONTRIBUTING.md` and `CLAUDE.md`.

## Steps

1. Work in your own worktree or clone, cut from the latest `origin/rework` (while the rework runs, see `docs/rework-plan.md`). Never stash, reset or switch branches in a checkout that someone else is using. Name the local branch `wt/<short-name>`, so Liam can check out the pull request branch in his own folder.

   ```bash
   git fetch origin
   git worktree add <path> -b wt/<short-name> origin/rework
   ```

2. Push to a branch named `feature/...`, `fix/...`, `art/...` or `chore/...`: `git push origin HEAD:<type>/<short-name>`.
3. Keep it to one thing. Do not mix a refactor with a fix.
4. Run the checks. The `mm-godot-check` skill has the commands and the traps.
5. Read the diff of every `.tscn` and `.tres`. Revert any scene you did not mean to change.
6. Commit the `.uid` and `.import` files that Godot made next to new files.
7. Write a commit message that says what changed and why, in one line.
8. Push the branch and open the pull request with `--base rework`. Fill in the template: what changed, how a person tests it in the game, the inventory (`python3 .github/ci/pr_inventory.py`) and the checklist. Write "Part of #N", not `Closes #N`.
9. Stop there. A person reviews and merges. Never approve or merge a pull request yourself.

## Leave people to the person you work for

- Do not request reviews, mention anyone or assign anyone. `CODEOWNERS` decides who GitHub asks.
- Do not address questions to teammates in the pull request, the commits or the comments. Ask the person you are working for.
- If someone comments or reviews, report what they said. Do not reply for your person.

## Rules

- Follow the code conventions in `CLAUDE.md`. Match the style of the file you are editing.
- Game files must not point into `ART/`.
- If the pull request changes the structure of the code, update `docs/architecture.md` in the same pull request.
- Do not add lines to `.github/ci/known-problems.txt`.
