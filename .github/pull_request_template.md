## What changed

<!-- One or two lines. Link the issue: "Part of #60". No closing keyword: the issue is closed by hand after the merge. -->

## Done lines this claims

<!-- Copy each "done" line of the issue that this pull request finishes. Next to it, name the test or the picture that proves it. -->

-

## How to test it

<!-- Steps a reviewer can follow in the game. Add a screenshot or GIF for anything visual. A big pull request also gets a short walkthrough and a demo scene. -->

1.

## Before asking for review

- [ ] I ran the game and tried the change myself
- [ ] Every scene (`.tscn`) in this pull request is changed on purpose, with no stray moves or hidden nodes
- [ ] New scripts and assets include their `.uid` or `.import` file
- [ ] The base of this pull request is `core-rewrite`
- [ ] I ran the repo checks, the Godot checks and the linter myself before pushing
- [ ] New rules in `game/` or `addons/` have a test
- [ ] Every new class and public function has a `##` doc comment, and the folder's `README.md` is up to date
- [ ] CI is green, or I explained below why it is not
