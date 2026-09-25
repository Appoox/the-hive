# The Hive

A game about an ant colony, in which the player inhabits a single worker ant.
Android, landscape, developed desktop-first on Linux.

Read `DESIGN.md` for the specification, `NOT_IN_V1.md` for what is deferred,
and `CLAUDE.md` for the working agreement.

## Pinned environment

| | |
|---|---|
| Engine | **Godot 4.7.2.stable**, standard build (not .NET) |
| Language | GDScript only |
| Renderer | Compatibility, on desktop and the mobile override |
| Tests | GUT 9.7.1, vendored in `addons/gut/` |
| Test device | OnePlus 12, landscape, Godot one-click deploy |

Do not upgrade Godot mid-milestone. `tools/check.sh` refuses any other version.

## Local check

`tools/check.sh` runs before every commit. It fails if:

- anything under `sim/` references presentation: `Node`, `get_node`, `$`,
  `_process`, `_physics_process`, `res://game`, `PackedScene`, `SceneTree`,
  `get_tree` or `.tscn` (`#` comments are ignored); or
- the headless GUT run over `sim_tests/` fails or reports a script error.

It needs the Godot 4.7.2 binary, through `$GODOT` or as `godot` on `PATH`:

```sh
export GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64
tools/check.sh
```

Turn on the pre-commit hook once per clone:

```sh
git config core.hooksPath tools/git-hooks
```

The check starts a headless Godot import before running the tests, which
rebuilds caches under `.godot/` but changes no tracked file. A cold run takes
about ten seconds. Hosted CI is deferred; the same script will move onto a
runner unchanged.

## After deleting or renaming a scene or script

Delete `.godot/` and `android/build/` before the next Android export. A stale
UID cache produces an Android build that runs but draws nothing, with no
error beyond `Unrecognized UID` in the remote debugger.

## License

TBD
