#!/usr/bin/env bash
# tools/check.sh — the local check (DESIGN.md §2.3, §13, §15 item 3).
#
# Two checks, in order:
#   1. The sim/ boundary grep. sim/ must never reach into presentation
#      (DESIGN.md §2.1, CLAUDE.md hard rule 1).
#   2. The GUT suite in sim_tests/, run headless on the pinned Godot.
#
# Runs before every commit through tools/git-hooks/pre-commit, and can be
# run by hand from anywhere in the repo. Exits non-zero if either check
# fails. It assumes nothing about the machine beyond bash, awk, find and a
# Godot binary, so it can move onto a self-hosted runner unchanged.
#
# Godot is found through $GODOT, falling back to `godot` on PATH.

set -euo pipefail

# The one Godot version this project is built with (CLAUDE.md, Environment).
# Standard build only: the .NET ("mono") build reports the same number, so it
# is rejected separately below.
readonly PINNED_GODOT_VERSION="4.7.2.stable"

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SIM_DIR="sim"
readonly TEST_DIR="sim_tests"

cd "$ROOT"

fail() {
	echo "check.sh: FAIL — $*" >&2
	exit 1
}

# ---------------------------------------------------------------------------
# 1. sim/ boundary grep
# ---------------------------------------------------------------------------
#
# Each entry is "label|regex". Regexes are POSIX ERE so they behave the same
# under gawk, mawk and BSD awk — none of those agree on \b, so identifier
# boundaries are spelled out as [^A-Za-z0-9_]. Matching is case-sensitive:
# prose that says "node" in lower case is fine.
readonly NOT_IDENT='[^A-Za-z0-9_]'
readonly FORBIDDEN=(
	# Any identifier starting with Node: Node, Node2D, Node3D, NodePath.
	"Node|(^|${NOT_IDENT})Node"
	# Prefix match on purpose, so get_node_or_null is caught too.
	"get_node|(^|${NOT_IDENT})get_node"
	# The $Child shorthand for get_node. Matched anywhere.
	"\$|[\$]"
	# Whole words only, so a sim function like _process_brood() is allowed.
	"_process|(^|${NOT_IDENT})_process(${NOT_IDENT}|\$)"
	"_physics_process|(^|${NOT_IDENT})_physics_process(${NOT_IDENT}|\$)"
	# Paths into presentation. These always live inside string literals,
	# which is why strings are never stripped before matching.
	"res://game|res://game"
	# The "a scene" clause of CLAUDE.md hard rule 1.
	"PackedScene|(^|${NOT_IDENT})PackedScene"
	"SceneTree|(^|${NOT_IDENT})SceneTree"
	"get_tree|(^|${NOT_IDENT})get_tree"
	".tscn|[.]tscn"
)
# Not covered, because text matching cannot see them: signals connected to
# nodes, the %UniqueName shorthand (% is also modulo and string formatting),
# and untyped variables that happen to hold a Node.

check_sim_boundary() {
	if [ ! -d "$SIM_DIR" ]; then
		fail "$SIM_DIR/ does not exist; the skeleton from DESIGN.md §2.5 is missing."
	fi

	# Patterns reach awk through the environment rather than -v, because -v
	# would interpret backslash escapes in them.
	local patterns
	patterns="$(printf '%s\n' "${FORBIDDEN[@]}")"

	# Only .gd files are scanned: sim/ is GDScript by rule, and the comment
	# stripping below understands GDScript syntax only.
	local hits
	hits="$(
		find "$SIM_DIR" -type f -name '*.gd' -print0 | sort -z |
			CHECK_PATTERNS="$patterns" xargs -0 -r awk -v sq="'" '
			BEGIN {
				count = split(ENVIRON["CHECK_PATTERNS"], entries, "\n")
				for (p = 1; p <= count; p++) {
					bar = index(entries[p], "|")
					label[p] = substr(entries[p], 1, bar - 1)
					regex[p] = substr(entries[p], bar + 1)
				}
			}

			# A new file must not inherit an unclosed string from the last one.
			FNR == 1 { quote = "" }

			{
				# Remove the # comment from this line so a why-comment such as
				# "stepped by world.gd, not _process" does not fail the check.
				# A # inside a string is not a comment, so string state is
				# tracked, including across lines for triple-quoted strings.
				code = ""
				n = length($0)
				i = 1
				while (i <= n) {
					c = substr($0, i, 1)
					if (quote != "") {
						if (c == "\\") {
							# Keep the escaped character so \" does not close the string.
							code = code substr($0, i, 2)
							i += 2
							continue
						}
						if (substr($0, i, length(quote)) == quote) {
							code = code quote
							i += length(quote)
							quote = ""
							continue
						}
						code = code c
						i++
						continue
					}
					if (c == "#") {
						break
					}
					if (c == "\"" || c == sq) {
						triple = substr($0, i, 3)
						if (triple == "\"\"\"" || triple == sq sq sq) {
							quote = triple
						} else {
							quote = c
						}
						code = code quote
						i += length(quote)
						continue
					}
					code = code c
					i++
				}
				# Single-quoted and double-quoted strings cannot span lines.
				# Resetting here stops one malformed line from hiding the rest
				# of the file from the check.
				if (quote == "\"" || quote == sq) {
					quote = ""
				}

				for (p = 1; p <= count; p++) {
					if (code ~ regex[p]) {
						printf "  %s:%d: forbidden %s%s%s: %s\n", FILENAME, FNR, sq, label[p], sq, $0
					}
				}
			}
		'
	)"

	if [ -n "$hits" ]; then
		echo "$hits" >&2
		fail "$SIM_DIR/ references presentation (DESIGN.md §2.1, CLAUDE.md hard rule 1)."
	fi
	echo "check.sh: sim/ boundary — ok"
}

# ---------------------------------------------------------------------------
# 2. Headless GUT run
# ---------------------------------------------------------------------------

find_godot() {
	local godot="${GODOT:-}"
	if [ -z "$godot" ]; then
		godot="$(command -v godot || true)"
	fi
	if [ -z "$godot" ]; then
		fail "Godot not found. Set GODOT=/path/to/Godot_v${PINNED_GODOT_VERSION%.stable}-stable_linux.x86_64 or put \`godot\` on PATH."
	fi
	if [ ! -x "$godot" ]; then
		fail "GODOT=$godot is not an executable file."
	fi

	# A missing Godot or the wrong Godot must fail, never skip: a test run
	# that silently does not happen is the failure DESIGN.md §2.3 warns about.
	local version
	version="$("$godot" --headless --version 2>/dev/null | tail -n 1)"
	case "$version" in
		*.mono.* | *.mono)
			fail "$godot is the .NET build ($version). This project uses the standard build."
			;;
		"$PINNED_GODOT_VERSION" | "$PINNED_GODOT_VERSION".*) ;;
		*)
			fail "$godot is Godot $version; this project is pinned to $PINNED_GODOT_VERSION."
			;;
	esac
	echo "$godot"
}

run_gut() {
	local godot
	godot="$(find_godot)"

	local log
	log="$(mktemp)"
	# shellcheck disable=SC2064 # expand $log now; it is local to this function
	trap "rm -f '$log'" EXIT

	# .godot/ is not committed, so a fresh clone has no global class cache and
	# GUT's own classes (GutTest and friends) do not exist yet. Importing first
	# builds that cache and keeps it current when sim/ gains a new class_name.
	# It does not modify any tracked file. Output is only shown on failure;
	# it is progress bars otherwise.
	if ! "$godot" --headless --path "$ROOT" --import >"$log" 2>&1; then
		cat "$log" >&2
		fail "headless import failed."
	fi

	# Output streams through tee so the run is visible, and is kept for the
	# marker scan below.
	set +e
	"$godot" --headless --path "$ROOT" \
		-s res://addons/gut/gut_cmdln.gd \
		-gdir="res://$TEST_DIR" \
		-ginclude_subdirs \
		-gexit 2>&1 | tee "$log"
	local gut_status="${PIPESTATUS[0]}"
	set -e

	if [ "$gut_status" -ne 0 ]; then
		fail "GUT exited with status $gut_status."
	fi

	# GUT exits 0 when a test file fails to parse: it skips the file with a
	# warning and carries on. Scan the output so a broken test file cannot
	# pass the check by being ignored.
	#
	# "[GUT ERROR]: Nothing was run." is deliberately not a marker: an empty
	# sim_tests/ must pass (DESIGN.md §15 item 3).
	#
	# If a test ever deliberately triggers a runtime script error and asserts
	# it with assert_engine_error, the SCRIPT ERROR marker will fail it and
	# needs revisiting. push_error prints "ERROR:", not "SCRIPT ERROR:", so
	# assert_push_error is unaffected.
	local markers
	local esc
	esc="$(printf '\033')"
	markers="$(sed "s/${esc}\[[0-9;]*m//g" "$log" |
		grep -E 'SCRIPT ERROR|Parse Error|does not extend GutTest' || true)"
	if [ -n "$markers" ]; then
		echo "$markers" | sed 's/^/  /' >&2
		fail "GUT output shows script errors or skipped test files (see above), although GUT exited 0."
	fi
	echo "check.sh: GUT — ok"
}

check_sim_boundary
run_gut
echo "check.sh: all checks passed"
