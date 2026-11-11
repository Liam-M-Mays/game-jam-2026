# What the jam game does

**What this is:** every behaviour of the jam game that a check of the old code found on 2026-11-10. There are 534 lines. Each line sits under the issue that owns it and says what happens to it in the new game.

> An AI agent wrote this list from the old code. Liam has not reviewed it.

The issue that checks this list at the end is [#75](https://github.com/Liam-M-Mays/game-jam-2026/issues/75).

## How to read it

| Mark | Means | Lines |
| --- | --- | --- |
| **Keep** | The new game must do this too | 399 |
| **Changed** | Changed on purpose. The line names the decision in [core-design.md](core-design.md#decisions) | 79 |
| **Giant only** | Belongs to the game on the giant's back | 44 |
| **Out of scope** | Only about how the old code was built. Nothing to do | 12 |

- A box is ticked by the pull request that proves the line, or by Liam.
- An agent does not change a mark from **Keep** to **Changed** alone. That needs a decision, or Liam's yes with a date.
- The name in `code style` at the end of a line is its id in the plan data.

## #60 Core: one village as a simulation that ticks

[Issue #60](https://github.com/Liam-M-Mays/game-jam-2026/issues/60)

- [ ] **Keep** · The map is a grid of slanted (parallelogram) cells. Each row is shifted sideways from the row above, so the grid leans like the 3/4 art. `world-grid-cell-layout`
- [x] **Keep** · Each cell has six neighbours, and distance on the grid is counted the hex way. `world-grid-neighbours`
- [x] **Keep** · A point in the world maps to the cell whose centre is nearest in the slanted grid. A point off the block or over a missing cell maps to no cell. `world-cell-lookup`
- [x] **Keep** · A cell holds at most one object (a resource or a building). An object with a footprint needs every cell of the footprint to exist and be empty, counted from the anchor cell to the right for width and down the rows for depth. `world-cell-one-occupant`
- [x] **Keep** · A placed object stands at the position of its first (anchor) cell and marks all of its cells as taken. `world-place-object`
- [ ] **Keep** · Removing an object frees its cells, clears any highlight on them and deletes the object. `world-remove-object`
- [x] **Keep** · The grid answers four questions for other systems: which cell is at a point, which cells are free for a footprint at a point, which empty cells lie within N steps of an object, and which cells sit at fixed offsets from a cell. `world-grid-queries`
- [x] **Keep** · Every grid object has a footprint width and a footprint depth, each between 1 and 4 cells. `world-object-footprint`
- [ ] **Changed** · The job queue (JobSystem) and the population rules (Population) are global singletons that live for the whole program, including the main menu. JobSystem announces every change to jobs or workers, and that announcement refreshes hunger, HUD counters, the build menu and lets construction sites post more haul jobs. *Now:* Decision 3: job board and population belong to the village, no globals. HUD, build menu and site refreshes listen to the news of the village in view, sent by that village itself. Events knows no village (Decision 33). `meeples-autoload-singletons`
- [ ] **Changed** · The game scene is a plain root with no script. It holds the giant rig (which contains the village and the camera), five scrolling background layers, the HUD, and the giant sound node. Game rules live in the autoloads, the HUD, the grid and the build system. *Now:* Decisions 3 and 4: the rules move out of the autoloads, the HUD and the grid nodes into one Village object, with the picture apart from it. The giant rig and backgrounds in this scene go with #76. `feel-scene-top-level`
- [ ] **Changed** · Seven global systems are loaded before any scene, in a fixed order, and live for the whole session across menu, game and restarts. *Now:* Decision 3: nothing about a village lives in a global. JobSystem, Inventory and Population move under the Village. The globals that stay are Game, Events, Dev settings (no player options), Audio and Data. `feel-project-autoloads`

## #61 Core: draw a village as one sprite batch

[Issue #61](https://github.com/Liam-M-Mays/game-jam-2026/issues/61)

- [ ] **Keep** · Objects on the grid are drawn back to front by row, so things lower on screen are in front. Within one row a newly placed object is put behind an object to its left. `world-draw-order`
- [ ] **Changed** · Only a left mouse button press on the object's own click area counts as a click on it. *Now:* Decision 7: clicks are found with maths, not click areas. 'Left press only' stays. `world-object-click`
- [ ] **Changed** · The files in assets/Res cut single sprites out of shared sheets for the resources, drops and the meeple shirt. *Now:* Decision 7: one atlas built from the art files replaces the cut-out files. The same sprite regions must carry over. Wood and stone point into ART/ today (#55). `world-res-atlas-cutouts`
- [ ] **Keep** · A meeple is a tiny two-part sprite: a 1x2 pixel body (the shirt) with a 3x2 pixel head sitting on top, drawn at 10x scale. The head is a separate animated sprite so it can swap to carrying frames. `meeples-scene-composition`
- [ ] **Keep** · Every meeple gets a random shirt colour the moment it appears. Only the body is tinted; the head stays off-white. `meeples-random-shirt-colour`
- [ ] **Changed** · Meeples are children of the Grid node, move in the grid's own local coordinates and are depth-sorted by Y together with buildings and resources. Because of this the whole village rides along with whatever the grid is attached to (the giant's back). *Now:* Decisions 5 and 7: meeples are rows drawn by the batch in row order, not Y-sorted child nodes. The depth look must stay. Riding along with the giant is #76. `meeples-live-in-grid-space`
- [ ] **Keep** · While walking, a meeple rocks side to side and stretches up and down. While standing still it does not rock and only breathes with half the stretch. *But:* #46: each meeple has its own timing. The motion itself is unchanged. `meeples-walk-bob-wobble`
- [ ] **Keep** · A meeple carrying one wood or one stone shows the item held above its head. The head goes back to normal when it delivers, stores or drops the item. `meeples-carry-single`
- [ ] **Keep** · A meeple carrying two of the same resource shows a taller stack above its head. `meeples-carry-double`
- [ ] **Keep** · Art is drawn with crisp, unsmoothed pixels, using the compatibility (OpenGL) renderer on every platform. `feel-project-pixel-rendering`
- [ ] **Keep** · Every meeple gets a random shirt colour when it appears; the head keeps its own off-white colour. `effects-meeple-colour`
- [ ] **Keep** · A walking meeple stretches up and down and rocks side to side. A standing meeple only breathes with half the stretch and no rocking. *But:* #46: each meeple has its own timing. The motion itself is unchanged. `effects-meeple-walk-bob`
- [ ] **Keep** · A meeple carrying something shows the load on its head: one or two pieces of wood or stone. The head goes back to normal when the load is delivered or dropped. `effects-meeple-carry-head`
- [ ] **Keep** · All art is drawn as crisp pixel art: world sprites are tiny pictures shown at 10 times size with no smoothing, and effects copy that size. `effects-pixel-art-rendering`
- [ ] **Changed** · The right-click pause and the building-site tooltip test the mouse against the site's whole sprite frame rectangle, including its transparent parts. Hover glow and left clicks use the smaller click box set in each building scene. *Now:* Decision 7: clicking is done with maths, not click areas. Hover, left click, right-click pause and the site tooltip all use the same one hit test. `gap-site-hit-test-sprite-rect`

## #62 Core: effects toolkit for the shader and the sauce

[Issue #62](https://github.com/Liam-M-Mays/game-jam-2026/issues/62)

- [ ] **Keep** · A respawned resource pops up from a squashed sliver to full size with a small overshoot. Resources placed at game start do not play this. `world-respawn-grow-in`
- [ ] **Keep** · Each hit that does not break the resource makes it squash, flash white and wobble side to side. `world-harvest-hit-feedback`
- [ ] **Keep** · Hovering the mouse over a resource or building gives it a soft white glow and lights up the cells it stands on. `world-object-hover`
- [ ] **Keep** · A selected or marked object gets a solid outline that can be tinted with a colour. `world-object-select-outline`
- [ ] **Keep** · A refused click makes the object flash red and shake left and right. `world-object-reject-feedback`
- [ ] **Keep** · One-shot effect animations play at the object's sprite offset plus its effect offset, at the object's scale, and then delete themselves. `world-object-effect-spawn`
- [ ] **Keep** · Cells are invisible until highlighted. A highlight tints the cell outline with a colour and a strength. `world-cell-highlight`
- [ ] **Keep** · The placement ghost is drawn as the completed building in flat blueprint blue, half transparent, keeping a hint of the art's shading. It turns red whenever the current spot would be refused (blocked cells, outside a barn area, or not enough materials to start). `buildings-preview-look`
- [ ] **Keep** · While under construction, a faint blue ghost of the next stage is drawn behind the current sprite. The ghost turns red while the next stage cannot be covered by materials at the site or on the way. `buildings-next-stage-ghost`
- [ ] **Keep** · Sites and finished buildings glow with a soft white outline when hovered and the cells they stand on light up; the outline also wraps the shape of the next-stage ghost. Placement ghosts never react to the mouse, and the Barn has hovering turned off. `buildings-hover-outline`
- [ ] **Keep** · The look of the selected outline and the hover glow on objects is set by project-wide shader values: selected things get a thin solid white outline, hovered things get a soft white glow with no outline, and neither pulses. `feel-project-outline-globals`
- [ ] **Changed** · Every placed world object (trees, rocks, bushes and all buildings) shares one base set of effects: flash, reject shake, selected outline, hover glow and one-shot effect spawn. Each object gets its own outline material when it enters the game. *Now:* Decision 7 (and 5): the effects toolkit, with one value per sprite in the batch, replaces the GridObject base class and one material per object. The effects themselves stay (see the other rows). The per-object knobs effect_offset and hoverable still need a field in the data files. `effects-toolkit-base`
- [ ] **Keep** · Effects on one object run in named slots. Starting an effect in a slot cancels the one already running in that slot, while effects in different slots play at the same time. `effects-tween-slots`
- [ ] **Keep** · The sprite instantly turns one solid colour and fades back to normal. White unless a colour is given. `effects-flash`
- [ ] **Keep** · A refused click makes the object flash red and shake side to side. *But:* Decision 8: the "job queue is full" refusal is gone. The other refusals stay. `effects-reject`
- [ ] **Keep** · An object with a player-queued job gets a crisp white outline that stays until the job finishes or is cancelled. `effects-selected-outline`
- [ ] **Keep** · Moving the mouse over a world object gives it a soft white glow around its silhouette; it goes away when the mouse leaves. `effects-hover-glow`
- [ ] **Keep** · While an object is hovered, the grid cells it stands on light up grey, and go dark again when the mouse leaves. `effects-hover-cells`
- [ ] **Keep** · The outline and glow follow the sprite's silhouette, are drawn outside the sprite's own rectangle, and keep the same thickness on screen at any zoom level. `effects-outline-shader`
- [ ] **Keep** · On sprite sheets and atlases the outline only reads the current frame, so neighbouring frames never bleed into it. It updates whenever the picture or frame changes. `effects-outline-frame-clip`
- [ ] **Keep** · On a building under construction, the outline and hover glow wrap the built part and the blueprint ghost of the next stage as one shape. `effects-outline-wraps-ghost`
- [ ] **Keep** · The look of the selection outline and hover glow is set once for the whole game in project settings, not per object. `effects-outline-globals`
- [ ] **Keep** · When an object is both selected and hovered, both show at once: the hover glow is layered over the selection outline. `effects-outline-hover-plus-select`
- [ ] **Keep** · Short one-shot sprite animations play at an object's visual centre and remove themselves when they finish. `effects-one-shot-spawn`
- [ ] **Keep** · A small spark burst plays where a tree, rock or bush breaks. `effects-break-sparks`
- [ ] **Keep** · A dust cloud puffs over a building the moment it is finished. `effects-build-cloud`
- [ ] **Keep** · Each harvest hit squashes the object wider and shorter, then it springs back with a small overshoot. `effects-hit-squash`
- [ ] **Keep** · Each non-final harvest hit rocks the object right, left and back to upright once. `effects-hit-wobble`
- [ ] **Keep** · A respawned tree, rock or bush pops up from a flat sliver to full size with a springy overshoot. Objects placed when the world is first generated just appear. `effects-grow-in`
- [ ] **Keep** · A building gives a quick little bounce each time a resource is delivered to it or stored in it. `effects-build-pop`
- [ ] **Keep** · Behind a construction site a see-through blue ghost shows the next build stage. It turns red while the site cannot get the resources for that stage, and disappears when the building is done. `effects-blueprint-ghost`
- [ ] **Keep** · The ghost is a flat one-colour version of the sprite that keeps a hint of the art's light and dark areas. `effects-blueprint-shader`
- [ ] **Keep** · Grid cells are invisible outlines until something highlights them. A highlight is a colour and an opacity put on the cell's outline sprite. `effects-cell-highlight`
- [ ] **Keep** · All in-world effects (flash, shake, squash, wobble, pop, drops, sparks, cloud, topple, windmill, giant) play faster at higher game speed and freeze while paused. Message fades, the game-over fade and the game-over music do not speed up. *But:* The giant part is checked in #76. `effects-game-speed-scaling`

## #48 The main village starts on the ground

[Issue #48](https://github.com/Liam-M-Mays/game-jam-2026/issues/48)

- [ ] **Changed** · The game scene asks for a 110 by 110 block of candidate cells. Only the candidates that fit on the ground become real cells. *Now:* Decision 13: size is a dev setting, about 100,000 cells, round. The 110 block and its 2,091 cells are the giant's back (#76). `world-grid-size`
- [ ] **Changed** · Every cell knows how far it is from the edge of the ground, as a number from 0 at the rim to 1 at the deepest point. This number decides where each resource type can grow. *Now:* Decision 13: noise bands decide where resources grow, not distance from the edge. `world-edge-distance`
- [ ] **Keep** · Choosing the Town Hall spot does not use the world seed. On the same ground shape it stands in the same place every game. `world-town-hall-fixed-spot`
- [ ] **Keep** · The empty cells touching the Town Hall are kept clear for the whole game. No resource is ever spawned or respawned on them. `world-keep-clear-ring`
- [ ] **Keep** · Each new game uses a new random world seed unless a fixed seed is set on the grid. The seed is printed to the console. `world-seed-random`
- [ ] **Keep** · The same world seed drives both the ground pattern and the resource layout. `world-seed-shared`
- [ ] **Changed** · The ground is painted in three flat greens (dark, base, light) with hard borders between them and no gradients. *Now:* Decision 13: the ground can be a flat colour. Band colours are for placing resources. `world-ground-three-greens`
- [ ] **Changed** · Each ground pixel gets one value. Low values are painted dark, high values light, and everything between is the base green. *Now:* Decision 13: new noise bands. The old thresholds only painted the ground. `world-ground-band-thresholds`
- [ ] **Changed** · The value starts from how deep the pixel is inside the yard, so the rim of the ground is dark and the middle is light. The same ground test the grid uses defines the rim. *Now:* Decision 13: flat ground is allowed. The depth field is built from the yard and torso shape, so it only fits the giant (#76). `world-ground-depth`
- [ ] **Changed** · Seeded noise is added to the depth value so the borders between the greens wobble instead of following the rim exactly. The noise fades out toward the deep middle. *Now:* Decision 13: noise now makes the bands that place resources. The old ground-pattern settings do not carry over. `world-ground-noise`
- [ ] **Changed** · A second, warped noise adds streaks to the ground, but only in patches where the main noise read at an offset is high. *Now:* Decision 13: a ground pattern is optional. `world-ground-streaks`
- [ ] **Changed** · The ground pattern is snapped to whole art pixels and the main noise is slanted one pixel per row, so it lines up with the slanted grid. *Now:* Decision 13: a ground pattern is optional. If bands are ever drawn on the ground, snapping them to art pixels is not in the plan. `world-ground-pixel-snap-shear`
- [ ] **Changed** · The ground script offers nine noise looks to choose in the editor: Soft, Perlin, Blocky, Cells, Cracks, Ridges, Rings, Swirls and Spots. The game scene uses Soft. *Now:* Decision 13: new generator. The game only uses Soft; the other eight looks are editor options. `world-ground-presets`
- [ ] **Changed** · In the editor the yard shows a live preview of the chosen preset from a preview seed. In the running game the pattern is rebuilt from the world seed. *Now:* Decision 13: new generator. The debug overlay (#31) shows the bands as colours. That replaces the yard's editor preview. `world-ground-editor-preview`
- [ ] **Keep** · Five kinds of resource are spawned on the map: tree, rock, big tree, bush and big rock. Each has a target count the map tries to hold. *But:* The five kinds stay. On the big world each kind keeps its share of the jam map, scaled up (Decision 30). `world-spawn-list`
- [ ] **Changed** · At the start the game queues one spawn for every resource up to each type's target, shuffles the queue with the world seed, and places them one by one. *Now:* Decision 13: placed by noise band, from the seed. `world-spawn-initial`
- [ ] **Changed** · To place one resource the game picks random cells until one is accepted. The footprint must fit on empty cells in one row and off the keep-clear ring, and then a dice roll weighted by the cell's edge distance and its nearness to buildings must pass. *Now:* Decision 13: the band replaces the edge-distance roll. Still needed: the footprint fits on empty cells in one row, off the keep-clear ring. `world-spawn-pick`
- [ ] **Changed** · If no cell is accepted after all tries, that one resource is skipped with no message. A type that starts below its target is topped up later by the respawn timer. *Now:* Decision 13: band placement replaces the 100-try pick at the start. `world-spawn-give-up`
- [ ] **Changed** · Small trees and small rocks grow inland. None appear in the outer rim, and the chance rises toward the middle. *Now:* Decisions 13 and 30: placed by noise band. Small trees and rocks stand in the light areas, big ones together in the dark areas. `world-spawn-zone-small`
- [ ] **Changed** · Big trees and big rocks grow around the rim. They have full chance near the edge and none in the middle. *Now:* Decision 13: placed by noise band, not by distance from the edge. `world-spawn-zone-big`
- [ ] **Changed** · Bushes grow in a ring halfway between the rim and the middle, with no chance at the very edge or the very centre. *Now:* Decision 13: placed by noise band, not by distance from the edge. `world-spawn-zone-bush`
- [ ] **Keep** · Anywhere nothing is drawn shows a muted teal background colour. `feel-project-clear-colour`
- [ ] **Changed** · The ground is drawn in three flat greens (dark, base, light) in blotchy patches, one colour per art pixel, slanted to follow the skewed grid rows. *Now:* Decision 13: the ground may be one flat colour. The bands only have to place resources. The debug overlay (#31) shows the bands. `effects-ground-bands`
- [ ] **Changed** · The ground pattern is built from the world seed: a soft noise map, a distance-from-the-edge map that makes the middle calmer and lighter, and a streak map that adds streaks only in some regions. *Now:* Decision 13: the world generator's own noise maps replace this. The edge map is baked from the shape of the giant's back, so that part only returns with #76. `effects-ground-noise-maps`
- [ ] **Changed** · The three ground greens are only a picture. Where resources spawn is decided by the grid's own cell edge distance and building clearance; nothing in the game reads the ground colour. Both follow rim-to-middle depth, which is the only reason they roughly line up. *Now:* Decision 13: resources are placed by the colour bands of the noise, and the ground can be a flat colour. The old rim-to-middle depth came from the shape of the giant's back. `gap-ground-colour-cosmetic`

## #63 Core: stock and drops as counts

[Issue #63](https://github.com/Liam-M-Mays/game-jam-2026/issues/63)

- [ ] **Keep** · Two kinds of drop item exist, wood and stone. Each is a tiny sprite lying on the ground. `world-drop-kinds`
- [x] **Keep** · A drop counts toward the stock the moment it appears, before any meeple picks it up, and stops counting when it is removed from the world. `world-drop-counts-at-once`
- [x] **Changed** · A drop that expires fades out and disappears. It cannot be picked up once the fade starts. *Now:* Decision 10: drops no longer expire, so nothing triggers this fade. `world-drop-expire-fade`
- [x] **Keep** · A new game starts with 10 food and no wood or stone. `world-stock-start`
- [ ] **Keep** · Food has a cap: a base amount plus the capacity of every finished silo. `world-stock-food-cap`
- [x] **Keep** · Food added above the cap is lost. `world-stock-food-overflow`
- [ ] **Keep** · Food counts as full when it is at or above the cap. Being full blocks bush picking and farm collecting. `world-stock-food-full`
- [x] **Keep** · Spending more than is in stock just empties it to zero. Stock never goes negative. `world-stock-spend-floor`
- [x] **Keep** · The number shown for a resource is the banked amount plus every drop item of that kind that exists: on the ground, being carried, or in a storage pile. `world-stock-count`
- [x] **Keep** · Wood and stone are never banked as a number. Each unit is a physical drop item until it is delivered to a building site, and only food is a banked number. `world-stock-wood-stone-are-items`
- [x] **Keep** · What can be promised to a building is the number of drops of that kind not yet claimed, minus those already reserved. `world-stock-available`
- [ ] **Keep** · A building site reserves one unit for every haul it asks for. Dropping the haul gives the reservation back. `world-stock-reserve`
- [x] **Keep** · When a hauler starts, it claims the nearest unclaimed drop of the needed kind, whether on the ground or in a pile. That turns one reservation into a claim. `world-stock-claim-closest`
- [x] **Keep** · If a haul is aborted, its drop is unclaimed again and the reservation is restored. `world-stock-release`
- [ ] **Keep** · A loose drop is one lying on the ground: not claimed and not in a pile. Idle meeples storing things take the nearest loose drop of the pile's kind. *But:* Decision 9: storage workers store drops, not idle meeples. `world-stock-loose`
- [x] **Changed** · Only 30 loose drops may lie around for long. When there are more, the oldest extra drops that no building has reserved start a 20 second timer and then expire, which lowers the stock. If the number falls back to 30 or less, the timers reset. *Now:* Decision 10: no 30-drop limit, drops stay where they fall. `world-stock-ground-limit`
- [ ] **Keep** · The stock announces every change, so the HUD counters, build menu, hunger, building sites and bushes update at once. `world-stock-changed-signal`
- [x] **Keep** · Starting a new game resets the banked stock to the starting values and clears all reservations. `world-stock-reset`
- [ ] **Keep** · Only wood and stone are ever physically carried. Food is never an item: when berries or crops are gathered the food count goes up instantly at the spot. `meeples-carry-only-wood-stone`
- [ ] **Keep** · When a meeple starts a delivery it claims the unclaimed unit of that resource closest to itself, whether it lies on the ground or sits in a storage pile. `meeples-haul-pick-closest`
- [x] **Changed** · Surplus drops left lying on the ground fade out and vanish. *Now:* Decision 10: no 30-drop limit, drops stay where they fall, so nothing fades out. `effects-drop-expire`
- [ ] **Keep** · A loose item that a meeple has chosen to carry to a pile is locked from the moment the trip is chosen until it lands in the pile. During the walk it still counts in the stock number but cannot be promised to a building site. Landing in the pile makes sites ask for materials again. `gap-stock-store-trip-locks-unit`

## #64 Core: meeples as data

[Issue #64](https://github.com/Liam-M-Mays/game-jam-2026/issues/64)

- [ ] **Keep** · When heading for a building, resource or storage pile, the meeple stops as soon as it steps onto any grid cell belonging to that object instead of walking to its exact centre. Loose items on the ground have no footprint, so the meeple walks right up to them. `meeples-stop-at-footprint`
- [ ] **Keep** · A meeple aims slightly below the thing it is walking to, so it is drawn in front of it rather than hidden behind it. `meeples-stand-in-front`
- [ ] **Keep** · A dying meeple freezes, tips over sideways around its feet (left or right at random), bounces once slightly, lies on the ground, fades out and is removed. `meeples-death-topple`
- [ ] **Keep** · With nothing to do, a meeple finishes its current walk, then switches to wandering: it remembers where it stopped as home and picks the nearest finished building as its hangout. `meeples-wander-start`
- [ ] **Keep** · A wandering meeple stands still for a random pause, strolls slowly to a new spot, then pauses again. *But:* #46: 30 is the middle value. Each meeple's own speed differs a little. `meeples-wander-pause-and-speed`
- [ ] **Keep** · Each stroll goes to a random free cell close to the hangout building, nudged by a small random offset so meeples do not line up. It prefers a spot it can reach without crossing a building; if none of the tried spots is clear it goes to the closest tried spot anyway. *But:* Decision 11: the walking issue decides how a base is avoided. Wandering near a building stays. `meeples-wander-near-building`
- [ ] **Keep** · On each stroll there is a small chance the meeple changes its hangout to another finished building, with nearby buildings much more likely than far ones. It also re-picks if its hangout no longer exists. `meeples-wander-building-hop`
- [ ] **Keep** · If there is no building to hang around, or no free cell next to it, the meeple instead strolls to a random point around the spot where it went idle, as long as that point is on the grid. `meeples-wander-fallback-home`
- [ ] **Keep** · A starving meeple cries out, tips over sideways around its feet, bounces once on landing, lies still for a moment, then fades away. *But:* The sound is ticked in #73. This issue sends the event. `effects-meeple-death`

## #65 Core: job board where jobs find meeples

[Issue #65](https://github.com/Liam-M-Mays/game-jam-2026/issues/65)

- [ ] **Changed** · If the job queue is full, the click is refused. The resource flashes red and shakes and no job is made. *Now:* Decision 8: no job limit, so this refusal is gone. `world-harvest-click-queue-full`
- [ ] **Changed** · A building counts as startable only if you can afford its minimum and the job queue has room for that many haul jobs; the build menu dims the button otherwise and refuses the pick with "Job queue is full". *Now:* Decision 8: no job limit, so no job-room check and no 'Job queue is full' refusal. The afford half stays in #67. `buildings-start-needs-job-room`
- [ ] **Changed** · A site only puts haul jobs into the shared job queue while the queue has room; the rest wait at the site and are posted as other jobs finish. *Now:* Decision 8: no job limit. A site posts all its haul jobs; the extra ones wait in the job board's backlog. `buildings-haul-queue-throttle`
- [ ] **Keep** · When a meeple dies its job goes back to the front of the queue for someone else, anything it was carrying is dropped on the ground where it died, and it stops counting as a worker straight away (before the death animation ends). *But:* Decision 8: the job looks for the closest free builder again, or waits in the backlog. It does not go to the front of a queue. `meeples-death-hands-back-work`
- [ ] **Changed** · A free meeple decides what to do every frame in this order: take the oldest waiting job; if there is none, look for idle work; if there is none, wander. A job it takes is started in the same frame. *Now:* Decisions 5, 8 and 9: jobs find the closest free builder, nothing polls, idle work is replaced by roles. Wandering when free stays. `meeples-job-loop`
- [ ] **Changed** · The number of player and construction jobs that can exist at once (waiting plus in progress) is limited to the number of meeples plus three. Idle work does not count toward this limit. If meeples die the limit shrinks but jobs already queued stay. *Now:* Decision 8: no job limit. `meeples-job-queue-cap`
- [ ] **Changed** · If the player clicks something to queue a job while the queue is full, no job is added, the clicked object flashes red and shakes, and a warning message appears. *Now:* Decision 8: no job limit, so there is no 'Job queue is full' refusal. The red flash and shake stay in #62 for the other refusals. `meeples-job-rejected-feedback`
- [ ] **Changed** · Jobs are handed out oldest first. The job goes to whichever free meeple gets its turn first (earlier-spawned meeples go first), not to the meeple nearest to the work. *Now:* Decision 8: a job takes the closest free builder; a freed builder takes the closest waiting job, not the oldest. `meeples-job-fifo-first-free`
- [ ] **Changed** · A job given up by its worker (the worker died or its building site was paused) jumps to the front of the queue, so it is the next one taken. Its work timer starts over. *Now:* Decision 8: an interrupted job looks for the closest free builder again. It waits in the backlog only if none is free. The work timer starting over stays. `meeples-job-requeue-front`
- [ ] **Keep** · Cancelling a job removes it from the queue. If a meeple is already walking to it or working on it, the meeple stops where it stands and becomes free. `meeples-job-cancel`
- [ ] **Changed** · A warning "Job queue is full" appears when a job you asked for is refused because the queue is full, and when you pick a building whose first deliveries will not fit in the queue. *Now:* Decision 8: no job limit, so this toast is gone. `ui-toast-job-queue-full`
- [ ] **Keep** · A drop disappears from the ground when a meeple picks it up or stores it, and reappears at the meeple's position if the job is abandoned mid-carry. `effects-drop-carry-hide`
- [ ] **Changed** · The job-queue room a building needs before it can be picked is its 'minimum to start' unit count, but never more than the whole queue limit. So a building whose minimum is bigger than the limit can still be picked when the queue is completely empty. *Now:* Decision 8: there is no job limit, so a building no longer needs free queue room to be picked. Only the 'minimum to start' materials check stays (#67). `gap-build-jobs-needed-capped`
- [ ] **Changed** · Job-queue room is checked only when a building is picked (menu button or hotkey). The placing click checks only free cells, barn area and materials, so a site can still be placed if the queue has filled up since; its deliveries then wait at the site. *Now:* Decision 8: no job limit, so there is no queue-room check at pick or at place. Deliveries that find no free builder wait in the backlog. The other placing checks (free cells, barn area, materials) stay in #67. `gap-build-place-no-queue-recheck`

## #66 Core: trees, rocks, bushes and harvesting

[Issue #66](https://github.com/Liam-M-Mays/game-jam-2026/issues/66)

- [ ] **Keep** · Resources avoid buildings. The closer a spot is to any building on the grid, building sites included, the less likely a resource appears there. `world-spawn-building-clearance`
- [ ] **Keep** · Resources grow back over time. Every tick, each resource type that is below its target rolls a chance to grow one new one, and the chance is higher the more are missing. `world-respawn-tick`
- [ ] **Keep** · Each resource type has its own respawn chance. Bushes come back half as readily as trees and rocks. `world-respawn-chance-values`
- [ ] **Keep** · The count toward a type's target is every living resource of that type on the map. One that is already being deleted is not counted. `world-respawn-count`
- [ ] **Keep** · A respawned resource follows the same placement rules as at the start: zone curve, building avoidance, keep-clear ring and the try limit. *But:* Decision 13: the cell's noise band replaces the zone curve. Building avoidance, the keep-clear ring and the try limit stay. `world-respawn-same-rules`
- [ ] **Keep** · A resource never grows back on a cell where a meeple is standing or a drop item is lying. `world-respawn-not-on-movers`
- [ ] **Keep** · Left-clicking a tree, rock or bush orders it to be harvested. It gets a white outline and a harvest job is queued for a meeple. `world-harvest-click-order`
- [ ] **Keep** · Left-clicking a resource that is already marked for harvest cancels the order and removes the outline. `world-harvest-click-cancel`
- [ ] **Keep** · Once the meeple has arrived, it hits the resource once per hit interval until the resource breaks. `world-harvest-hit-rhythm`
- [ ] **Keep** · Hits already landed stay on the resource if the order is cancelled or the worker leaves. The next worker needs only the remaining hits. `world-harvest-progress-kept`
- [ ] **Keep** · Breaking a tree or rock costs food. The food is taken once, at the moment it breaks, not per hit. `world-harvest-food-cost`
- [ ] **Keep** · On the last hit the resource squashes and turns solid white for a moment, then vanishes with a small spark burst and its cells become free. `world-harvest-break`
- [ ] **Keep** · A resource that has taken its last hit cannot be ordered again during the short break pause. `world-harvest-no-reorder-while-breaking`
- [ ] **Keep** · When a resource breaks, each of its drops appears at its base, centred under the sprite, and flies out. `world-harvest-drops-spawn`
- [ ] **Keep** · Tree: breaks after 2 hits and drops 1 wood. *But:* The target count is for the jam map. On the big world each kind keeps its share, scaled up (Decision 30). `world-type-tree`
- [ ] **Keep** · Rock: breaks after 3 hits and drops 1 stone. *But:* The target count is for the jam map. On the big world each kind keeps its share, scaled up (Decision 30). `world-type-rock`
- [ ] **Keep** · Big tree: breaks after 4 hits and drops 2 wood. *But:* The target count is for the jam map. On the big world each kind keeps its share, scaled up (Decision 30). `world-type-big-tree`
- [ ] **Keep** · Big rock: breaks after 6 hits and drops 2 stone. *But:* The target count is for the jam map. On the big world each kind keeps its share, scaled up (Decision 30). `world-type-big-rock`
- [ ] **Keep** · Bush: gives food straight into the stock when picked. It has no drops and no food cost. *But:* The target count is for the jam map. On the big world each kind keeps its share, scaled up (Decision 30). `world-type-bush`
- [ ] **Keep** · A bush has five looks. It spawns on the first one, and each pick moves it one step toward the last one, where nothing is left to pick. `world-bush-stages`
- [ ] **Keep** · One harvest order keeps the same meeple picking, one pick per interval, until the bush is bare or the food store is full. Each pick shows the normal hit feedback. `world-bush-pick-loop`
- [ ] **Keep** · A bush that is not on its first stage grows back one step every 15 seconds. Every pick restarts that timer, and a bare bush needs 60 seconds to be full again. `world-bush-regrow`
- [ ] **Keep** · Each time a bush is picked bare counts once. The third time it is destroyed with the normal break effect and gives no drops, and a new bush can then respawn somewhere else. `world-bush-dies`
- [ ] **Keep** · Clicking a bush that still has food while the food store is full is refused with the red flash and shake. *But:* Decision 27: the reason is also shown to the player on screen. `world-bush-food-full-click`
- [ ] **Keep** · If the food store becomes full while a bush is marked for picking, the order is cancelled and the outline removed automatically. `world-bush-food-full-cancel`
- [ ] **Keep** · If a pick lands while food is full, nothing is picked and the job ends. `world-bush-food-full-hit`
- [ ] **Keep** · Clicking a bare bush orders it to be cleared instead. A meeple hits it like a tree until it breaks, it gives nothing, and this works even when food is full. `world-bush-clear-bare`
- [ ] **Keep** · A new drop slides quickly from where the resource stood to a random spot close by, slowing down as it lands. `world-drop-fly`
- [ ] **Keep** · A drop only lands on an existing, empty cell. If it cannot find one, it stays where the resource stood. `world-drop-landing-rule`
- [ ] **Keep** · Trees, rocks and bushes are less likely to spawn or respawn close to any building or construction site, and never on its cells. `buildings-resource-spawn-clearance`
- [ ] **Keep** · Left-clicking a tree, rock or berry bush queues a harvest job and outlines the object. Left-clicking it again cancels the job and removes the outline. `meeples-harvest-queue-input`
- [ ] **Keep** · On a harvest job the meeple walks to the object, then hits it at a steady rhythm until it breaks; the job is then done. The first hit lands one full interval after arriving. `meeples-harvest-steps`
- [ ] **Keep** · Breaking a tree or rock costs food, taken at the moment it breaks. Food cannot go below zero, and a harvest the player ordered is never refused for lack of food. *But:* Decision 27: a role worker is not refused for lack of food either. `meeples-harvest-food-cost`
- [ ] **Keep** · If the worker is pulled off a harvest, the hits already landed on the tree or rock stay; only the swing rhythm starts over for the next worker. `meeples-harvest-interrupt-keeps-damage`
- [ ] **Keep** · A harvest job on a berry bush picks berries once per hit and adds food each time. The job ends when the bush is picked clean or food storage is full, and costs no food. `meeples-harvest-bush`
- [ ] **Keep** · Food-gathering jobs the player queued (berry picking and crop collecting) are cancelled automatically as soon as food storage becomes full. `meeples-food-jobs-autocancel-when-full`
- [ ] **Keep** · Trees, rocks and bushes do not regrow on a cell a living meeple is standing on. `meeples-block-resource-respawn`
- [ ] **Keep** · A non-final hit plays the hit sound, squash, white flash and wobble together, and hits repeat at a steady rhythm while a meeple works. *But:* The sound is ticked in #73. This issue sends the event. `effects-hit-reaction`
- [ ] **Keep** · The final hit plays the hit sound and squash, turns the object solid white for a split second, then it bursts into sparks, disappears, and its drops fly out. *But:* The sound is ticked in #73. This issue sends the event. `effects-shatter`
- [ ] **Keep** · Picking a bush swaps it to the next, emptier berry picture with the normal hit reaction. Berries growing back swap the picture silently with no effect, and a bush emptied for the last time shatters like a tree. `effects-bush-stages`
- [ ] **Keep** · Drops from a broken object fly out to a random nearby free spot, slowing down as they land. `effects-drop-launch`
- [ ] **Keep** · A bare bush that has been ordered to be cleared does not grow berries back while the order stands. If the order is cancelled, regrowing carries on and the hits already landed on it stay. `gap-bush-regrow-paused-while-clearing`
- [ ] **Keep** · Every tree, rock and bush is hit once every 0.6 seconds, except the big rock, which is hit once every 0.7 seconds. Idle choppers and miners use the same rhythm. `gap-world-hit-interval-per-type`

## #67 Buildings: data files, placing and construction

[Issue #67](https://github.com/Liam-M-Mays/game-jam-2026/issues/67)

- [ ] **Keep** · Picking a building (build menu button or number hotkey) enters placement mode: a ghost of the finished building follows the mouse and the build menu closes. Picking another building while already placing swaps the ghost. `buildings-build-mode-start`
- [ ] **Keep** · The ghost snaps to the grid cell under the mouse, which becomes the building's anchor cell; it is hidden when the mouse is not over any grid cell. The footprint grows from the anchor: width cells along +x, depth rows along +y. `buildings-preview-snap`
- [ ] **Keep** · While placing a normal building the cell-highlight cursor around the mouse is switched on. It is off for farms and silos (they use the barn area highlight instead) and is switched off again when placement ends. `buildings-cell-cursor-toggle`
- [ ] **Keep** · A building can only go where every footprint cell exists on the ground grid and has no occupant (tree, rock, bush, building or construction site). Meeples and loose resource drops standing on a cell do not block placement. *But:* #9, decision 12: a barn's plot cells take farms and silos only. `buildings-placement-rule-free-cells`
- [ ] **Keep** · To place a building you must have at least its 'minimum to start' amount of each listed resource available, counting only resource drops that are not claimed by a job and not reserved by another site. Nothing is deducted at placement; the building is paid for one hauled unit at a time. `buildings-placement-rule-afford`
- [ ] **Keep** · Left-clicking a valid spot places a construction site there, starts construction at once and ends placement mode, so each selection places exactly one building. The click is marked as handled while in placement mode. `buildings-place-click`
- [ ] **Keep** · Clicking an invalid spot makes the ghost flash red and shake sideways, shows a warning toast, and leaves you in placement mode. The toast is "Can't build there" for blocked cells and "You need more materials to build <Name>" when you cannot afford to start. *But:* The message is ticked in #70. This issue sends the event. `buildings-place-fail-feedback`
- [ ] **Keep** · Pressing Escape (ui_cancel) while placing cancels placement and the key press is consumed, so the pause menu does not open. Pressing the HUD build button while placing also cancels placement and opens the build menu. `buildings-cancel-placement`
- [ ] **Keep** · A freshly placed site has nothing built yet: its own sprite is invisible and only a blue ghost of the first stage is shown. From this moment it can be hovered and clicked, and it is listed as a construction site. `buildings-site-start-state`
- [ ] **Keep** · A building is built in ordered stages, one per build frame of its sprite sheet, and each stage has its own resource cost. A stage completes as soon as the site holds everything that stage needs, and the sprite moves to that stage's frame. *But:* Decision 5: the stage count and the frame order are written in the data file, not read from the sheet. `buildings-stage-cost-model`
- [ ] **Changed** · A site reserves every available unit it still needs for all of its remaining stages and creates one haul job per unit; it tries again every time the inventory changes. Reserved units cannot be used by other sites and do not count toward affording new buildings. *Now:* Decision 25: a site asks only for what its next step needs. One haul job per unit stays. Nothing is held for later stages. `buildings-haul-requests`
- [ ] **Keep** · Each unit a meeple delivers makes the site do a small scale pop; when a delivery completes a stage the sprite advances to the next frame with a white flash. `buildings-deliver-feedback`
- [ ] **Keep** · Materials that arrive before their stage is due are kept at the site and used when that stage comes up, so several stages can complete in a row from one delivery. `buildings-banked-materials`
- [ ] **Keep** · Right-clicking a construction site pauses it, and right-clicking it again resumes it; a right-button drag (used to pan the camera) does not count as a click. If several sites are under the mouse the front-most one is chosen. This works whether or not you are in placement mode. `buildings-pause-toggle`
- [ ] **Keep** · Pausing a site gives it a yellow outline, makes meeples hauling to it abandon the trip and drop what they carry where they stand, cancels its queued hauls and frees its reserved materials for other sites. Materials already delivered stay in the site, no shortage warning is given while paused, and resuming requests hauls again. `buildings-pause-effect`
- [ ] **Keep** · When the last stage is paid for, the building shows its finished frame, a small cloud puff plays over it, and it becomes a completed building that can offer work and count toward totals. *But:* Decision 9: a finished building has worker slots. It does not offer idle work. `buildings-completion`
- [ ] **Keep** · A meeple fetching building material from a pile can carry two units in one trip when the pile has a second free item and the same site has another queued haul for the same resource. `buildings-storage-double-carry`
- [ ] **Changed** · All buildings share one base that handles the ghost, stages, hauling, pausing and completion, and kinds add behaviour on top: huts (small, stone, town hall), barn, barn plots (farm, silo), storage piles, the lumberjack and miner (one shared script with a different target drop), and the windmill. The statue uses the base as is. *Now:* Decision 5: one object per building, not a node. A kind is a data file plus its own behaviour (#68). `buildings-structure-class-tree`
- [ ] **Changed** · Other systems find buildings through named sets: sites under construction, completed buildings, barns, silos, windmills and storages. A building joins its sets only when the matching state is reached. *Now:* Decision 3: the village owns its buildings by state and kind. Scene-tree groups are global, so they go. `buildings-structure-groups`
- [ ] **Changed** · One build system node per level owns placement mode, the ghost, the barn area highlight, right-click pausing and the site tooltip, and tells the HUD when a build starts, fails or completes. It needs the grid and the cell cursor wired in. *Now:* Decision 4: placing is a command to the village that answers with a reason; ghost, highlight and tooltip are on the picture side (#70). The QUEUE_FULL reason goes (decision 8). `buildings-structure-build-system`
- [ ] **Changed** · Every building scene is a single sprite sheet drawn at ten times pixel size one layer above the ground, with a rectangular click area and its stage costs stored in the scene. *Now:* Decisions 5 and 7: costs move to data files, sprites go into one atlas and batch, clicks use maths instead of click boxes (#61). The art is still drawn at 10x. `buildings-structure-scene-shape`
- [ ] **Keep** · A construction site creates one delivery job per unit of wood or stone it still needs, but only for units that actually exist and are not already promised elsewhere. If the job queue is full, the extra deliveries wait at the site and are added as room frees up. *But:* Decision 8: there is no job limit, so nothing waits for room in a queue. `meeples-haul-created-by-sites`
- [ ] **Keep** · The hauler walks to the item (following it if it is still moving), picks it up instantly so it disappears from the ground or pile and shows above its head, walks to the building site, and hands it over instantly on arrival. The item is used up and the site may advance a build stage. `meeples-haul-steps`
- [ ] **Keep** · If the item a hauler claims is in a storage pile, the pile holds another unclaimed item, and another delivery for the same site and same resource is waiting in the queue, the hauler takes that second delivery too and carries both in one trip. Both are delivered together on arrival. `meeples-haul-two-at-a-time`
- [ ] **Keep** · If a hauler is interrupted, whatever it carries (one or two items) is put on the ground where it stands and becomes available again, even if it came from a pile. The delivery job or jobs go back to the front of the queue. *But:* Decision 8: the job looks for the closest free builder again, or waits in the backlog. It does not go to the front of a queue. `meeples-haul-abort-drops-item`
- [ ] **Keep** · Right-clicking a construction site pauses it: every meeple delivering to it stops and drops its load, and all its waiting deliveries are removed and their materials released. Right-clicking again resumes and deliveries are requested again. `meeples-haul-pause-recall`
- [ ] **Keep** · While placing a building that can go anywhere, the ground cells in a circle around the mouse light up and follow the mouse. Outside that mode nothing lights up. `feel-cursor-cell-highlight`
- [ ] **Keep** · A construction site paused with right-click gets a yellow outline until it is resumed or finished. `effects-paused-outline`
- [ ] **Keep** · A construction site flashes white each time it gains a build stage, including the final one. `effects-build-stage-flash`
- [ ] **Keep** · Finishing a building shows its final picture with a dust cloud, on top of the delivery bounce, hammer sound and stage flash. A building with no cost (farm) finishes the instant it is placed, with only the cloud and flash. *But:* The sound is ticked in #73. This issue sends the event. `effects-build-complete`
- [ ] **Keep** · A newly placed site with nothing built yet shows no building picture at all, only the blueprint ghost of its first stage. `effects-site-hidden-until-first-stage`
- [ ] **Keep** · While placing a building, a ghost of the finished building snaps to the grid cell under the mouse: blue when it can go there, red when it cannot. `effects-placement-preview`
- [ ] **Keep** · While placing any other building, the grid cells near the mouse light up grey so the grid shows around the cursor. `effects-build-cursor-cells`
- [ ] **Changed** · When materials become available, building sites are offered them in the order the sites were placed. Each site reserves everything it still needs for all of its remaining stages before the next site gets anything, so one big early site can starve later ones until it is paused. *Now:* Decision 25: a site holds nothing for later stages, and a free meeple takes the nearest delivery job. One big early site no longer starves the others. `gap-build-older-site-first`
- [ ] **Keep** · Pausing a site clears its 'short of materials' state, so its next-stage ghost goes back to blue while paused. Resuming checks again, and a site that is still short shows the 'needs N more' warning a second time. `gap-build-resume-rewarns`

## #68 Buildings: bring over the eleven buildings

[Issue #68](https://github.com/Liam-M-Mays/game-jam-2026/issues/68)

- [ ] **Keep** · Farms and silos can only be placed on a free cell inside the plot ring of a finished barn that still has a free slot for that kind of plot. `buildings-placement-rule-barn-area`
- [ ] **Keep** · While placing a farm or silo, every free plot cell around every eligible barn glows pale yellow and the cell under the ghost turns solid white. The ghost itself only appears while the mouse is over a valid highlighted cell. `buildings-barn-area-highlight`
- [ ] **Keep** · A building's shown name comes from its scene file name: underscores become spaces, words are capitalised and a trailing "_build" is dropped. *But:* The name is a field in the data file. The shown names stay. `buildings-display-name`
- [ ] **Keep** · Each finished barn supports up to 3 farms and, counted separately, up to 3 silos, placed on the ring of cells around it. A barn still under construction supports nothing. `buildings-barn-slots`
- [ ] **Keep** · A farm or silo is tied to the first barn that has a free slot of its type and whose ring contains its cell, and it uses up that slot from the moment it is placed. *But:* #9: two barns' areas cannot share a cell. `buildings-barn-plot-assignment`
- [ ] **Keep** · A farm costs nothing and is finished the instant it is placed, with the usual cloud puff, white flash and "Farm finished!" toast. *But:* The message is ticked in #70. This issue sends the event. `buildings-farm-instant-free`
- [ ] **Keep** · A finished farm grows its crop through visible stages on a timer and stops when ripe; harvesting resets it to the first stage. The sprite flashes white each time the stage changes. `buildings-farm-growth`
- [ ] **Keep** · Each finished silo raises the food limit, and the food counter updates as soon as it is finished. `buildings-silo-food-cap`
- [ ] **Keep** · Each finished windmill gives every barn on the map one extra farm slot and one extra silo slot, wherever the windmill stands. `buildings-windmill-bonus`
- [ ] **Keep** · When a windmill is finished its body switches to the bare tower frame and a separate wheel sprite appears and spins continuously. `buildings-windmill-wheel`
- [ ] **Keep** · Stored items disappear into the pile, whose sprite fills up to show how full it is, popping and flashing as it changes. They still count in the resource totals and can still be hauled to building sites, but they no longer count as loose ground drops, so they do not expire. *But:* Decision 10: drops no longer expire. `buildings-storage-effect`
- [ ] **Keep** · A Wood Pile holds wood only and a Stone Pile holds stone only, each up to a fixed number of items. `buildings-storage-capacity`
- [ ] **Keep** · Small Hut: a one-cell home for one meeple, who moves in as soon as it is finished. Menu description: "A home for one meeple, who moves in as soon as it's finished." *But:* Who moves in, and the Town Hall levels, are ticked in #69. This issue ticks the numbers. `buildings-scene-small-hut`
- [ ] **Keep** · Stone Hut: a two-cell home with room for three meeples; one moves in on completion and the others join over time while fed. Menu description: "A bigger home. One meeple moves in when it's finished, and more join while they're well fed." *But:* #40: the art offset is fixed so the art sits on its cells. Who moves in, and the Town Hall levels, are ticked in #69. This issue ticks the numbers. `buildings-scene-stone-hut`
- [ ] **Keep** · Town Hall: the pre-built starting building, a two-cell hut with room for one meeple and five upgrade levels that unlock the other buildings. It is not in the build menu. *But:* Who moves in, and the Town Hall levels, are ticked in #69. This issue ticks the numbers. `buildings-scene-town-hall`
- [ ] **Keep** · Barn: a two-cell building that lets you place farms and silos on the ring of cells around it. Menu description: "Lets you build farms and silos in the area around it." `buildings-scene-barn`
- [ ] **Keep** · Farm: a free one-cell plot next to a barn that grows a crop meeples harvest for food. Menu description: "Grows crops that feed meeples when collected. Must be placed near a barn." `buildings-scene-farm`
- [ ] **Keep** · Silo: a one-cell plot next to a barn that raises the food limit. Menu description: "Raises your food limit. Has to go next to a barn." `buildings-scene-silo`
- [ ] **Keep** · Windmill: a two-cell building with a spinning wheel that adds one farm slot and one silo slot to every barn. Menu description: "+1 farm plot and silo per farm". *But:* The rule and the numbers stay. The menu text is rewritten so that it says the bonus is per barn (Decision 32). `buildings-scene-windmill`
- [ ] **Keep** · Lumberjack: a two-cell hut where one idle meeple at a time chops the nearest tree, paying food per tree. Menu description: "An idle meeple works here, chopping the nearest tree. Chopping uses food." *But:* Decision 9: worker slots replace one idle meeple at a time, 1 slot for now. The menu text is rewritten (Decision 32). Cost, footprint and unlock level stay. `buildings-scene-lumberjack`
- [ ] **Keep** · Miner: a two-cell hut where one idle meeple at a time mines the nearest rock, paying food per rock. Menu description: "An idle meeple works here, mining the nearest rock. Mining uses food." *But:* Decision 9: worker slots replace one idle meeple at a time, 1 slot for now. The menu text is rewritten (Decision 32). Cost, footprint and unlock level stay. `buildings-scene-miner`
- [ ] **Keep** · Wood Pile: a one-cell stockpile where idle meeples stack loose wood. Menu description: "Meeples stack loose wood here so it doesn't go to waste." *But:* Decision 9: worker slots replace one idle meeple at a time. Cost, footprint and unlock level stay. The menu text is rewritten (Decision 32). `buildings-scene-wood-pile`
- [ ] **Keep** · Stone Pile: a one-cell stockpile where idle meeples stack loose stone. Menu description: "Meeples stack loose stone here so it doesn't go to waste." *But:* Decision 9: worker slots replace one idle meeple at a time. Cost, footprint and unlock level stay. The menu text is rewritten (Decision 32). `buildings-scene-stone-pile`
- [ ] **Keep** · Statue: a huge, very expensive monument that does nothing once built. It is kept a mystery: its menu icon is a question mark and it shows no next-stage ghost while being built. Menu description: "A towering monument to your village." *But:* #40: the art offset is fixed so the art sits on its cells. `buildings-scene-statue`
- [ ] **Changed** · Each building has one description line shown in its tooltip. *Now:* Decisions 9, 10 and 32: the Lumberjack, Miner, Wood Pile, Stone Pile and Windmill lines are rewritten. An agent drafts them and Liam reviews them. The other six lines stay. `ui-build-tooltip-descriptions`
- [ ] **Keep** · While placing a farm or silo, every allowed cell around barns glows pale yellow, and the cells under the ghost glow bright white. `effects-placement-area-cells`
- [ ] **Keep** · Buildings that change picture after they are built flash white on each change. `effects-frame-swap-flash`
- [ ] **Keep** · A finished windmill shows its bare tower with a separate wheel that spins forever. `effects-windmill-wheel`
- [ ] **Changed** · A pile's capacity is its 'max items' setting, or, when that is not set, the number of fill pictures on its sprite sheet. The picture shown is the fill fraction rounded up, so the first stored item already shows the first fill step. *Now:* Decision 5: rules never come from sprite frame counts. Capacity is written in the data file. The numbers stay: stone pile 11, wood pile 20, fill picture rounded up. `gap-storage-capacity-from-art`

## #16 A* path finding

[Issue #16](https://github.com/Liam-M-Mays/game-jam-2026/issues/16)

- [ ] **Changed** · A meeple walks in a straight line to its target. There is no pathfinding and no collision: on a job it walks straight through buildings, trees, rocks and other meeples. *Now:* Decision 11: building bases block walking. Trees, rocks and other meeples still do not. Straight line and 100 units/s stay in #64, with a slight per-meeple speed spread from #46. `meeples-straight-line-walk`

## #6 deconstruct

[Issue #6](https://github.com/Liam-M-Mays/game-jam-2026/issues/6)

- [ ] **Changed** · Once a site is placed it cannot be cancelled, moved or demolished and nothing is refunded; pausing is the only control. Finished buildings are permanent too. *Now:* Decision 12: a building can be destroyed and its cost pops out as drops. #6 (#6) also covers removing a site. `buildings-no-cancel-or-demolish`

## #9 barns should auto put you in placing farms and also cannot overlap their areas with other buildings

[Issue #9](https://github.com/Liam-M-Mays/game-jam-2026/issues/9)

- [ ] **Changed** · Only the Town Hall's ring of cells is protected from resources. Trees, rocks and bushes can spawn or grow back on a barn's farm and silo cells and right beside any other building, just with a lower chance, and they then block that spot until harvested. *Now:* Decision 22: nothing grows back inside a barn's plot area. The Town Hall's ring stays protected. `gap-world-respawn-can-block-plots`

## #7 replace idle jobs with a role system

[Issue #7](https://github.com/Liam-M-Mays/game-jam-2026/issues/7)

- [ ] **Keep** · If a gathering building's worker has already claimed the resource, clicking it is refused with the red flash and shake. `world-harvest-click-claimed`
- [ ] **Keep** · A resource is free for gathering buildings only when nobody has a job on it and it can still be hit. A resource claimed by a building worker shows no outline. `world-harvest-free-rule`
- [ ] **Keep** · Gathering buildings never take bushes, because a bush has no drop that matches what they gather. Bushes are only picked on a player's click. `world-bush-not-auto`
- [ ] **Changed** · Finished buildings can offer work to meeples that have no job. Each building employs at most one meeple at a time, the nearest offering building to the meeple is tried first, and the meeple drops this work as soon as any ordered job is waiting. *Now:* Decision 9: roles replace idle jobs. Workers are assigned to slots and do only their building's work. `buildings-idle-work-offers`
- [ ] **Changed** · When a farm is ripe and food storage is not full, a meeple with nothing else to do walks to it, works briefly and harvests it, adding food and resetting the crop. If the farm stops being harvestable before they finish, they just give up. *Now:* Decision 22: the barn's workers harvest its farms. These carry over: 1.5 s, +1 food, no food cost, not when food is full. `buildings-farm-auto-harvest`
- [ ] **Changed** · Left-clicking a ripe farm orders a meeple to collect it as a normal queued job and outlines the farm; clicking it again cancels the order. The farm flashes red and shakes if food is full or the job queue is full, the order is cancelled automatically if food fills up first, and clicking an unripe farm does nothing. *Now:* Decision 22: a click on a farm opens its barn's panel. The barn's workers collect ripe farms. The collect order by click is gone. `buildings-farm-click-harvest`
- [ ] **Changed** · A finished lumberjack sends one idle meeple to chop the free tree closest to the lumberjack building, then offers the next one. It only does so while you have enough food to pay that tree's food cost, and the food is spent when the tree breaks. *Now:* Decision 9: an assigned worker chops, not an idle meeple. Closest free tree to the building and 1 food per tree should carry over (#66). `buildings-lumberjack-work`
- [ ] **Changed** · A finished miner works exactly like the lumberjack but targets rocks, sending one idle meeple to mine the free rock closest to the miner building for the same food cost. *Now:* Decision 9: an assigned worker mines, not an idle meeple. Closest free rock to the building and 1 food per rock should carry over (#66). `buildings-miner-work`
- [ ] **Changed** · Meeples with no job and no building work carry loose drops of the matching kind into a finished pile that has room. The pile and drop giving the shortest walk are chosen, and drops reserved for construction are left alone. *Now:* Decision 9: a storage worker stores loose drops, not any idle meeple. Leaving reserved drops alone carries over. The worker picks the drop and the pile with the shortest total trip (Decision 32). `buildings-storage-stocking`
- [ ] **Changed** · A free meeple only asks for idle work every so often, not every frame. This also means there is a short standing gap after each finished idle task before it picks up the next one. *Now:* Decisions 5 and 9: idle jobs are gone and nothing polls. A worker still stands for a short moment between two tasks, up to half a second (Decision 32). `meeples-idle-check-interval`
- [ ] **Changed** · A meeple doing idle work drops it the moment a real job is waiting in the queue and takes that job instead. If it was carrying an item to a pile, the item is put down where it stands. *Now:* Decision 9: a worker does only its building's work. Builders are the unassigned meeples. `meeples-idle-yields-to-jobs`
- [ ] **Changed** · Left-clicking a ripe farm queues a collect job and outlines the farm; clicking it again cancels. Clicking an unripe farm does nothing. If food is full or the job queue is full the farm flashes red and shakes instead. *Now:* Decision 22: a click on a farm opens its barn's panel. There is no collect order by click. `meeples-collect-queue-input`
- [ ] **Keep** · On a collect job the meeple walks to the farm, works there for a moment, then the crop is collected: food goes up, the farm flashes and its crop starts growing again from the first stage. *But:* Decision 22: the barn's worker does this, not a builder on a collect order. `meeples-collect-steps`
- [ ] **Changed** · Queuing a collect job on a farm stops any idle meeple that was already on its way to harvest that same farm. *Now:* Decision 22: there is no collect order by click any more, so nothing overrides the barn's worker. `meeples-collect-overrides-idle`
- [ ] **Changed** · When a free meeple looks for idle work, every finished building that has work and no worker yet offers itself, and the meeple takes the offer from the building nearest to itself. *Now:* Decision 9: the player assigns workers with the panel arrows; the add arrow takes the next available meeple. `meeples-idle-offers-nearest-building`
- [ ] **Changed** · A farm, lumberjack or miner keeps only one idle worker busy at a time. A second meeple cannot work the same building until the first one finishes or leaves. *Now:* Decision 9: a set number of worker slots per building, from its data file. 1 each for now. A farm has no slot: the barn's workers harvest it (Decision 22). `meeples-idle-one-per-building`
- [ ] **Changed** · Idle meeples harvest ripe farms on their own when food is not full and the player has not queued a collect job there: walk to the farm, work, food goes up, crop restarts. If the farm stops being harvestable on the way, the meeple gives up. *Now:* Decision 22: the barn's workers harvest its farms. These carry over: 1.5 s, +1 food, no food cost, not when food is full. `meeples-idle-farm`
- [ ] **Changed** · A finished lumberjack offers idle work when there is a free tree, and a finished miner when there is a free rock, as long as the village has enough food to pay for it. The target is always the tree or rock closest to the building, with no distance limit. *Now:* Decision 9: only an assigned worker chops or mines. Carry over: the target closest to the building with no distance limit, and food of at least 1. `meeples-idle-chop-offer`
- [ ] **Keep** · The idle chopper or miner walks to the target and hits it at the same rhythm as a player harvest until it breaks, and the same food cost is paid when it breaks. If the building or the target disappears the meeple gives up. `meeples-idle-chop-steps`
- [ ] **Keep** · A tree or rock an idle worker is heading for is reserved without any outline. If the player clicks it, it flashes red and shakes and no job is queued. The reservation is released if the worker is pulled away. `meeples-idle-chop-reserves-target`
- [ ] **Changed** · If no building has idle work, a free meeple looks for loose wood or stone to stack in a storage pile. For every finished pile that has room and whose resource has spare unpromised units, it considers the loose item closest to itself and picks the pile and item with the shortest total trip. *Now:* Decision 9: only a worker at a storage building stores loose drops. It picks the drop and the pile with the shortest total trip, as today (Decision 32). `meeples-idle-store-choice`
- [ ] **Keep** · On a store task the meeple walks to the loose item, picks it up (shown above its head, always one at a time), walks to the pile and puts it in. The item disappears into the pile, and the pile's art fills up. If the pile disappears the meeple gives up. `meeples-idle-store-steps`
- [ ] **Keep** · A pile stops accepting new store trips once the items inside it plus the items already on their way would fill it. `meeples-idle-store-capacity`
- [ ] **Keep** · If a storing meeple is interrupted, the item it carries is put on the ground where it stands and is loose again. `meeples-idle-store-abort`
- [ ] **Changed** · Several build-menu descriptions explain meeple rules to the player and will need to stay true: homes, lumberjack, miner, piles and farm. *Now:* Decision 9 makes the lumberjack and miner texts untrue ('An idle meeple works here'). Decision 10 makes both pile texts untrue ('so it doesn't go to waste': drops no longer expire). The new wording is Liam's call. Hut, stone hut and farm texts carry over in #68. `meeples-rule-texts-in-building-descriptions`
- [ ] **Keep** · Collecting a ripe farm flashes it white with a rustle sound and resets the crop picture to empty. Its selection outline is removed at the same moment. *But:* The sound is ticked in #73. This issue sends the event. `effects-farm-harvest`
- [ ] **Keep** · Lumberjacks and miners choose their target by what it drops, so a lumberjack chops big trees as well as small ones and a miner mines big rocks as well as small ones. The one closest to the building wins, whatever its size. `gap-gather-buildings-take-big`

## #69 Village life: population, hunger and the Town Hall

[Issue #69](https://github.com/Liam-M-Mays/game-jam-2026/issues/69)

- [ ] **Keep** · At the start a finished Town Hall is placed for free on the deepest inland spot where it fits. `world-start-town-hall`
- [ ] **Keep** · Every building has a required Town Hall level and cannot be picked until the Town Hall reaches it. `buildings-unlock-levels`
- [ ] **Keep** · When any hut is finished it adds its capacity to the village's meeple limit and one new meeple appears at its door straight away. `buildings-hut-housing`
- [ ] **Keep** · While meeples are well fed, there is food, and the population is below total hut capacity, another meeple arrives every so often at the door of a randomly chosen hut. `buildings-hut-growth`
- [ ] **Keep** · The game starts with a finished Town Hall already standing on the most central free spot of the map, with a cloud puff and the first meeple at its door. The player cannot build a Town Hall, and resources never spawn on the cells right next to it. `buildings-townhall-start`
- [ ] **Keep** · The Town Hall has levels 1 to 5 and each upgrade needs a minimum number of living meeples; upgrading costs no materials and is done from the build menu. On upgrade its sprite changes to the next level's art with a white flash. `buildings-townhall-levels`
- [ ] **Keep** · The level used for unlocking buildings is the highest level among finished Town Halls, or 1 if there is none. `buildings-townhall-current-level`
- [ ] **Keep** · A meeple counts as a worker from the moment it enters the scene and stops counting when it leaves or dies. The worker count drives the job cap, hunger, the HUD counter and Town Hall upgrades. *But:* Decision 8: there is no job limit, so the head count no longer sets one. `meeples-register-as-worker`
- [ ] **Keep** · Starvation is the only thing that kills a meeple. Nothing else in the game calls for a meeple to die. `meeples-death-only-by-starvation`
- [ ] **Keep** · A new game starts with the Town Hall already built. The Town Hall is a home, so the village starts with one meeple and room for one. `meeples-start-population`
- [ ] **Keep** · Every home spawns one meeple at its door the moment it is finished, whatever the food situation. A message announces the arrival. *But:* The message is ticked in #70. This issue sends the event. `meeples-hut-spawn-on-complete`
- [ ] **Keep** · The population limit is the total of the capacities of all finished homes, pooled together. `meeples-housing-capacity`
- [ ] **Keep** · Hunger is not a meter that drains; it is simply how much food there is per meeple. It is recalculated whenever food, jobs or the number of meeples changes, and reads full when there are no meeples. `meeples-hunger-formula`
- [ ] **Keep** · Meeples never eat. Food only goes down when a tree or rock is broken, so hunger changes only when food is gained or spent on harvesting, or when the number of meeples changes. A new meeple arriving lowers hunger for everyone. `meeples-never-eat`
- [ ] **Keep** · While the village is well fed, has at least some food, and has fewer meeples than housing capacity, a countdown runs; when it ends a new meeple walks out of a random home. Growth costs no food. The countdown pauses (it does not restart) while the conditions are not met. *But:* Decision 24: no meeple belongs to a house. The random home is only where it walks out. `meeples-growth`
- [ ] **Keep** · On a fixed tick, if the village is starving, there is a chance that one random meeple dies. Each death raises the food per meeple, so deaths stop once the survivors are back above the starving line. `meeples-starvation`
- [ ] **Keep** · Upgrading the Town Hall requires a minimum number of living meeples for each level. A message tells the player when they have enough, and a warning shows the shortfall if they try too early. *But:* The message is ticked in #70. This issue sends the event. `meeples-townhall-needs-population`
- [ ] **Keep** · The game keeps one hunger value from 0 to 100 that is recalculated every time stock or the number of meeples changes. It is full when each meeple has 2 food, and full when there are no meeples. `ui-hunger-value`
- [ ] **Keep** · Upgrading the Town Hall only needs enough living meeples. It costs no materials and uses up no meeples. The hall starts at level 1 and tops out at level 5. `ui-upgrade-requirements`
- [ ] **Keep** · Upgrading the town hall swaps to the next level's picture with a white flash and a short success jingle. *But:* The sound is ticked in #73. This issue sends the event. `effects-townhall-upgrade`
- [ ] **Keep** · A Town Hall upgrade changes only its level: the art and which buildings are unlocked. Its housing stays at one meeple at every level and nothing else about the village changes. `gap-townhall-upgrade-only-unlocks`
- [ ] **Keep** · A meeple that arrives through growth gets no message, no sound and no effect; it simply appears at a home's door and the meeple counter goes up. Only a meeple that arrives because a home was finished is announced. `gap-growth-arrival-silent`
- [ ] **Keep** · The game has no win state. It goes on until every meeple has died or the player leaves; finishing the Statue only shows the normal 'Statue finished!' message. `gap-rule-no-win-condition`

## #70 UI: HUD, build menu and toasts on the new core

[Issue #70](https://github.com/Liam-M-Mays/game-jam-2026/issues/70)

- [ ] **Keep** · When a site's next stage first becomes short of materials, a warning toast says "<Name> needs N more <kind> to keep building", joining several kinds with "and". It fires once per shortage, not again until the shortage has cleared and returned. `buildings-missing-warning`
- [ ] **Keep** · Hovering a construction site shows a tooltip next to the mouse with the building name in bold, "Built X / Y" stages, and "Next stage needs:" with what the next stage still lacks. Kinds that are short are shown in red with "(not enough)", and a paused site adds a yellow line "Paused - right-click to resume". `buildings-site-tooltip`
- [ ] **Keep** · A toast announces each finished building: "<Name> finished!", or "<Name> finished! A new meeple arrived" for any kind of hut. `buildings-completion-toast`
- [ ] **Keep** · A building's menu icon is its finished frame cropped to the visible pixels. Storage piles use their completely full frame instead, and the Statue uses a question-mark picture. `buildings-menu-icon`
- [ ] **Changed** · A building cannot be picked from the build menu (button or number key) unless the job queue has room for its starting deliveries. The button is dimmed and pressing it shows a warning. *Now:* Decision 8: no job limit, so this dimmed state and its warning are not carried over into the build menu. `meeples-build-needs-job-room`
- [ ] **Keep** · Whenever the number of meeples goes down a warning message appears. `meeples-death-warning`
- [ ] **Keep** · A message appears each time the village moves between the three food states: starving, fed, and well fed. No message is shown while there are no meeples. `meeples-hunger-band-messages`
- [ ] **Keep** · The HUD shows the current number of meeples next to the housing capacity and updates whenever either changes. `meeples-counter-ui`
- [ ] **Keep** · The food bar and food label are coloured by the same thresholds the population uses: green when meeples can reproduce, red when they will die, yellow in between. Hovering it shows the food-to-meeple ratio, the current outcome, and the two thresholds. `meeples-hunger-colour-and-tooltip`
- [ ] **Keep** · All UI text uses one pixel font, pixel art is drawn unsmoothed, and the UI is laid out on a 1920x1080 canvas that stretches with the window. `ui-global-look`
- [ ] **Keep** · Whenever a red warning toast actually appears, the game speed drops back to x1 if it was faster. `ui-speed-reset-on-warning`
- [ ] **Keep** · In the game the HUD puts the resource counters at the top centre, the speed button top-right, the toast feed bottom-left, the build button bottom-centre and the food label with the hunger bar bottom-right. *But:* The speed button is ticked in #71. `ui-hud-layout`
- [ ] **Keep** · A dark rounded strip at the top centre shows three counters side by side, each an icon followed by a number: stone, wood, meeples. `ui-counters-panel`
- [ ] **Keep** · The stone and wood counters show just the total amount you own, counting pieces lying on the ground and pieces in storage. `ui-counter-stone-wood`
- [ ] **Keep** · The meeple counter shows living meeples against total housing space. `ui-counter-meeples`
- [ ] **Keep** · A food label next to the hunger bar shows current food against the food limit. `ui-counter-food`
- [ ] **Keep** · The counters update the moment stock, jobs or the number of meeples change. The counters strip never blocks clicks, so you can click the world through it. `ui-counters-refresh`
- [ ] **Keep** · The tall bar in the bottom-right fills from the bottom up to show how full your food store is: current food out of the food limit. It is refreshed every frame. `ui-hunger-bar-fill`
- [ ] **Keep** · The bar fill and the food label text share one colour that shows how your meeples are doing: green when well fed, yellow when just fed, red when starving. `ui-hunger-bar-colour`
- [ ] **Keep** · The bar's fill art is recoloured live to the current colour while keeping its shading and its white highlight pixels. `ui-hunger-bar-shader`
- [ ] **Keep** · Hovering the hunger bar or the food label shows a tooltip titled "Food to meeple ratio" with the food and meeple counts, food per meeple, what will happen to the meeples, and the two thresholds. `ui-hunger-tooltip`
- [ ] **Keep** · The tooltip's outcome line is one of four coloured messages depending on hunger and housing. `ui-hunger-tooltip-outcomes`
- [ ] **Keep** · The hunger tooltip sits to the left of the bar, centred on it but pushed up so it never covers the food label. It uses the same dark tooltip box as the build menu. `ui-hunger-tooltip-placement`
- [ ] **Keep** · Messages appear as a stack in the bottom-left corner. The newest is at the bottom and older ones are pushed upward; each sits on a dark plate just wide enough for its text and wraps if too long. Toasts never block clicks. `ui-toast-feed-layout`
- [ ] **Keep** · There are four kinds of message, told apart by colour and prefix: plain info, tips, warnings and fun facts. `ui-toast-kinds`
- [ ] **Keep** · Each message stays for a fixed time and fades out at the end. The time is real time, so game speed does not change it, and it stops counting while the game is paused. `ui-toast-lifetime`
- [ ] **Keep** · Only a limited number of messages are shown at once; when one more arrives the oldest is removed immediately. `ui-toast-max`
- [ ] **Keep** · If exactly the same message text is requested again within a short real-time window it is silently dropped: no toast, no sound and no speed reset. `ui-toast-repeat-cooldown`
- [ ] **Keep** · When hunger falls into the starving range while at least one meeple is alive, a warning says "Meeples are starving! Get more food". `ui-toast-hunger-starving`
- [ ] **Keep** · When hunger moves into the middle range, an info toast says "Meeples are fed, but won't reproduce". `ui-toast-hunger-fed`
- [ ] **Keep** · When hunger rises into the top range, an info toast says "Meeples are well fed and can reproduce". `ui-toast-hunger-thriving`
- [ ] **Keep** · The moment food drops from something to zero, a warning says "You're out of food! Pick berries or plant farms to gather more". `ui-toast-out-of-food`
- [ ] **Keep** · Whenever the number of meeples goes down, a warning says "A meeple has died, watch your hunger bar!". `ui-toast-meeple-died`
- [ ] **Keep** · When a building you placed is finished an info toast says "<Name> finished!". For huts it says "<Name> finished! A new meeple arrived". `ui-toast-building-finished`
- [ ] **Keep** · If you pick a building, or click to place one, without the materials needed to start it, a warning says "You need more materials to build <Name>". `ui-toast-cant-afford`
- [ ] **Keep** · If you click to place a building where its cells are not free, a warning says "Can't build there". The preview also flashes red and shakes. `ui-toast-cant-build-there`
- [ ] **Keep** · Picking a building that is still locked gives the warning "You need Town Hall level N to build <Name>". `ui-toast-locked-building`
- [ ] **Keep** · Pressing the Town Hall upgrade button without enough meeples gives the warning "You need N meeples to upgrade your Town Hall (you have M)". `ui-toast-upgrade-needs-meeples`
- [ ] **Keep** · As soon as you have enough meeples for the next Town Hall level, an info toast says "You have enough meeples to upgrade your Town Hall! Open the build menu to upgrade it". It shows once each time the condition becomes true, and is re-checked right after an upgrade. `ui-toast-upgrade-ready`
- [ ] **Keep** · After an upgrade, info toasts say "Town Hall reached level N!" and then "New buildings unlocked: A, B, C" listing what that level unlocks. `ui-toast-hall-level`
- [ ] **Keep** · When a building site first runs short of materials for its next stage, a warning says "<Name> needs N more wood to keep building", joining two materials with "and". `ui-toast-site-stuck`
- [ ] **Keep** · Each time the game scene loads, five opening tips are shown one after another in a fixed order as yellow "Tip: ..." toasts. `ui-tips-opening`
- [ ] **Keep** · After the opening tips, the game keeps showing one random tip or fun fact at a time, forever. All tips and facts are shuffled into one deck and nothing repeats until the whole deck has been shown. `ui-tips-rotation`
- [ ] **Keep** · The rotating tips are seven fixed lines, shown with the "Tip: " prefix. *But:* Decision 32: the wheel tip is corrected (the wheel zooms) and "disappear" is spelled right. `ui-tips-list`
- [ ] **Keep** · The rotating fun facts are eleven fixed lines, shown in light blue with the "Fun fact: " prefix. *But:* "Have you zoomed out all the way yet?" is shown only on the giant (Decision 32). `ui-fun-facts-list`
- [ ] **Keep** · Tip timers count real seconds, so game speed does not make tips come faster, and they stop while the game is paused. Retry restarts the opening tips from the first one. `ui-tips-timing`
- [ ] **Keep** · The build button at the bottom centre opens the build menu, and closes it if it is already open. It does nothing while the pause menu is up, and if you were in the middle of placing a building it cancels that first. `ui-build-button`
- [ ] **Keep** · The build menu is a panel in the middle of the screen titled "BUILD" with a two-column grid of buttons. It starts hidden, the game keeps running while it is open, and clicks outside the panel still reach the world. `ui-build-menu-panel`
- [ ] **Keep** · The first button is the Town Hall upgrade. After it the buildings are listed by the Town Hall level that unlocks them, lowest first, and within a level in a fixed order. `ui-build-menu-order`
- [ ] **Keep** · Each building button shows a cropped picture of the finished building, how many of it you have built in square brackets, its name, and what it costs to start. `ui-build-menu-button-text`
- [ ] **Keep** · The cost on each button is only what must be on hand to start the building, not its full cost. `ui-build-menu-start-costs`
- [ ] **Keep** · The number in brackets counts only finished buildings of that type; sites still under construction are not counted. `ui-build-menu-built-count`
- [ ] **Keep** · A building you have not unlocked yet shows the Town Hall level it needs instead of a cost, its text is greyed and its picture is a black silhouette. It can still be clicked, which only gives the warning. `ui-build-menu-locked`
- [ ] **Changed** · An unlocked building you cannot start right now is shown half see-through. That happens when you lack the free materials to start it, or when the job queue has no room for its first deliveries. *Now:* Decision 8: no job limit, so the "no room in the job queue" reason goes. Dimming to 50% when free materials are short stays. #8 (#8) adds a new reason: no barn has room, for Farm and Silo. `ui-build-menu-unavailable`
- [ ] **Keep** · Costs, counts, locked and dimmed states refresh whenever stock, jobs or meeples change, and every time the menu is opened. `ui-build-menu-refresh`
- [ ] **Changed** · Clicking a building checks three things in order: is it unlocked, do you have the starting materials, is there room in the job queue. The first failure shows its warning and leaves the menu open; if all pass the menu closes and you are holding that building ready to place. *Now:* Decision 8: the third check (room in the job queue) goes. The first two checks, their order, and the menu staying open on a failure all stay. #67 and #8 add a new stop: no build mode when nothing can be placed. `ui-build-menu-pick`
- [ ] **Keep** · The build menu closes when you press Esc, press the build button again, successfully pick a building, start placing by hotkey, or when the game over screen appears. `ui-build-menu-close`
- [ ] **Keep** · The number row picks buildings directly in menu order, whether or not the build menu is open, and behaves exactly like clicking that building's button including the warnings. Hotkeys do nothing while the game is paused. `ui-build-hotkeys`
- [ ] **Keep** · Hovering a building button shows a tooltip that follows the mouse: the name in yellow, a description, the total cost of the whole building, its hotkey, and in red the Town Hall level needed if it is locked. `ui-build-tooltip`
- [ ] **Keep** · The tooltip's total cost is the sum of every build stage of that building. `ui-build-tooltip-total-costs`
- [ ] **Keep** · Building names shown in the menu, tooltips and toasts come from the building's file name with underscores turned into spaces and each word capitalised. *But:* The name is a field in the data file. The shown names stay. `ui-building-names`
- [ ] **Keep** · The first button in the build menu upgrades the Town Hall. It shows a picture of the hall at its next level and how many meeples that level needs, and is half see-through until you have enough. It is hidden if there is no finished Town Hall. `ui-upgrade-button`
- [ ] **Keep** · Pressing the upgrade button with enough meeples upgrades at once: the hall changes to its next look with a flash, a success jingle plays, the level and unlock toasts appear, and the menu stays open with the newly unlocked buildings now available. *But:* The sound is ticked in #73. This issue sends the event. `ui-upgrade-press`
- [ ] **Keep** · At the top level the upgrade button reads "Fully upgraded", shows the top-level hall at full brightness, and pressing it does nothing. `ui-upgrade-maxed`
- [ ] **Keep** · Hovering the upgrade button shows a tooltip naming the next level and listing the buildings it unlocks. At the top level it just says the hall is fully upgraded. `ui-upgrade-tooltip`
- [ ] **Keep** · Hovering a building under construction shows a tooltip by the cursor with its name in bold, how many stages are built, and what the next stage still needs. It does not show while paused or while the mouse is over any UI. `ui-site-tooltip`
- [ ] **Keep** · In the site tooltip, a material the village cannot currently supply is shown in red with "(not enough)" after it. `ui-site-tooltip-stuck`
- [ ] **Keep** · If the site is paused, the tooltip adds a yellow line "Paused - right-click to resume". `ui-site-tooltip-paused`
- [ ] **Keep** · When several sites overlap under the cursor, the one lowest on screen (the one in front) is the one described. The same pick decides which site a right-click pauses or resumes. `ui-site-tooltip-pick`
- [ ] **Keep** · Whenever a warning message appears while the game is running faster than normal, the game speed drops back to x1 on its own. `feel-ui-warning-resets-speed`
- [ ] **Keep** · The number row keys 1 to 9, 0 and minus pick a building to place without opening the build menu. They are the only custom input actions in the project and do nothing while paused. `feel-input-build-hotkeys`
- [ ] **Changed** · The HUD is an instanced scene that is handed the build system and the game camera from the game scene. *Now:* Decision 4: the HUD is no longer handed the build system and the camera. It sends commands to the village in view and listens to its events. `feel-scene-hud-wiring`
- [ ] **Keep** · The game is laid out for a 1920 x 1080 view and scales with the window; a window with a different shape shows more of the scene rather than black bars. `feel-project-window`
- [ ] **Keep** · All UI text uses one pixel font by default. `feel-project-font`
- [ ] **Keep** · Each message in the feed stays for a while, then slowly fades out and is removed. When there are too many, the oldest disappears at once. `effects-toast-fade`
- [ ] **Keep** · Feed messages are colour-coded by type and tips and fun facts get a text prefix. `effects-toast-colours`
- [ ] **Keep** · The food bar and the food number change colour with how well fed the village is: green when thriving, yellow when just fed, red when starving. `effects-hunger-bar-colour`
- [ ] **Keep** · The bar's fill art is recoloured live: its dark and light shading is kept, and its highlight pixels stay white. `effects-hunger-bar-shader`
- [ ] **Keep** · In the build menu, buildings you cannot start right now are half see-through, and buildings locked behind a town hall level show grey text and a black silhouette icon. The upgrade button is also half see-through until you have enough meeples. `effects-build-menu-tints`
- [ ] **Keep** · The hover tooltip over a construction site follows the mouse and colours its warning lines: resources it cannot get are red and the paused note is yellow. `effects-construction-tooltip`
- [ ] **Keep** · Only buildings under construction have a hover tooltip. Hovering a finished building, a pile, a farm, a tree, a rock or a bush shows the glow but no text, so how full a pile is, how far a crop has grown or how many hits are left can only be read from the art. *But:* Decision 28: hovering a pile shows how full it is. The rest stays without text. `gap-ui-no-info-on-finished-things`
- [ ] **Keep** · Costs are written as amount then kind, joined with ' / ' when there are two kinds. A building with no cost shows the word 'Free', on its button and as 'Total cost: Free' in its tooltip. `gap-ui-cost-text-format`
- [ ] **Keep** · With no meeples alive, the hunger tooltip shows only its title and the line 'N food, no meeples to feed'. `gap-ui-hunger-tooltip-no-meeples`
- [ ] **Keep** · The build menu tooltip and the building-site tooltip sit right and below the mouse and are pushed back inside the screen when they would run off an edge. `gap-ui-tooltips-stay-on-screen`

## #71 UI: main menu, pause, game over and game speed

[Issue #71](https://github.com/Liam-M-Mays/game-jam-2026/issues/71)

- [ ] **Keep** · All meeple movement, job timers, wander pauses, growth countdown and the starvation tick run on game time, so the speed setting speeds all of them up together. `meeples-game-speed-scales-everything`
- [ ] **Keep** · Starting a new game or retrying cancels every job and empties the queue. `meeples-job-reset-new-game`
- [ ] **Keep** · When the last meeple dies the game is over: the music winds down, the build menu closes and the death screen fades in and pauses the game, and the pause key stops working. *But:* The sound is ticked in #73. This issue sends the event. `meeples-game-over`
- [ ] **Keep** · The main menu has a constant rain of meeples falling from above the screen to below it, each at its own speed and at a random horizontal position. `meeples-menu-rain`
- [ ] **Keep** · Each falling menu meeple has a random shirt colour and an off-white head; most of them spin as they fall. `meeples-menu-look`
- [ ] **Keep** · A small share of the falling menu meeples are put on a separate front layer; the rest fall on the layer behind. `meeples-menu-layers`
- [ ] **Keep** · The game opens on the main menu. The game scene is only reached through the Start button, and the HUD is one scene dropped into the game scene and wired to its build system and camera. *But:* Kept: the game opens on the menu and Start is the only way in. The scene paths are new. `ui-main-scene-entry`
- [ ] **Keep** · The main menu shows three image buttons in a column in the lower middle: Start, Credits and Quit. Each has normal, hover and pressed art. `ui-menu-buttons`
- [ ] **Keep** · Pressing Start resets everything to a fresh game and loads the game scene. `ui-menu-start`
- [ ] **Keep** · Pressing Credits opens a panel over the menu with the credit lines and a Back button. Back hides it again, and the panel is hidden whenever the menu loads. `ui-menu-credits-panel`
- [ ] **Keep** · The credits panel lists four people and their roles, one per line. `ui-menu-credits-text`
- [ ] **Keep** · Pressing Quit on the main menu closes the game at once, with no confirmation. `ui-menu-quit`
- [ ] **Keep** · The Mighty Meeple logo is drawn large across the top of the main menu. `ui-menu-logo`
- [ ] **Keep** · Behind the menu, layers of sky, mountains and trees scroll sideways forever, each at its own speed, and repeat seamlessly. `ui-menu-parallax`
- [ ] **Keep** · Meeples rain down the main menu from above the top edge at random horizontal positions. Most fall behind the logo and buttons and a few fall in front of them; each is removed once it is below the screen. `ui-menu-meeple-rain`
- [ ] **Keep** · Each falling menu meeple gets a random shirt colour with a pale head, and may be tilted and spinning as it falls. *But:* Decision 32: the start tilt is up to 35 degrees. The spin stays as it is. `ui-menu-meeple-look`
- [ ] **Keep** · Start and Retry both begin a clean game: stock goes back to the starting amount, all jobs are cancelled, the toast repeat memory is cleared, speed returns to x1 and hunger is recalculated. `ui-new-game-reset`
- [ ] **Keep** · Game speed has four steps and cycling past the last one wraps back to the first. The chosen step speeds up the whole game clock. `ui-speed-steps`
- [ ] **Keep** · Pressing F moves to the next game speed. It does nothing while the game is paused, and holding the key does not repeat. `ui-speed-key`
- [ ] **Keep** · A button in the top-right corner shows the current speed and moves to the next speed when clicked. It can only be used with the mouse. `ui-speed-button`
- [ ] **Keep** · Esc does one thing per press, in this order: cancel the building you are placing; otherwise close the build menu; otherwise close the pause menu; otherwise open the pause menu. After game over Esc does nothing. `ui-esc-priority`
- [ ] **Keep** · The pause menu freezes the game, darkens the screen and shows three image buttons in the middle: Resume, Menu and Quit. `ui-pause-menu`
- [ ] **Keep** · Resume, or Esc, closes the pause menu and the game carries on at the speed it had. `ui-pause-resume`
- [ ] **Keep** · The Menu button on the pause menu leaves the current game and returns to the main menu. Nothing is saved. `ui-pause-to-menu`
- [ ] **Keep** · The Quit button on the pause menu and on the game over screen closes the game at once, with no confirmation. `ui-pause-quit`
- [ ] **Keep** · While paused, the F key, the build hotkeys and the build button do nothing, the building-site tooltip is hidden, and toast and tip timers stand still. The HUD itself keeps running so the pause and game over buttons work. `ui-pause-blocks`
- [ ] **Keep** · The game is lost when the last meeple dies. From that moment Esc is disabled, the music starts dying, and after a short real-time delay the game over screen comes up. *But:* The sound is ticked in #73. This issue sends the event. `ui-game-over-trigger`
- [ ] **Keep** · The game over screen closes the build menu, pauses the game and fades in over the frozen view, then the background keeps darkening until it is fully black. It shows a big GAME OVER image with Retry, Menu and Quit buttons below the centre. `ui-game-over-screen`
- [ ] **Keep** · Retry resets everything to a fresh game and reloads the game scene, so you start again with a new world and the opening tips. `ui-game-over-retry`
- [ ] **Keep** · The Menu button on the game over screen returns to the main menu. `ui-game-over-menu`
- [ ] **Changed** · Holding the X key runs the game fast; letting go returns to the speed shown on the speed button. It works in every scene and while paused, and is not shown anywhere in the UI. *Now:* Decision 32: holding X for x3 is dropped. `feel-dev-hold-x-fast`
- [ ] **Changed** · If the game window loses focus, the fast-forward from the X key is cancelled and the game returns to the selected speed. *Now:* Decision 32: the X key is dropped, so there is nothing to reset. `feel-dev-focus-loss-reset`
- [ ] **Keep** · Pressing F steps the game speed to the next setting and wraps around. It does nothing while paused. `feel-input-f-speed`
- [ ] **Keep** · Escape backs out of whatever is open, one thing at a time: first it cancels building placement, otherwise closes the build menu, otherwise closes the pause menu, otherwise opens the pause menu. After game over it does nothing. `feel-input-escape`
- [ ] **Keep** · The game starts on the main menu; pressing Start resets the game state and loads the game scene. *But:* Kept: the game opens on the menu and Start is the only way in. The scene paths are new. `feel-project-start-scene`
- [ ] **Keep** · One second after the last meeple dies the game pauses and the game-over screen fades in, then the dim behind it deepens to full black. `effects-death-screen-fade`
- [ ] **Keep** · The pause menu and the game-over screen put a half-transparent black layer over the game. `effects-pause-dim`
- [ ] **Keep** · Picture buttons swap their art when hovered or pressed; there is no animation on them. `effects-button-states`
- [ ] **Keep** · The main menu background uses the same tree, mountain and sky layers, drifting faster than in the game. `effects-parallax-menu`
- [ ] **Keep** · On the main menu, meeples with random shirt colours rain down the screen, some spinning, a few passing in front of the menu and the rest behind it. `effects-menu-meeple-rain`
- [ ] **Keep** · Not every picture button has hover art. The build button and the three main menu buttons change on hover; the pause menu buttons, the game over buttons and the credits Back button only have normal and pressed art. `gap-ui-buttons-without-hover-art`
- [ ] **Keep** · There is no options screen: no volume control, no fullscreen toggle and no key rebinding. Nothing is written to disk, so every start is a new game. `gap-ui-no-options-or-save`

## #29 Show the player how the job queue works

[Issue #29](https://github.com/Liam-M-Mays/game-jam-2026/issues/29)

- [ ] **Changed** · The HUD never shows how many jobs are queued or what the job limit is. The player only learns the queue is full from dimmed build buttons and the 'Job queue is full' warning. A text overlay that printed 'Jobs: n / limit' exists only in unused test scenes. *Now:* Decisions 8 and 29: no job limit. The HUD shows a count of the waiting jobs. `gap-ui-no-job-counter`

## #72 Feel: camera and input for a big world

[Issue #72](https://github.com/Liam-M-Mays/game-jam-2026/issues/72)

- [ ] **Keep** · The game opens zoomed in close on the village on the giant's back. *But:* On the ground: centred on the start cell, same size on screen. The torso position is giant only. `feel-cam-start-view`
- [ ] **Changed** · The camera can zoom from a wide view of the whole giant to very close on the village, and no further either way. *Now:* Decisions 1 and 13: the zoom-out limit of 1.6 was set to frame the whole giant; a ground world of about 100,000 cells needs a new one. The zoom-in limit of 20 stays. The 1.6 limit goes with #76. `feel-cam-zoom-limits`
- [ ] **Keep** · Holding W, A, S or D pans the camera up, left, down or right at a constant on-screen speed regardless of zoom. Diagonals are not faster. `feel-cam-wasd-pan`
- [ ] **Keep** · Holding E zooms in and holding Q zooms out smoothly, centred on the middle of the screen. `feel-cam-qe-zoom`
- [ ] **Keep** · The mouse wheel zooms in and out towards the mouse pointer: the point under the pointer stays under the pointer. `feel-cam-wheel-zoom`
- [ ] **Keep** · Holding the right mouse button and dragging pans the camera so the world follows the mouse one to one. `feel-cam-right-drag-pan`
- [ ] **Keep** · A trackpad pinch zooms the camera towards the pointer by the amount of the pinch. `feel-cam-trackpad-pinch`
- [ ] **Keep** · A two-finger trackpad scroll zooms the camera towards the pointer (it does not pan). `feel-cam-trackpad-scroll`
- [ ] **Keep** · Camera mouse and trackpad controls only react to input the UI did not use, so scrolling or dragging over a UI panel that takes the event does not move the camera. The WASD and Q/E keys are read directly each frame. `feel-cam-mouse-blocked-by-ui`
- [ ] **Keep** · Left click acts on the thing under the mouse (or places the building while in placement mode). Right button drags the camera; a right click that barely moves on a construction site pauses or resumes that site. *But:* Only the right-drag is ticked here. The left click and the site pause are ticked in #66 and #67. `feel-input-mouse-buttons`
- [ ] **Keep** · All keyboard controls go by key position, not the letter printed on the key, so they sit in the same place on non-QWERTY layouts. `feel-input-physical-keys`
- [ ] **Keep** · Meeples cannot be clicked, hovered or selected. The player never gives an order to a specific meeple; orders are given by clicking objects and whichever meeple gets its turn first takes them. *But:* Decision 8: a job picks the closest free builder, not whichever meeple gets its turn first. `gap-meeple-not-clickable`

## #73 Feel: music and sounds on the new core

[Issue #73](https://github.com/Liam-M-Mays/game-jam-2026/issues/73)

- [ ] **Keep** · Every hit, including the breaking one, plays the resource's hit sound at its position. `world-harvest-hit-sound`
- [ ] **Keep** · A hammer sound plays at the site every time a unit of material is delivered to it. `buildings-sound-hammer`
- [ ] **Keep** · A short success riff plays when the Town Hall is upgraded. `buildings-sound-upgrade-riff`
- [ ] **Keep** · A grass rustle plays at the farm when its crop is harvested. `buildings-sound-grass`
- [ ] **Keep** · A log thud plays at the pile each time an item is stored in a Wood Pile or Stone Pile. `buildings-sound-log`
- [ ] **Keep** · A hurt sound plays at the meeple's position when it dies. `meeples-death-sound`
- [ ] **Keep** · Each delivered unit plays a hammer sound at the site and makes the site pop slightly. `meeples-haul-delivery-feedback`
- [ ] **Keep** · A rustling grass sound plays at the farm when a crop is collected, by either a queued collect job or an idle farm worker. *But:* Decision 22: the crop is collected by the barn's worker. `meeples-collect-sound`
- [ ] **Keep** · Putting an item into a pile plays a log thud at the pile and makes the pile pop slightly. `meeples-idle-store-sound`
- [ ] **Keep** · Every warning toast that appears plays a warning sound. `ui-toast-warning-sound`
- [ ] **Keep** · Every button in the game, on the main menu, the HUD, the build menu and the pause and game over screens, plays a click sound when pressed. `ui-button-click-sound`
- [ ] **Keep** · On game over the gameplay music winds down like a dying tape: it drops in pitch, wobbles, gets crunchy, goes silent and stops. It keeps playing out while the game is paused on the game over screen. `ui-game-over-music`
- [ ] **Keep** · Everything the player hears (menu and game) is boosted, because the master audio bus is turned up once at startup and left there. `feel-audio-master-boost`
- [ ] **Keep** · Music, the success riff and the UI click and warning sounds keep running while the game is paused, because the music controller (which also owns the UI sound node) is set to always process. The village sound and giant sound nodes have no such setting. `feel-audio-keeps-playing-when-paused`
- [ ] **Keep** · The music track plays on its own audio bus that is created at startup and carries a lo-fi distortion effect (silent in normal play, used by the game over effect). The success riff and UI sounds do not go through this bus. `feel-music-own-bus`
- [ ] **Keep** · On the main menu the menu theme plays on a loop. `feel-music-menu`
- [ ] **Keep** · In the game scene the gameplay track plays, quieter than the menu theme. `feel-music-gameplay`
- [ ] **Keep** · The gameplay track plays its intro once and then loops only its later section forever. `feel-music-gameplay-loop`
- [ ] **Keep** · Every time a new scene instance becomes current (start game, Retry reload, back to menu) the right track starts again from the beginning, and any game over effect is cancelled: pitch, distortion and volume go back to normal. `feel-music-restarts-per-scene`
- [ ] **Keep** · A short success riff plays once each time the Town Hall is upgraded. It plays over the music, is not changed by zoom, and restarts if triggered again. `feel-music-success-riff`
- [ ] **Keep** · When the last meeple dies the music melts down: it slows to a near stop with a growing wobble, gets crunchy with lo-fi distortion, stays audible for most of the effect, then fades to silence and stops. `feel-music-game-over-meltdown`
- [ ] **Keep** · The game over music effect runs in real time: it is not sped up by game speed and it keeps going while the death screen pauses the game. A second request while one is running is ignored. `feel-music-game-over-real-time`
- [ ] **Keep** · Every button in the whole game makes the same click when pressed: main menu, HUD build and speed buttons, build menu entries, pause menu and death screen buttons. Buttons created later are picked up automatically. `feel-ui-click`
- [ ] **Keep** · Every warning message that actually appears plays a warning sound. Info, tip and fun fact messages are silent. *But:* Decision 8: the "job queue is full" refusal is gone. The other warnings stay. `feel-ui-warning-sound`
- [ ] **Keep** · The village has six sound types, each with its own loudness and several recorded variants. `feel-village-sound-table`
- [ ] **Keep** · Each village sound picks one of its variants at random and plays at a slightly random pitch, so repeated hits do not sound identical. `feel-village-variation`
- [ ] **Keep** · The same type of village sound cannot play again until a short gap has passed, no matter how many meeples are working. Extra requests in that window are dropped silently. The gap is measured in real time, not game time. `feel-village-min-gap`
- [ ] **Keep** · At most six village sounds can play at once; a new one is dropped if all six are busy. `feel-village-voice-limit`
- [ ] **Keep** · Village sounds do not start at all when the camera is zoomed out far, or when the thing making the sound is a full screen-width or more away from the centre of the view. They also need a camera to exist. `feel-village-not-started-when-far`
- [ ] **Keep** · Village sounds are loudest when zoomed in on the village and fade as the camera zooms out. Sounds already playing follow the zoom live. `feel-village-volume-by-zoom`
- [ ] **Keep** · Village sounds get quieter the further their source is from the centre of the screen, and follow the camera as it pans. `feel-village-volume-by-screen-position`
- [ ] **Keep** · Village sounds are placed left or right in stereo by where their source is on screen, with a stronger than default stereo spread. `feel-village-panning`
- [ ] **Keep** · An axe chop plays at the tree on every hit a meeple lands on a tree or big tree, including the final hit that breaks it. `feel-village-axe-when`
- [ ] **Keep** · A pickaxe strike plays at the rock on every hit a meeple lands on a rock or big rock, including the final breaking hit. `feel-village-pickaxe-when`
- [ ] **Keep** · A grass rustle plays on every hit on a berry bush, and also each time a farm crop is successfully harvested. `feel-village-grass-when`
- [ ] **Keep** · A hammer knock plays at a construction site each time one resource is delivered to it. `feel-village-hammer-when`
- [ ] **Keep** · A wooden thud plays at a storage building each time a resource is put into it. `feel-village-log-when`
- [ ] **Keep** · A hurt cry plays at a meeple the moment it dies. `feel-village-hurt-when`
- [ ] **Keep** · A bird ambience loop drifts in and out in the game: it starts silent, fades in for a while, fades out for a longer while, and repeats with random lengths. `feel-village-birds-cycle`
- [ ] **Changed** · The bird ambience is very quiet, is not positional, and gets quieter still as the camera zooms out. *Now:* Decision 32: the bird ambience is raised until it can be heard. It stays non-positional and still gets quieter as the camera zooms out. `feel-village-birds-volume`
- [ ] **Keep** · The bird ambience is stopped whenever there is no 2D camera, which is the case on the main menu. `feel-village-birds-need-camera`
- [ ] **Keep** · On game over the music slows down to a crawl with a growing wobble and lo-fi distortion, then fades to silence and stops. `effects-gameover-music`
- [ ] **Keep** · Many actions make no sound of their own: placing a building, a farm appearing, a meeple arriving, picking up or dropping an item, queuing or cancelling an order, and a refused click. A refused click is only heard when it also raises a warning message. *But:* #45: placing a building plays the hammer. The other silent actions stay silent. `gap-sound-silent-actions`
- [ ] **Keep** · Sound levels and the HUD are tied to fixed camera zoom numbers chosen for the giant scene. Village sounds are full at zoom 6 and do not start at zoom 2.2 or less, gameplay music fades between the camera's minimum zoom and zoom 6, giant sounds use their own village zoom, and the HUD hides at exactly the minimum zoom. A scene with a different zoom range gets different loudness with no code change. *But:* Only the village sound numbers are kept here. On the ground the music does not fade and the HUD does not hide (Decision 32). Giant sounds are checked in #76. `gap-structure-zoom-constants`

## #76 Giant: run the village system on the giant's back

[Issue #76](https://github.com/Liam-M-Mays/game-jam-2026/issues/76)

- [ ] **Giant only** · A cell only exists if all six corners of its outline are on ground. Ground means inside one of the yard rectangles and not under an opaque pixel of the cover sprite (the giant's torso art). `world-ground-fit-rule`
- [ ] **Giant only** · The ground on the giant is two overlapping green rectangles, a wide one and a narrower one shifted up and left. They are drawn behind the torso art, so they show only where the torso picture is transparent. `world-ground-yard-shape`
- [ ] **Giant only** · Both yard rectangles share one generated material and the smaller one carries an origin offset, so the pattern continues across them without a seam. `world-ground-two-sprites-aligned`
- [ ] **Giant only** · When the camera is zoomed out as far as it goes, the whole HUD disappears so the giant is seen clean. It comes back as soon as you zoom in, and it is always shown while the game is paused so the pause and game over screens stay visible. *But:* On the ground the HUD always stays (Decision 32). `ui-hud-hidden-zoomed-out`
- [ ] **Giant only** · Gameplay music gets quieter as the camera zooms out and is silent at the fully zoomed out giant view; it is at full level when zoomed in on the village. Menu music is not affected. *But:* On the ground the music stays at full level (Decision 32). `feel-music-zoom-fade`
- [ ] **Giant only** · Each time one of the giant's hands slams down, a deep stomp plays at that hand. The same stomp recording never plays twice in a row and each is pitched down by a slightly random amount. `feel-giant-stomp-sound`
- [ ] **Giant only** · Stomps get louder the further the camera is zoomed out and are loudest at the full giant view. `feel-giant-stomp-volume`
- [ ] **Giant only** · All giant sounds (stomps and crumbles) are completely silent while the camera is zoomed in on the village. `feel-giant-silent-when-zoomed-in`
- [ ] **Giant only** · As the stepping hand starts to lift, a quiet rock crumble plays near that hand a moment later. `feel-giant-crumble-on-lift`
- [ ] **Giant only** · Right after each stomp a crumble plays at the hand that landed. `feel-giant-crumble-after-stomp`
- [ ] **Giant only** · After each stomp, two more crumbles play a little later from random spots around the giant's body. `feel-giant-crumble-scattered`
- [ ] **Giant only** · Each crumble is a random rock-fall recording, pitched very low and placed a little randomly around its source so it does not always come from the same spot. `feel-giant-crumble-sound`
- [ ] **Giant only** · Crumbles fade in as the camera zooms out past the village, are loudest part of the way out, then drop back at the full giant view. Crumbles away from the centre of the screen are quieter. `feel-giant-crumble-volume`
- [ ] **Giant only** · The scattered crumbles come from 14 marked spots on the giant: three on each arm, six around the torso and two on the head. `feel-giant-crumble-points`
- [ ] **Giant only** · At most 16 giant sounds can overlap; a new one is dropped if all are busy. Giant sounds have no engine distance falloff; their volume comes only from zoom and screen position. `feel-giant-voice-limit`
- [ ] **Giant only** · The delays before crumbles are game timers, so pending crumbles wait while the game is paused. `feel-giant-crumble-timers-pause`
- [ ] **Giant only** · The giant walks in place in a repeating cycle: lift, hang in the air, slam down, settle, pause. All moving parts share the same cycle length. `feel-giant-walk-cycle`
- [ ] **Giant only** · The two arms take turns: each cycle exactly one arm does the lift and slam while the other stays planted. The background arm steps first. `feel-giant-arms-alternate`
- [ ] **Giant only** · The stepping arm rises and reaches forward (left), hangs, slams down slightly past ground level, then springs back to ground level and rests. `feel-giant-arm-step-motion`
- [ ] **Giant only** · While one arm steps, the other planted arm slides back (right) along the ground with no lift. `feel-giant-arm-slide-back`
- [ ] **Giant only** · The giant's body (head, torso and the whole village on its back) rises during each lift and drops with a thud just after the hand lands, then settles. `feel-giant-body-bob`
- [ ] **Giant only** · The head has its own extra nod on top of the body: it lifts a little and leans, then swings sideways and down on the slam and returns. `feel-giant-head-bob`
- [ ] **Giant only** · The black eye backdrop and both eyes shift down inside the face on each slam and slide back, so the eyes jolt on impact. `feel-giant-eyes-drop`
- [ ] **Giant only** · The whole giant leans forward (left) as a hand lifts, holds there through the slam, then eases back to where it started. `feel-giant-drift`
- [ ] **Giant only** · The giant blinks: both eyes vanish together for half a second at a regular interval by dropping behind the black eye backdrop. `feel-giant-blink`
- [ ] **Giant only** · The giant's walk (and so the stomp rhythm) advances with game time: it speeds up at higher game speed and stops while paused. `feel-giant-speed-follows-game-speed`
- [ ] **Giant only** · The camera can never show anything outside the frame seen at full zoom out. The closer the zoom, the further it can pan; at full zoom out it cannot pan at all. `feel-cam-bounds`
- [ ] **Giant only** · While zoomed in, the camera is attached to the giant's torso, so the village stays steady on screen while the giant bobs and the background moves behind it. `feel-cam-rides-giant`
- [ ] **Giant only** · At full zoom out the camera lets go of the giant and sits still at a fixed spot, so the player sees the whole giant bobbing and walking in frame. `feel-cam-wide-view-detach`
- [ ] **Giant only** · At full zoom out the whole HUD disappears for a clean view of the giant; it comes back as soon as the player zooms in, and it is always shown while paused. *But:* On the ground the HUD always stays (Decision 32). `feel-cam-hud-hidden-wide`
- [ ] **Giant only** · The giant is built from separate sprites that move on their own: a body group holding the head (with eye backdrop and two eyes) and the torso, plus a foreground arm and a background arm. `feel-scene-giant-rig`
- [ ] **Giant only** · Back to front the player sees: sky, far mountains, near mountains, far trees, near trees, the background arm, the yard ground, the torso with the village on it and the foreground arm, then the head on top. `feel-scene-draw-order`
- [ ] **Giant only** · The whole village (grid, resources, buildings, meeples, build system and mouse cursor area) lives on the giant's torso at one tenth scale, sorted by depth, and moves with the torso. `feel-scene-village-on-back`
- [ ] **Giant only** · The buildable ground is the area covered by two overlapping green yard rectangles on the torso, minus anywhere the torso picture itself is solid. The yard uses the soft noise look. `feel-scene-ground-yard`
- [ ] **Giant only** · Five background layers scroll sideways on their own at different speeds, nearest fastest, so the giant looks like it is walking through the land. Each layer tiles sideways. `feel-scene-parallax`
- [ ] **Giant only** · The giant sound node is told which camera to listen from, which parts count as feet (the two arms), and the 14 crumble spots, and the scene overrides several of its mix values. `feel-scene-giant-audio-wiring`
- [ ] **Giant only** · The whole HUD disappears when the camera is zoomed all the way out, and comes back when you zoom in or pause. *But:* On the ground the HUD always stays (Decision 32). `effects-hud-hide-zoomed-out`
- [ ] **Giant only** · Behind the giant, layers of trees, mountains and sky drift sideways at different speeds, nearer layers faster. `effects-parallax-game`
- [ ] **Giant only** · The giant's body (with the village on its back) and head rise slowly, hang, slam down past their rest position and settle back, over and over. `effects-giant-body-step`
- [ ] **Giant only** · The giant's two arms take turns stepping: an arm shifts sideways and lifts, hangs, slams down with a small dip and settles, while the other waits. `effects-giant-arms`
- [ ] **Giant only** · The whole giant slides slightly sideways during each step and eases back before the next one. `effects-giant-drift`
- [ ] **Giant only** · The giant's eyes blink: every so often each eye drops behind the layer under it for a moment. `effects-giant-blink`
- [ ] **Giant only** · The camera rides on the giant, so the village looks still while the giant walks. Only when zoomed all the way out does the camera let go, so you see the giant stomp and bob. `effects-camera-rides-giant`
- [ ] **Giant only** · When the HUD is hidden at full zoom-out, only its drawing is turned off. The number hotkeys, F and Esc still work, messages keep arriving and timing out unseen, and the building-site tooltip still appears because it lives on its own layer. *But:* On the ground the HUD always stays (Decision 32). `gap-ui-hud-hidden-still-active`

## No issue

These belong to no issue.

- **Out of scope** · When the game scene starts, the world is set up in a fixed order: build the cells, measure each cell's distance from the edge, pick the seed and paint the ground, place the Town Hall, then spawn the resources. *Why:* Order of calls in the old Grid ready step. The results that matter (Town Hall placed before resources, ring kept clear, one seed) are separate lines owned by #48. `world-setup-order`
- **Out of scope** · If the grid is given no ground sprites, every cell in the block exists and no patterned ground is generated. This is the path a flat, non-giant map would take today. *Why:* A fallback path the jam game never takes: the game scene always sets ground sprites. The new ground shape comes from #48 (decision 13). `world-ground-none-fallback`
- **Out of scope** · Every tree, rock and bush joins one shared group, which respawn counting and the gathering buildings use to find them. *Why:* A Godot group used to look things up. Trees, rocks and bushes become data rows (decision 5). `world-harvest-group`
- **Out of scope** · When a drop is deleted while it sits in a storage pile, the pile lets go of it first, so the pile's fill level stays right. *Why:* Node clean-up detail. A pile holds a count in the new core (#63), so its fill level cannot drift. `world-drop-leaves-storage`
- **Out of scope** · Each cell carries its own physics area in the shape of the slanted cell. The cell cursor uses it to light the cells under the mouse, and that cursor is switched off in the game scene. *Why:* The physics areas go (decision 7). The cursor they feed is on while a building is being placed. It is kept as a cell highlight in #62. `world-cell-area`
- **Out of scope** · Hut (hut_build scene): an older two-cell wooden hut for one meeple. It is not in the build menu and nothing in the game places it. *Why:* Unused scene: nothing references hut_build.tscn, it is not in the build menu and it is not one of the eleven buildings. A player never sees it. Its art stays in the project (decision 1). `buildings-scene-hut-build`
- **Out of scope** · Every job has three steps the meeple drives: start once when taken, update every frame until it reports done, and abort when the worker is pulled off it. Jobs also carry a cancelled flag. There are two families: player/site jobs (harvest, haul, collect crop) and idle jobs tied to a building (chop, farm, store). *Why:* Class layout of the old job code. Each job kind has its own row. The per-frame update and the idle family are replaced by decisions 5, 8 and 9. `meeples-job-class-contract`
- **Out of scope** · Any scene that is not exactly the main menu or the game scene has no music; the track is stopped. *Why:* A player only ever sees the menu and the game scene (credits is a panel inside the menu), so this is never heard. Trap: music is picked by scene file path, so the new game scene gets no music until #73 starts it another way. `feel-music-other-scenes-silent`
- **Out of scope** · Every build includes every resource in the project, unencrypted. *Why:* Build packaging; a player cannot notice it. Heads-up: #74 and #31 say dev tools must not ship, so the all-resources filter cannot stay as it is. `feel-export-everything-included`
- **Out of scope** · The game has no particles, no lights or lighting, no camera shake, no full-screen flash and no animation-player timelines. Every effect is a tween, a shader parameter, a sprite-sheet animation or a per-frame formula. *Why:* A list of what the old game does not use; nothing to build. The rework adds none of them (lighting is out per decision 1; the toolkit's shake is the refused-click shake, not a camera shake). `effects-none-of-these-exist`
- **Out of scope** · A flat, giant-free test level already exists next to the game scene. It has the grid with no ground sprites (so every cell exists and no ground is painted), the starting Town Hall, one hand-placed meeple, the build system, a plain camera and a text-only overlay, but no HUD, so nothing can be built in it and no music plays. *Why:* An unused dev scene the player cannot reach, and nothing can be built in it. #48 makes the real ground game, #32 covers dev starts, #36 removes unused scenes. `gap-structure-flat-test-level`
- **Out of scope** · The game scene and the main menu are found by fixed file paths in several places: the Start button, the pause menu's Menu button, the music chooser and the CI start-up test. Moving or renaming either scene means changing all of them together. *Why:* Only how the old code finds its scenes. The new paths are set once in #71: the start and menu buttons, the main scene and its CI line. #36 takes the old lines out. `gap-structure-scene-paths-hardcoded`

## #36 Tidy the project structure

[Issue #36](https://github.com/Liam-M-Mays/game-jam-2026/issues/36)

- [ ] **Keep** · The project icon is the SVG stored in assets/Res. *But:* The icon file moves out of assets/ before the old tree goes. `world-res-project-icon`
- [ ] **Changed** · The application is named after the jam repository and uses the project icon. *Now:* Decision 32: the app is named "Mighty Meeple". The icon stays, and its file moves out of assets/ before the old tree goes. `feel-project-name-icon`

## #77 Finish: switch master to the rework

[Issue #77](https://github.com/Liam-M-Mays/game-jam-2026/issues/77)

- [ ] **Keep** · The Windows build is a single 64-bit exe with the game data packed inside it. *But:* Decision 31: this issue builds the export and starts it once. `feel-export-windows`
- [ ] **Changed** · There is a web (HTML) build that fills the browser window, takes keyboard focus on start, and runs without threads. *Now:* Decisions 6 and 31: desktop only. The web preset is deleted. `feel-export-web`
- [ ] **Keep** · There is a macOS build for both Intel and Apple Silicon in the Games category, with high-resolution display on. *But:* Decision 31: this issue builds the export and starts it once. `feel-export-macos`
