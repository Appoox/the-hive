# The Hive — Working Agreement

Read `DESIGN.md` before any task. Read `NOT_IN_V1.md` before adding anything.

---

## Decision protocol

Assume nothing. Ask me and explain. I will decide.

Batch questions at natural checkpoints rather than interrupting mid-task.
State the options and your recommendation for each. Implement nothing until
told which option.

---

## Environment — fixed, do not change

- **Godot 4.7.2.stable**, standard build (not .NET). Do not suggest upgrading
  mid-milestone.
- **GDScript only.** No C#, no GDExtension in v1.
- **Renderer: Compatibility**, on both the desktop and the mobile override.
- **Test device: OnePlus 12**, landscape, deployed via Godot's one-click deploy.
- Project settings in `DESIGN.md` §2.6 are already set. Do not change them
  without asking.

---

## Hard architectural rules

1. **Nothing under `sim/` may reference a Godot `Node`,** a scene, `get_node`,
   `$`, `_process`, `_physics_process`, a signal connected to a node, or
   anything under `game/`. `sim/` may use `RefCounted`, arrays, dictionaries,
   `Vector2`, `Vector2i`, and other `sim/` classes. Nothing else.

2. **Communication is one-directional.** When `sim/` needs to report something,
   it appends a `SimEvent` to the event list. `game/` drains that list each
   frame. The simulation never calls into presentation, never emits to it, and
   never holds a reference to it.

3. **The simulation is deterministic.** One seeded RNG, owned by `sim/rng.gd`.
   Never global `randi()` or `randf()`. Never RNG in `game/` that can affect
   sim state. Fixed 20 Hz timestep. Iterate arrays, never dictionaries,
   wherever order affects outcome.

4. **The simulation knows nothing about pixels.** All sim positions are in tile
   units where a tile is 1.0 x 1.0. The tile-to-pixel mapping lives in `game/`.

5. **Every value affecting feel or balance lives in `data/tuning.json`** or an
   `@export`. No magic numbers in logic. If you need a new tunable, add it to
   the JSON and the debug overlay in the same change.

6. **Ants are data in a fixed-size array,** moved kinematically over the tile
   grid. No `CharacterBody2D`, no `RigidBody2D`, no physics bodies of any kind.

7. **All neighbour queries go through `sim/spatial_index.gd`.** No caller may
   know which implementation is behind it.

---

## Godot file rules

Scene and resource files are the fragile part of this project. These rules
exist because each of them has already caused a real failure.

1. **Keep `.tscn` files nearly empty.** One root node per scene, with a script
   attached. Every other node is created in code in `_ready()`. Scenes are
   mounting points, not content. Do not hand-write node trees into `.tscn`
   files.

2. **Never hand-edit `.tscn`, `.tres`, or `project.godot`** without asking
   first. The Godot editor may be open, and it rewrites files it has loaded —
   your changes can be silently overwritten, or can corrupt its state.

3. **Commit `.uid` files.** Never delete one on its own. They are how resource
   references survive file moves.

4. **Reference scenes and resources by `res://` path, not `uid://`,** in
   `project.godot` and anywhere else you write a reference by hand.

5. **After deleting or renaming any scene or script, say so explicitly,** so I
   can clear `.godot/` before the next Android export. A stale UID cache
   produces an Android build that runs but draws nothing, with no error beyond
   `Unrecognized UID` in the remote debugger.

6. **Leave `main.gd` and `main.tscn` alone.** They are the deploy sanity check
   — an orange square that follows touch. They are replaced during §15 items
   9–11, not before, and only when I say so.

---

## Vocabulary — use these exact terms

Colony, Chamber, Tunnel, Brood, Larva, Forager, Soldier, Queen, Trail, Scent,
Forage, Alarm, Surface, Nest, Worm, Granary, Nursery, Spoil, Entrance.

**Never:** Unit, Entity, Player, Enemy, Building, Resource, Mob, NPC, Agent,
Character, Actor, Item.

Naming is load-bearing here. Generic names pull generated code toward generic
RTS assumptions — health bars, damage numbers, selection boxes. Domain names
keep it in this game.

---

## Code style

- Comment every non-obvious block. Explain **why**, not what.
- Never delete an existing comment.
- Prefer explicit over clever. This codebase is read far more than written.
- Tests live in `sim_tests/` and target `sim/` only. Never test presentation.
- Small commits. "It felt better two commits ago" is a real and frequent
  sentence in game development.

---

## Branches

- The default branch is **`master`**, not `main`. `master` is always runnable.
- Prototypes go on `spike/<question>` branches, named after the question rather
  than the feature — `spike/does-crawling-feel-good`, not `spike/movement-v2`.
- Never merge a spike wholesale. Cherry-pick the answer or delete the branch.
  The point of a spike is that its code is disposable.
- Tag milestones: `v0.1-crawl`, `v0.2-colony`, and so on.
- `v0.0-pipeline` is the known-good deploy baseline. If an Android build
  breaks, check that tag out first to separate code problems from toolchain
  problems.

---

## Scope

Consult `NOT_IN_V1.md` before adding anything. If a request would build
something on that list, say so instead of building it.

Design is mostly subtraction. I am the one who says no; you will not
volunteer it. So when a request implies scope beyond the current milestone,
name the implication before starting.

---

## Current milestone

<!-- Update this at every rung. Refuse work outside it. -->

**v0.1** — One ant, hand-made tunnel, crawl and dig, tuning overlay, running
on the OnePlus 12.

The question this rung answers: *does crawling along a tunnel ceiling with one
thumb feel like being an ant?*

Anything that does not serve answering that question is out of scope for now.

**Progress against `DESIGN.md` §15:**

- [x] Item 2 — Android export pipeline. Touch reaches the engine on device.
- [ ] Item 1 — Project setup (skeleton, README, `.gitignore`, GUT)
- [ ] Item 3 — Local check script (`tools/check.sh` + pre-commit hook)
- [ ] Items 4–13
