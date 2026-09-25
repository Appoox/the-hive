# The Hive — Requirements & Design

**Status:** v1 specification, derived from four rounds of design questionnaires.
**Target:** Android (landscape), developed desktop-first on Linux. Test device: OnePlus 12.
**Engine:** Godot 4.7.2.stable, GDScript only, Compatibility renderer.

Every numeric value in this document is a **starting point**, not a commitment. All of them live in `data/tuning.json` and are adjustable at runtime via the debug overlay. The v0.2 milestone exists specifically to find out which of them are wrong.

---

## 1. What this is

A game about an ant colony, in which the player inhabits a single worker ant.

The player is never a commander. There is no unit selection, no order queue, no click-to-move-army. The player is one small body in a large system, and the colony's behaviour is shaped indirectly — through scent, through where you dig, through which crumb you chose to chase.

### 1.1 Core verb — range management

The player's continuous decision is **how far from the nest they dare to be.**

Foraging happens on the surface. The nest is a separate scene. While above ground the player cannot act on the nest at all — soldiers respond to alarm autonomously, workers evacuate brood autonomously. The only signal is alarm scent leaking out of the entrance.

So every crumb further out is a bet against a threat that hasn't appeared yet. That tension is the game.

### 1.2 Emotional target — anticipation and accepted loss

The player will sometimes return to find larvae gone and nothing they could have done differently. This is intended. The game is not about heroic saves; it is about running a system you only partly control and living with the results.

Tuning must protect this. Losses should feel like consequences of range decisions, not like arbitrary punishment.

### 1.3 The player never fights

The player possesses workers only. Workers cannot win a fight. Available verbs under threat: flee, carry brood away, seal a tunnel, lay alarm scent.

Soldiers do the killing, autonomously, in response to alarm. The player's contribution to a defence is *the alarm scent they laid before running*.

This is the most distinctive decision in the design and must not be quietly eroded.

### 1.4 Session and lifespan

- Target session: ~20 minutes
- A badly-played colony dies in 20–30 minutes
- A well-played colony persists indefinitely in principle, bounded in practice by map size and food yield — a natural ceiling near 80 ants
- Hard fail: queen death, or zero ants

---

## 2. Architecture

### 2.1 The boundary

The single most important structural rule. `sim/` is pure logic; `game/` is presentation. The boundary is one-directional and enforced by a check that runs before every commit (§2.3).

**`sim/` may not reference:** `Node`, any scene type, `get_node`, `$`, `_process`, `_physics_process`, signals connected to nodes, or anything under `game/`.

**`sim/` may use:** `RefCounted`, `Resource` (data only), arrays, dictionaries, `Vector2i`, `Vector2`, and other `sim/` classes.

**Communication is one-directional.** When the simulation needs to report something, it appends to an event list. The presentation layer drains that list each frame. The simulation never calls into presentation, never emits to it, never holds a reference to it.

```gdscript
# sim/sim_event.gd
# Events are plain data. The simulation appends; presentation drains and clears.
# This is the ONLY channel from sim to game. Nothing else crosses the boundary.
class_name SimEvent
extends RefCounted

enum Type {
    ANT_BORN,
    ANT_DIED,
    LARVA_MATURED,
    LARVA_DIED,
    FOOD_DEPOSITED,
    TILE_DUG,
    TILE_COLLAPSED,
    WORM_SPAWNED,
    WORM_DIED,
    POSSESSED_ANT_DIED,
}

var type: Type
var scene_id: int      # which scene this happened in — NEST or SURFACE
var position: Vector2  # tile-space position, for presentation to place effects
var subject_id: int    # ant / larva / worm id, where applicable
```

### 2.2 Why this matters

- The colony simulation becomes unit-testable without a running game.
- The sim can be run headless at high speed to find death spirals overnight.
- The entire visual layer can be rewritten without touching game logic. This will happen — the first art will be placeholder shapes.
- Determinism becomes achievable, so bugs reproduce.

### 2.3 Enforcement

A check script greps `sim/` for forbidden tokens and fails on any hit. It runs before every commit (§13). The rule is silent damage otherwise — the day it breaks is the day headless testing stops working, and by then it's expensive.

### 2.4 Units

**The simulation knows nothing about pixels.** All sim positions are in *tile units*. A tile is 1.0 × 1.0. An ant at `Vector2(12.5, 30.0)` is halfway across tile column 12, on row 30.

The presentation layer owns the tile→pixel mapping via `TILE_RENDER_SIZE` in presentation config. The confirmed 16px tile size is a **presentation default**, not a simulation constant.

Design resolution is 1920×1080 with `canvas_items` stretch. At default gameplay zoom roughly 30–40 tiles are visible across the screen, and an ant reads at approximately 2mm on the OnePlus 12 in landscape — the readability floor established in Q80. If on-device testing says that's too small, the fix is zoom, not a re-authoring of assets. This is the main reason for vector art.

### 2.5 Directory layout

```
res://
  sim/                      # Pure logic. No Godot nodes. Unit tested.
    colony.gd               #   Brood, food pool, birth timer, caste ratio
    ant.gd                  #   Ant data + per-tick behaviour
    worm.gd                 #   Worm data + per-tick behaviour
    terrain.gd              #   Tile grid, dig_progress, solidity queries
    pheromone_field.gd      #   Two-channel scent grid: lay, diffuse, decay, sample
    distance_field.gd       #   Flood-fill from nest entrance, rebuilt on terrain change
    spatial_index.gd        #   Neighbour queries behind a swappable implementation
    movement.gd             #   Surface adhesion and gradient following
    scene_sim.gd            #   One simulated space (nest or surface)
    world.gd                #   Owns both scene_sims, the entrance links, the tick loop
    sim_event.gd            #   Event data types
    rng.gd                  #   The single seeded RNG
  sim_tests/                # GUT tests. Target sim/ ONLY.
  game/                     # Presentation. Nodes, scenes, rendering, input.
    nest_view/
    surface_view/
    ant_renderer.gd
    scent_overlay.gd
    camera_controller.gd
    input/
    hud/
  data/                     # JSON tuning config. Hot-reloadable.
    tuning.json
  tools/                    # Debug overlay, spawner, time controls, scenario loader
  assets/
```

### 2.6 Project settings

Set once, during pipeline setup. Changing any of these later is expensive, so they are fixed:

| Setting | Value | Why |
|---|---|---|
| Display → Window → Size | 1920 × 1080 | Design resolution for vector art |
| Display → Window → Stretch → Mode | `canvas_items` | Scales with the screen rather than rendering at native 3168×1440 |
| Display → Window → Stretch → Aspect | `expand` | Height locked to 1080, width grows to fit the phone's wider aspect (~2376 on the OnePlus 12) |
| Display → Window → Handheld → Orientation | `landscape` | |
| Rendering → Renderer → Rendering Method | `gl_compatibility`, **including the mobile override** | Widest Android support, lighter on battery, and all a 2D vector game needs |
| Physics → Common → Physics Ticks per Second | 20 | Drives the fixed sim tick (§3.1) |
| Application → Run → Main Scene | `res://main.tscn` as a **path**, not a `uid://` | Path references survive cache rebuilds |
| Android export → Architectures | `arm64-v8a` | The OnePlus 12's ABI |

### 2.7 Godot file conventions

- **Scenes are mounting points.** One root node plus a script; every other node is created in code. `.tscn` files merge badly, are easy to corrupt, and cannot be meaningfully authored by Claude Code.
- **Commit `.uid` files.** Ignore `.godot/` and `android/`.
- **Stale UID caches break Android silently.** After deleting or renaming a scene or script, delete `.godot/` (and `android/build/`) before the next Android export. Desktop runs from source with a live cache and never notices; the exported build carries the stale ID and draws nothing.

---

## 3. Simulation core

### 3.1 Tick

- **Fixed 20 Hz**, decoupled from render framerate.
- Rendering interpolates between the previous and current tick state.
- Framerate affects visual smoothness only, never simulation outcome. Target 60 fps, verify playable at 30.
- **Both scenes tick every tick**, regardless of which one the player is looking at. The colony is fully autonomous and does not pause when unobserved.
- **Driver:** a node in `game/` calls `world.tick()` from `_physics_process`, with Physics Ticks per Second set to 20 (§2.6). Godot handles the fixed-timestep accumulator, and the driver sits on the presentation side of the boundary, so `sim/` still knows nothing about Godot.

### 3.2 Determinism

Given the same seed and the same input sequence, the simulation produces an identical result. Non-negotiable, and near-free if built in from the start.

Requirements:

- **One seeded RNG**, owned by `sim/rng.gd`. Never global `randi()` / `randf()`. Never any RNG in `game/` that can affect sim state.
- **Fixed timestep.** The simulation advances in whole ticks and never by a variable delta.
- **Stable iteration order.** Iterate arrays, never dictionaries or sets, anywhere order affects outcome.
- **Seed is displayed on screen** in debug builds and settable via the debug overlay.

A bug report becomes `seed 8471, tick 3300` rather than an anecdote. A full run replay is a seed plus an input log — a few kilobytes.

### 3.3 Tick order

Fixed, and documented because changing it changes behaviour:

1. Decay and diffuse both pheromone fields, in both scenes
2. Transfer pheromone across entrance links
3. Update terrain (`dig_progress` accumulation, collapse resolution)
4. Rebuild distance field if terrain changed this tick
5. Update worms
6. Update ants (arrays iterated in stable id order)
7. Update colony (birth timer, food consumption, larva maturation and starvation)
8. Check fail conditions
9. Emit accumulated events

---

## 4. Terrain

### 4.1 Structure

- Tile grid, 150 × 80 tiles for the nest scene. Configurable.
- Each tile: `material` enum, `dig_progress` float 0.0–1.0.
- Materials: `SOIL` (diggable), `ROCK` (undiggable), `OPEN` (air), `SPOIL_PILE` (open, but contains hauled dirt awaiting removal).

### 4.2 Digging

Digging is gradual, not instantaneous. A digging ant accumulates `dig_progress` on the target tile; at 1.0 the tile becomes `OPEN` and drops a spoil pile.

**Dig time scales with depth.** Deeper soil is denser:

```
dig_time = dig_time_base * (1.0 + depth * dig_depth_multiplier)
```

This is the bedrock mechanism. There is no hard floor — digging simply becomes uneconomic. Soft boundary, no new systems, and it reads as bedrock without being a wall.

### 4.3 Spoil

Every dug tile produces spoil. Spoil must physically leave the nest.

**The player never hauls spoil.** Workers do, autonomously, in the background. The player digs; a spoil pile appears; workers carry it to the surface over time. This gives the full visual — dirt piles by the entrance, ants carrying grains — with none of the labour, and it gives idle workers something visibly useful to do.

Spoil piles do not block movement. They are a work queue with a visual.

### 4.4 Who digs where

- **The player pioneers.** Possessed workers dig wherever they stand.
- **Workers widen and maintain** passages the player has opened.
- **Workers also dig in response to brood-space pressure**: when there is nowhere to place a new larva, a worker begins excavating outward from the nearest chamber.

This is self-regulating and needs no marking UI. The nest shape ends up recording the colony's growth history, which is free storytelling.

There is **no designation system in v1.** Tap-to-mark digging is deferred to v2 — it is a second control paradigm that would partly replace possession as the way the player directs the colony, and it needs its own milestone.

### 4.5 Chambers

A chamber is an open region of at least `chamber_min_tiles` contiguous open tiles. Chambers are detected, not authored — the sim tags open regions by size each time terrain changes.

Chamber types are assigned by contents and proximity, not by player designation:
- **Nursery** — contains larvae
- **Granary** — contains deposited food
- **Queen chamber** — contains the queen

### 4.6 Collapse

The player may deliberately collapse a tunnel. This is the worker's only defensive verb with teeth: seal a passage behind you and the worm must take another route.

Collapse is player-triggered only in v1. No environmental or spontaneous collapse.

### 4.7 Generation

Procedurally generated from a seed, with a small pre-dug starting nest: queen chamber, one nursery with 3 larvae, a small food store, ~8 ants, and a single tunnel to the surface.

Dirt contains `ROCK` formations and natural air pockets. Nothing else in v1 — no roots, no clay layers, no buried food.

Note: air pockets create open regions disconnected from the nest. The distance field must treat unreachable open tiles as having no gradient rather than infinite distance.

---

## 5. Pheromone system

The signature system. Everything about the colony's behaviour flows through it.

### 5.1 Structure

- **Two channels: `FORAGE` and `ALARM`.** No others in v1.
- One cell per terrain tile, per channel, per scene.
- Float value per cell.

### 5.2 Laying

| Source | Strength | When |
|---|---|---|
| Possessed ant, forage | `player_trail_strength` | Continuously while carrying food toward the nest |
| AI worker, forage | `ai_trail_strength` | On a successful return trip with food |
| Possessed ant, alarm | `player_alarm_strength` | Manual button; brief automatic burst on taking damage |
| Any ant, alarm | `death_alarm_burst` | On death, at the death position |

The ratio matters: `player_trail_strength` is roughly 4–5× `ai_trail_strength`. **The player is the scout who establishes a road; the colony reinforces and maintains it.** Without AI trail-laying the player becomes a manual logistics operator; without the strength gap possession becomes decorative.

### 5.3 Diffusion and decay

Trail pheromone is a volatile chemical. It evaporates into the air and forms a scent cloud wider than the ant's actual path — ants find trails by walking into that cloud.

Diffusion is therefore **mechanically required**, not a flourish. Gradient-following cannot work without it: an ant one cell off a zero-width trail reads zero in every direction and has no gradient at all.

- **Diffusion:** each tick, each cell distributes `diffusion_rate` of its value to its four neighbours. Effective spread ~1–2 cells.
- **Decay:** exponential, per channel. `FORAGE` half-life ~3 minutes; `ALARM` half-life ~25 seconds.

The differing decay rates are where the interesting behaviour lives. Forage trails become infrastructure. Alarm stays an emergency.

### 5.4 Cross-scene propagation

The nest and surface are separate scenes with separate coordinate spaces and separate fields. They are linked at **entrances**.

Each entrance is a linked pair of cells — one in each scene's field. Each tick, a fraction (`entrance_transfer_rate`) of each channel's value transfers between the paired cells in both directions.

This is cheap, and it earns the off-screen awareness signal for free: **the entrance glow is alarm scent physically leaking out of the hole**, not a UI indicator. Glow intensity is simply the alarm value at the surface-side entrance cell.

### 5.5 Visualisation

- **Faint in-world wisps at all times**, in both scenes.
- **A full heatmap on a toggle button**, available in both scenes.

### 5.6 Cost

Laying scent is free. No resource, no cooldown, nothing to explain to the player.

---

## 6. Movement

### 6.1 Surface adhesion

Ants adhere absolutely to surfaces. There is no gravity, no falling, no jumping. An ant walks on floors, walls, and ceilings identically.

This removes an entire class of physics bugs and touch-input problems, and it is biologically correct.

An ant's state is:
- `position: Vector2` — continuous, in tile units, constrained to lie on the boundary of the solid tile set
- `normal: Vector2` — the outward normal of the surface it is standing on
- `facing: float` — direction along the surface tangent

Movement steps along the surface tangent. At a **convex** corner the ant wraps around the outside; at a **concave** corner it turns into the join. Both cases interpolate the normal over `corner_ease` seconds so it reads as a curve rather than a snap.

If a terrain change removes the surface an ant is standing on, it re-attaches to the nearest adjacent solid tile.

### 6.2 No physics bodies

Ants are data in a fixed-size array, moved kinematically over the tile grid. No `CharacterBody2D`, no `RigidBody2D`.

Collision is an array lookup ("is the target tile solid?"). Adhesion is an array lookup ("which neighbouring tile is solid, and what is its normal?"). Rendering reads from the array.

Godot's physics assumes gravity and a floor; absolute adhesion would mean fighting it on its own turf. Custom is not only faster here, it is simpler.

### 6.3 Navigation

**No pathfinding for foraging.** Ants read the pheromone field in their neighbourhood and step toward the strongest cell, with noise. O(1) per ant, no path state to invalidate, and terrain changes handle themselves because the field flows around new geometry.

**Homing uses a distance field.** A single flood-fill outward from the nest entrance gives every ant "downhill is home" for free, with no per-ant pathfinding. Recomputed when terrain changes.

A\* is not implemented in v1. If a case appears that genuinely needs it, that is a decision to bring back, not to solve inline.

### 6.4 Carrying

- One item at a time. Food, or a larva. Corpses deferred.
- `carry_speed_mult` ≈ 0.55, plus a turn-rate penalty.
- Items may be dropped anywhere. Dropping a larva in a tunnel to deal with something and coming back for it is intended texture.

### 6.5 Spatial queries

All neighbour queries go through one interface. Implementation starts as a uniform grid reusing the tile grid, and is swappable.

```gdscript
# sim/spatial_index.gd
# Everything needing neighbour queries goes through this and nothing else.
# Implementation is swappable — uniform grid now, quadtree later if profiling
# ever justifies it. No caller should know or care which is behind it.
func get_ants_near(pos: Vector2, radius: float) -> Array
```

---

## 7. Ants

### 7.1 Data

Every ant has an id, age, caste, current behaviour state, carried item, position, normal, and facing. Identity is cheap — 80 ants with full records is a few kilobytes.

There is **no per-ant inspector UI, no visible names, no stats screen** in v1. The data exists; the interface does not.

Ants do not die of old age in v1.

### 7.2 Castes

Assigned at birth from the current ratio. Not switchable at runtime.

**Worker**
- Digs, widens, hauls spoil
- Carries food and larvae
- Lays weak forage trail on successful return
- Cannot fight. Ever.
- **Forage scent:** follows it uphill
- **Alarm scent:** moves toward it, then grabs the nearest larva and carries it *away* from the source

**Soldier**
- Fights
- Cannot carry brood
- **Forage scent:** ignores it
- **Alarm scent:** moves toward the source and attacks what is there

**Queen**
- Not an ant agent. A static object in the queen chamber.
- Lays eggs on a timer, gated by food.
- Cannot be possessed — she does nothing but lay.
- Her death is a hard fail condition.

The worker/soldier birth ratio is **player-adjustable at runtime** via a single slider. Default 4:1.

### 7.3 Behaviour states

Minimal set for v1:

`IDLE` · `FORAGING` · `RETURNING` · `DIGGING` · `HAULING_SPOIL` · `CARRYING_BROOD` · `FLEEING` · `ATTACKING`

Idle ants wander the nest and drift toward the strongest scent. This is not filler — it is what makes the colony look alive and what makes trail formation visible.

### 7.4 Possession

- The player possesses **workers only** in v1. Soldier possession is deferred.
- **No voluntary switching.** The player cannot body-hop to another ant at will.
- On death: **instant swap to the nearest ant**, no delay. Nearby ants emit an alarm burst — grieving as flavour, not as a control penalty.
- The possessed ant **reverts to normal AI** when the player is in the other scene.
- Possession is **retained across scene transitions**. The ant walks through the entrance and appears on the other side, still possessed.
- Visual marker: a reserved hue used by nothing else in the game, plus a subtle outline. The rule is that the player must find themselves on a busy screen in under half a second.

---

## 8. Colony economy

### 8.1 Food

- **Discrete on the map** — visible crumbs that can be picked up and counted.
- **Aggregated into a pool once deposited** in the granary chamber.
- The granary is a real location with real contents. The worm can raid it. A location worth defending is worth more than a number.
- Surface food respawns over time.

### 8.2 Brood

- Two stages only: **larva → adult.** No eggs, no pupae.
- Larvae are immobile, fragile, and the entire point of the colony.
- Larvae draw from the food pool, but only while in a chamber connected to the nest. Nurse ants physically feeding larvae is deferred.
- Maturation: `larva_maturation_time` ≈ 90s.
- Starvation: larvae die after roughly 2× maturation time without food.

### 8.3 Birth

Timer plus food gate. The queen lays on `egg_interval`; if the food pool is below `food_per_larva`, the timer stalls rather than resetting.

New larvae need chamber space. If there is none, birth waits and a worker starts digging — chamber space is a **lag** on growth, not a ceiling.

### 8.4 Population ceiling

Not enforced by a hard number. The ceiling emerges from food yield and map size, landing near 80 ants on a 150×80 map.

No cap displayed in the UI, no artificial wall. The colony simply cannot feed more than the map supports.

### 8.5 Fail conditions

- Queen dies, or
- Zero ants remain

---

## 9. The worm

One enemy type in v1. One.

- **Arrival:** burrows in from a map edge, visible on approach so the player gets warning.
- **Targeting:** eats anything — larvae, ants, stored food — but target scoring is **weighted toward brood and the granary.** Without that weighting it mostly eats whichever worker wandered closest, which is the least alarming possible outcome.
- **Killable**, but expensive: roughly 4–6 soldiers, losing 1–2.
- **Retreats** below 20% health, and returns later.
- **Kills a possessed ant instantly.** Auto-swap to the nearest ant.
- Uses existing tunnels and entrances. Worms do not dig their own in v1.

---

## 10. Scenes

### 10.1 Structure

Two scenes with separate coordinate spaces:

- **Nest** — side-view cross-section. Tile grid, digging, chambers, brood, queen, granary.
- **Surface** — top-down. Foraging, food sources, worm arrival.

Both are simulated every tick regardless of which is displayed.

### 10.2 Transition

The player walks their ant into an entrance. No button, no menu — the entrance is a real place.

Possession is retained. The same ant emerges on the other side.

### 10.3 Entrances

- One at start. The player can dig upward and break the surface to create more.
- More entrances mean more foraging throughput and more ways in for the worm. That trade is the point.
- Each entrance links a pheromone cell pair between the two fields (§5.4).

### 10.4 Off-screen awareness

While on the surface the player cannot see the nest. The signal is **entrance glow** — alarm scent leaking out of the hole, intensity proportional to the alarm value at the surface-side entrance cell.

That is the whole mechanism. No status bar, no popup, no edge indicator in v1. A messenger ant that physically runs out to find you is the planned v2 upgrade.

---

## 11. Input and presentation

### 11.1 Orientation and controls

- **Landscape**, one thumb.
- Movement: **drag toward a direction.** Absolute adhesion handles all vertical traversal, so there is no jump and no precision-timing input.
- Dig: contextual action while stationary against soil.
- Pick up / drop: contextual.
- Alarm: a dedicated button. Manual, because laying alarm should be a decision the player can get wrong.
- Collapse tunnel: contextual, with confirmation.
- Scent heatmap: toggle.
- Pause: shipped. Fast-forward is debug-only in v1.
- Caste ratio: one slider, in a pull-out panel.

**This is already a lot of buttons for one thumb.** v0.1 ships movement and dig only. The full set is a design problem to be solved at v0.4 with a real device in hand, not specified in advance.

### 11.2 HUD

Permanently visible: food count, ant count, larva count, carried-item icon. Nothing else.

**Numbers only, no words.** No text anywhere in v1.

Food running low is communicated by the food number plus larvae visibly weakening.

### 11.3 Art

- **Vector**, 1920×1080 design resolution, `canvas_items` stretch.
- **Silhouette and atmosphere.** Ants as near-black shapes. This hides limited animation skill, is thematically correct underground, and is far cheaper than readable detail.
- Palette: 12–16 colours in two families. Underground — warm dark browns, near-black, one amber for food and light. Surface — desaturated greens, pale sky, harsher light. One hue reserved exclusively for the possessed ant, one for alarm.
- **No walk cycles.** Rigid sprite rotated to the surface normal, plus a two-frame leg flicker and a body bob scaled to movement speed. At 12 pixels long nobody can see a walk cycle anyway.
- Placeholder strategy for the first three months: **coloured shapes.** Art never blocks systems work.

### 11.4 Audio

None in v1.

---

## 12. Debug tooling

Built **before** content, not after. This is roughly two evenings of work and it pays back for the life of the project.

- **Live tuning overlay** — sliders bound to every feel and balance parameter, adjustable while the game runs
- **Time controls** — pause, 0.25×, 4×
- **Spawner** — drop an ant, larva, worm, or food anywhere
- **Seed field** — settable, and the current seed always displayed
- **Scenario loader** — one-click states such as "brood chamber under attack, 3 workers, 40% food"

Tools live in-build behind a debug flag, on by default until ship.

The reason this comes first: game design demands a tuning loop measured in seconds. If every iteration requires a code change, tuning silently stops happening and the game feels like a first draft forever.

---

## 13. Testing

GUT, from day one, targeting `sim/` **only**. Presentation is not tested.

Representative tests:

- A colony with 10 workers and 100 food survives 5000 ticks
- The pheromone field conserves total mass under diffusion alone
- Forage scent decays to below 1% within the expected window
- A worm reaching the nursery with no soldiers present kills larvae
- Terrain mutation triggers exactly one distance-field rebuild per tick, not one per tile
- The same seed produces byte-identical colony state after 10,000 ticks
- An ant on a surface that is dug away re-attaches rather than falling out of the world

For now, checks run **locally**, not on a hosted CI runner: one script, `tools/check.sh`, runs the `sim/` boundary grep and the headless GUT suite, and is wired into a git pre-commit hook so it can't be forgotten. Moving the same script onto a self-hosted runner (tests on push, APK build on tag) is a later step and needs no change to the script itself.

---

## 14. Milestones

| Rung | Contains | Question it answers |
|---|---|---|
| **v0.1** | One ant, hand-made tunnel, crawl + dig, tuning overlay, running on the phone | Does surface-crawling feel good under a thumb? |
| **v0.2** | Headless colony sim: 20 ants, food, larvae, hunger, GUT tests | Is there an economy here, or does it always spiral? |
| **v0.3** | Pheromone field, gradient-following, trails visible | Is indirect control satisfying or frustrating? |
| **v0.4** | Possession, both scenes, transition, sim running underneath, full control set | Is this one game or two? |
| **v0.5** | Procgen nest, surface map, one worm, larvae at risk | **The build you show your friend.** |

Each rung is independently abandonable. If the answer to a rung's question is bad, that is a successful outcome — it was cheap to find out.

v0.4 is the heaviest rung because Package B put a second scene, a second camera, and a transition in it.

### 14.1 The v0.5 target — first five minutes

| Time | Beat |
|---|---|
| 0:00 | Wake in a small pre-dug nest. Queen, ~8 ants, 3 larvae, a little food. |
| 0:30 | Crawl. Discover surfaces work in every orientation. |
| 1:00 | Find the entrance, transition, see the surface for the first time. |
| 1:30 | Find a crumb. Pick it up. Notice you're slower. |
| 2:30 | Carry it home. Watch the trail you laid start pulling other ants outward. |
| 3:30 | A larva matures. Population ticks up. |
| 4:00 | Food number starts dropping — more mouths. |
| 4:30 | A worm burrows in at the map edge. |
| 5:00 | It reaches the nest before you do. |

---

## 15. v0.1 — immediately actionable

Ordered. Each item should be a separate commit or small series.

1. **Project setup.** `4.7.2.stable` pinned in README. Git repo, `LICENSE: TBD`. Directory skeleton per §2.5. `.gitignore` per §2.7. GUT installed under `addons/`. `CLAUDE.md`, `NOT_IN_V1.md`, `data/tuning.json` already in place.
2. ✅ **Android export pipeline.** Done. JDK 17, command-line SDK, debug keystore, `arm64-v8a` preset, Compatibility renderer, one-click deploy to the OnePlus 12. `main.tscn` + `main.gd` draw an orange square that follows touch — this is the deploy sanity check, kept until items 9–11 replace it. Baseline tagged `v0.0-pipeline`.
3. **Local check script.** `tools/check.sh`: the `sim/` boundary grep, and a headless GUT run that passes with zero tests. Installed as a git pre-commit hook. Hosted CI is deferred.
4. **`sim/terrain.gd`.** Tile grid, materials, `dig_progress`, solidity queries. Hand-authored test map loaded from JSON.
5. **`sim/movement.gd`.** Surface adhesion: position on the solid-set boundary, normal, facing, tangent stepping, convex and concave corner handling with `corner_ease` interpolation.
6. **`sim/ant.gd`.** Minimal: one ant, position, normal, facing, movement intent, dig intent.
7. **`sim/world.gd`.** The 20 Hz fixed tick loop, seeded RNG, event list.
8. **`sim_tests/`.** First real tests: an ant traverses a convex corner without leaving the surface; an ant on a dug-away tile re-attaches; the tick is deterministic across two runs with the same seed.
9. **`game/` tile renderer.** Tiles drawn from terrain state. Placeholder colours.
10. **`game/` ant renderer.** Rigid shape rotated to normal, interpolated between ticks.
11. **`game/input/`.** Drag-toward-direction → movement intent. Contextual dig.
12. **`tools/` tuning overlay.** Sliders bound to `crawl_speed`, `turn_rate`, `surface_stick_force`, `corner_ease`, `dig_time_base`. Live, on device.
13. **Deploy and play.** Spend at least two days doing nothing but moving sliders with your thumb.

**The question v0.1 answers is not "does the code work."** It is *does crawling along a tunnel ceiling with one thumb feel like being an ant.* If the answer is no, that is worth knowing after two weeks rather than after six months.

---

## 16. Assumptions I have filled in

Where the questionnaires did not settle something, I have specified a default rather than leaving a hole. Correct any of these and I will revise:

- **Behaviour state list** (§7.3) — never explicitly enumerated. This is the minimal set the specified behaviours require.
- **Chamber detection by contiguous open region** (§4.5) — Round 1 said rooms are functional entities but not how they come to exist. Detection rather than designation follows from having no designation system.
- **Food respawn on the surface** (§8.1) — Round 1 said food respawns; rate and distribution are unspecified and are in the tuning file.
- **Spoil piles do not block movement** (§4.3) — never asked. Blocking would create pathing problems for no gain.
- **Air pockets and the distance field** (§4.7) — the consequence of Q125 was never worked through. Unreachable open tiles need explicit handling.
- **All numeric starting values** — every number in `data/tuning.json` is a guess calibrated to the constraints given (90s maturation, ~80 ant ceiling, 20-minute sessions). v0.2 exists to find out which are wrong.
- **`corner_ease` and the adhesion feel parameters** — invented, because they cannot be reasoned about, only felt.

---

## 17. Open for v2, deliberately

Recorded so they are not forgotten, and not built:

- Satellite colonies via alates — the v2 headline
- Designation-based digging — the other v2 headline
- Messenger ants replacing entrance glow
- Soldier possession
- Follower squad
- Enemy tunnelling
- Day/night, weather, seasons
- Rival colonies
- Audio
- Corpses as food
- Nurse ants physically feeding larvae
- Spoil as a player-facing economy
