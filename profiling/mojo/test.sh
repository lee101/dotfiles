#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fixtures="$root/profiling/tests/fixtures"
wrapper="$root/tools/profile-md"
native_bin="$tmp/cache/dotfiles-tools/profile-md-mojo"

pass_count=0
fail_count=0
skip_count=0

pass() { pass_count=$((pass_count + 1)); }
fail() {
	fail_count=$((fail_count + 1))
	echo "FAIL: $*" >&2
}
skip() { skip_count=$((skip_count + 1)); }

assert_eq() {
	# assert_eq <expected> <actual> <label>
	if [[ "$1" == "$2" ]]; then
		pass
	else
		fail "$3: expected [$1], got [$2]"
	fi
}

assert_ne() {
	if [[ "$1" != "$2" ]]; then
		pass
	else
		fail "$3: expected value to differ from [$1]"
	fi
}

assert_contains() {
	# assert_contains <haystack-file> <literal> <label>
	if grep -qF -- "$2" "$1"; then
		pass
	else
		fail "$3: [$2] missing from $1"
	fi
}

assert_not_contains() {
	if grep -qF -- "$2" "$1"; then
		fail "$3: [$2] unexpectedly present in $1"
	else
		pass
	fi
}

assert_matches() {
	# assert_matches <haystack-file> <extended-regex> <label>
	if grep -qE -- "$2" "$1"; then
		pass
	else
		fail "$3: /$2/ did not match anything in $1"
	fi
}

# Runs the requested engine and reports its exit code, leaving stdout in $1's
# target file and any diagnostics in the sibling .err file.
run_native() {
	local out="$1"
	shift
	"$native_bin" "$@" >"$out" 2>"$out.err" || return $?
	return 0
}

run_fallback() {
	local out="$1"
	shift
	PATH="/usr/bin:/bin" XDG_CACHE_HOME="$tmp/fallback" PROFILE_MD_DISABLE_NATIVE=1 \
		"$wrapper" "$@" >"$out" 2>"$out.err" || return $?
	return 0
}

native_available=1
if ! "$root/profiling/mojo/build.sh" "$native_bin" >"$tmp/build.log" 2>&1; then
	native_available=0
	echo "note: native Mojo binary unavailable; the native half is skipped." >&2
	sed 's/^/  build: /' "$tmp/build.log" >&2 || true
fi

# A workstation commonly exports the MODULAR_HOME of a different Modular
# installation. build.sh resolves its own compiler, so it must not inherit that
# value: doing so makes every build die with "unable to locate module 'std'"
# and a cascade of bogus "unknown declaration" errors that look like a broken
# source file.
if [[ $native_available -eq 1 ]]; then
	if MODULAR_HOME=/nonexistent/modular "$root/profiling/mojo/build.sh" \
		"$tmp/poisoned-pmd" >"$tmp/build-poisoned.log" 2>&1; then
		pass
	else
		fail "build.sh inherited a foreign MODULAR_HOME and failed"
		sed 's/^/  build: /' "$tmp/build-poisoned.log" >&2 || true
	fi
	# An explicit request still wins.
	if MODULAR_HOME=/nonexistent/modular \
		MOJO_MODULAR_HOME="$root/profiling/mojo/.pixi/envs/default/share/max" \
		"$root/profiling/mojo/build.sh" "$tmp/override-pmd" >/dev/null 2>&1; then
		pass
	else
		fail "build.sh ignored an explicit MOJO_MODULAR_HOME"
	fi
fi

# ---------------------------------------------------------------------------
# Native half.
# ---------------------------------------------------------------------------
if [[ $native_available -eq 1 ]]; then
	mkdir -p "$tmp/cache/dotfiles-tools"
	XDG_CACHE_HOME="$tmp/cache" "$wrapper" \
		"$fixtures/trtexec.log" \
		--out "$tmp/report.md" --top 1 --max-chars 2000
	grep -q 'TensorRT trtexec Report' "$tmp/report.md"
	grep -q 'attention_block' "$tmp/report.md"
	if grep -q 'conv1' "$tmp/report.md"; then
		echo "native --top 1 retained more than one layer" >&2
		exit 1
	fi
	test "$(grep -c '^| `' "$tmp/report.md")" -eq 1

	# --out writes the document to the file instead of stdout.
	assert_contains "$tmp/report.md" '# TensorRT trtexec Report' 'native --out wrote the report'
	assert_eq 1 "$(grep -c '^| `' "$tmp/report.md")" 'native --out row count'

	# --help exits 0 and prints usage on stdout.
	run_native "$tmp/help.md" --help
	assert_eq 0 $? 'native --help exit code'
	assert_contains "$tmp/help.md" 'Usage: profile-md INPUT' 'native --help usage line'
	assert_not_contains "$tmp/help.md" 'Unhandled exception' 'native --help clean stdout'

	# The three "Next action" branches are mutually exclusive.
	run_native "$tmp/next_hot.md" "$fixtures/trtexec_nosummary.log"
	assert_contains "$tmp/next_hot.md" 'it is the hottest retained layer.' 'native next-action: layers'
	assert_not_contains "$tmp/next_hot.md" 'Re-run trtexec' 'native next-action: not the empty branch'

	run_native "$tmp/next_empty.md" "$fixtures/trtexec_empty.log"
	assert_contains "$tmp/next_empty.md" 'Re-run trtexec with `--dumpProfile`' 'native next-action: empty input'

	# Warnings with no per-layer timings must select the inspect branch.
	printf '[T] [TRT] Throughput: 12.00 qps\n[T] [TRT] WARNING: kernel fell back\n' \
		>"$tmp/warn_only.log"
	run_native "$tmp/next_warn.md" "$tmp/warn_only.log"
	assert_contains "$tmp/next_warn.md" 'Inspect the warning/error lines' 'native next-action: warnings only'
	assert_eq 1 "$(grep -c 'Warning/error lines: 1' "$tmp/next_warn.md")" 'native warning-only counter'

	# The native core reports diagnostics on stdout, not stderr: the Mojo
	# unhandled-exception handler owns stderr. Assert the exit code and the
	# message where it actually lands.
	assert_native_rejects() {
		# assert_native_rejects <expected-message> <args...>
		local want="$1"
		shift
		local out="$tmp/err.md"
		set +e
		"$native_bin" "$@" >"$out" 2>"$out.err"
		local rc=$?
		set -e
		if [[ $rc -eq 0 ]]; then
			fail "native error path [$*] exited 0"
			return
		fi
		pass
		assert_contains "$out" "$want" "native error path [$*] message"
	}

	assert_native_rejects 'missing input file'
	assert_native_rejects 'only one input file is accepted' \
		"$fixtures/trtexec.log" "$fixtures/trtexec_nosummary.log"
	assert_native_rejects 'unknown option: --bogus' "$fixtures/trtexec.log" --bogus
	assert_native_rejects '--out requires a path' "$fixtures/trtexec.log" --out
	assert_native_rejects '--top requires an integer' "$fixtures/trtexec.log" --top
	assert_native_rejects 'Mojo core only accepts --kind auto|trtexec' \
		"$fixtures/trtexec.log" --kind nsys
	assert_native_rejects '--top must be positive' "$fixtures/trtexec.log" --top 0
	assert_native_rejects '--max-chars must be at least 1000' \
		"$fixtures/trtexec.log" --max-chars 999

	# --max-chars 1000 and one byte above it must both succeed.
	run_native "$tmp/cap1000.md" "$fixtures/trtexec_large.log" --top 40 --max-chars 1000
	assert_eq 0 $? 'native --max-chars 1000'
	run_native "$tmp/cap1001.md" "$fixtures/trtexec_large.log" --top 40 --max-chars 1001
	assert_eq 0 $? 'native --max-chars 1001'
	assert_contains "$tmp/cap1000.md" '_Output capped by `--max-chars`._' 'native cap marker at 1000'

	# The cap must land on a line boundary and stay under the budget.
	run_native "$tmp/cap2000.md" "$fixtures/trtexec_large.log" --top 40 --max-chars 2000
	cap_bytes=$(wc -c <"$tmp/cap2000.md")
	if [[ $cap_bytes -le 2000 ]]; then
		pass
	else
		fail "native --max-chars 2000 emitted $cap_bytes bytes"
	fi
	# The cap must land on a whole row: every table line stays a complete row.
	# cap1000.md is the run that actually truncates on this fixture.
	if grep -n '^| ' "$tmp/cap1000.md" | grep -qv '|$'; then
		fail "native --max-chars 1000 truncated a table row"
	else
		pass
	fi
	# A budget the document already fits under must not invent a cap marker.
	assert_not_contains "$tmp/cap2000.md" '_Output capped by `--max-chars`._' \
		'native under-budget run has no cap marker'

	# --compact implies --top 10 --max-chars 6000 when neither is given.
	run_native "$tmp/compact.md" "$fixtures/trtexec_large.log" --compact
	assert_eq 10 "$(sed -n 's/^- Retained hotspots: //p' "$tmp/compact.md")" 'native --compact top'

	# --top above the layer count retains everything available.
	run_native "$tmp/top9999.md" "$fixtures/trtexec_nosummary.log" --top 9999
	assert_eq 5 "$(sed -n 's/^- Retained hotspots: //p' "$tmp/top9999.md")" 'native --top above layer count'
	assert_eq 5 "$(grep -c '^| `' "$tmp/top9999.md")" 'native --top above layer count rows'
	# Scanned/warning counters are derived from the fixture, not hard-coded.
	# A file that ends with a newline has exactly as many lines as it has
	# newline bytes; only an unterminated final line adds one.
	assert_scanned() {
		# assert_scanned <fixture> <report>
		local want newlines size last
		newlines=$(tr -cd '\n' <"$fixtures/$1" | wc -c)
		size=$(wc -c <"$fixtures/$1")
		# Hex, not od -c: the printable rendering of "\n" is indistinguishable
		# from the whitespace tr would otherwise strip.
		last=$(tail -c 1 "$fixtures/$1" | od -An -tx1 | tr -d ' \n')
		want=$newlines
		if [[ $size -gt 0 && $last != "0a" ]]; then
			want=$((newlines + 1))
		fi
		assert_eq "$want" \
			"$(sed -n 's/^- Scanned: \([0-9][0-9]*\) lines$/\1/p' "$2")" \
			"native scanned count for $1"
	}
	# The per-fixture reports only exist once the parity loop below has run,
	# so the remaining scanned-count checks are asserted there, not here.
	assert_scanned trtexec.log "$tmp/report.md"
	assert_scanned trtexec_nosummary.log "$tmp/next_hot.md"
	assert_scanned trtexec_empty.log "$tmp/next_empty.md"

	# Summary metrics land in the right fields.
	run_native "$tmp/summary.md" "$fixtures/trtexec.log"
	assert_contains "$tmp/summary.md" '- Throughput: 1234.56 qps' 'native throughput field'
	assert_contains "$tmp/summary.md" '- Latency mean: 0.15 ms' 'native latency mean field'
	assert_contains "$tmp/summary.md" '- Latency p90: 0.18 ms' 'native latency p90 field'
	assert_contains "$tmp/summary.md" '- Enqueue mean: 0.06 ms' 'native enqueue mean field'
	assert_contains "$tmp/summary.md" '- GPU compute mean: 0.05 ms' 'native gpu mean field'
	assert_not_contains "$tmp/summary.md" 'H2D mean' 'native absent H2D is omitted'

	# No summary header -> the explicit "not found" line.
	run_native "$tmp/nosummary.md" "$fixtures/trtexec_nosummary.log"
	assert_contains "$tmp/nosummary.md" 'No TensorRT performance summary was found.' \
		'native missing-summary branch'

	# Malformed input: junk lines are skipped, markdown-hostile names escaped.
	run_native "$tmp/malformed.md" "$fixtures/trtexec_malformed.log"
	assert_contains "$tmp/malformed.md" '| `single\|pipe` | 0.75 |' 'native escapes pipe in layer name'
	assert_contains "$tmp/malformed.md" "| \`alpha\\|beta 'gamma'\` | 0.1 |" 'native escapes pipe and backtick'
	assert_eq 8 "$(sed -n 's/^- Retained hotspots: //p' "$tmp/malformed.md")" 'native malformed layer count'
	assert_not_contains "$tmp/malformed.md" 'negative_time' 'native drops negative timings'
	assert_not_contains "$tmp/malformed.md" 'no_digits_here' 'native drops digitless timings'
	assert_not_contains "$tmp/malformed.md" 'missing_number' 'native drops digitless timings'
	assert_not_contains "$tmp/malformed.md" 'truncated_last_line' 'native drops truncated last line'
	assert_not_contains "$tmp/malformed.md" 'head_fc' 'native drops [TRT] with no ms unit'

	# Warning counting is case-insensitive and only counts [TRT] lines.
	# The warnings fixture's own report is only produced by the parity loop
	# below, so its warning count is asserted there.

	# Table rows are well formed: name in backticks, numeric time, right arity.
	assert_table_well_formed() {
		# assert_table_well_formed <report> <label>
		local report="$1" label="$2" bad
		# A layer name may contain an escaped pipe (native escapes it, the
		# fallback splits on it), so the name is any run of non-pipe characters
		# interleaved with \| sequences.
		bad=$(grep -E '^\| `' "$report" | grep -vcE '^\| `[^|]*(\\\|[^|]*)*` \| [0-9]+(\.[0-9]+)? \|$' || true)
		assert_eq 0 "$bad" "$label"
	}
	# These reports are produced by the parity loop below, which runs after this
	# point, so the well-formedness sweep is issued there as well.

	# CRLF endings and a missing final newline parse identically to plain LF.
	run_native "$tmp/crlf.md" "$fixtures/trtexec_crlf.log"
	assert_contains "$tmp/crlf.md" '| `attention_block` | 0.456 |' 'native crlf hottest layer'
	assert_not_contains "$tmp/crlf.md" '\r' 'native strips carriage returns'

	# Non-ASCII names survive round-trip.
	run_native "$tmp/unicode.md" "$fixtures/trtexec_unicode.log"
	assert_contains "$tmp/unicode.md" 'ぁいうえお層' 'native unicode layer name'
	assert_contains "$tmp/unicode.md" 'ñandú_capa' 'native unicode accented layer name'

	# Empty and whitespace-only inputs are handled without crashing.
	run_native "$tmp/empty.md" "$fixtures/trtexec_empty.log"
	assert_eq 0 "$(sed -n 's/^- Retained hotspots: //p' "$tmp/empty.md")" 'native empty retained'
	run_native "$tmp/blank.md" "$fixtures/trtexec_blank.log"
	assert_eq 0 "$(sed -n 's/^- Retained hotspots: //p' "$tmp/blank.md")" 'native blank retained'

	# --- native vs fallback parity over every fixture -----------------------
	#
	# The two engines emit intentionally different documents, so parity is
	# asserted on normalised facts (top-N layer names+times, and the metric
	# values each summary carries), not on raw text.
	for name in trtexec.log trtexec_nosummary.log trtexec_warnings.log trtexec_malformed.log \
		trtexec_crlf.log trtexec_unicode.log trtexec_empty.log trtexec_blank.log trtexec_large.log; do
		run_native "$tmp/native_$name.md" "$fixtures/$name" --top 20 --max-chars 12000
		run_fallback "$tmp/fallback_$name.md" "$fixtures/$name" --top 20 --max-chars 12000

		# Top-20 (name, time) pairs must be identical once formatting is
		# normalised away.
		normalise_layers() {
			# native rows: | `name` | 12.5 |   python rows: | name | 12.500 |
			sed -n 's/^| `\(.*\)` | \([0-9.]*\) |$/\1 \2/p' "$1" |
				sed 's/\\|/|/g;s/'"'"'/`/g'
		}
		sed -n 's/^| \(.*\) | \([0-9.]*\) |$/\1 \2/p' "$tmp/fallback_$name.md" >"$tmp/fb.norm"
		normalise_layers "$tmp/native_$name.md" >"$tmp/na.norm"

		# The two renderers format the same number differently (native 12.5,
		# fallback 12.500), so the time is re-rendered to a fixed precision and
		# the raw text is dropped. The name is everything before the trailing
		# time field and may itself contain spaces.
		layer_key() {
			awk '{
				t = $NF; name = $0
				sub(/[[:space:]]+[^[:space:]]+$/, "", name)
				# The fallback splits rows on "|", so a layer name containing
				# one is truncated there while the native core escapes it.
				# Compare up to the first pipe, which is exactly where the two
				# engines diverge; the escaped form is asserted separately.
				sub(/\|.*$/, "", name)
				printf "%.6f|%s\n", t, name
			}'
		}
		layer_key <"$tmp/na.norm" | sort -rn >"$tmp/na.sorted"
		layer_key <"$tmp/fb.norm" | sort -rn >"$tmp/fb.sorted"
		if diff -q "$tmp/na.sorted" "$tmp/fb.sorted" >/dev/null; then
			pass
		else
			fail "native/fallback layer parity for $name"
			diff "$tmp/na.sorted" "$tmp/fb.sorted" | head -6 >&2 || true
		fi
		# The hottest layer must agree even where row formatting differs.
		na_top=$(head -1 "$tmp/na.sorted" | cut -d'|' -f1)
		fb_top=$(head -1 "$tmp/fb.sorted" | cut -d'|' -f1)
		assert_eq "$na_top" "$fb_top" "native/fallback hottest time for $name"

		if [[ $name == trtexec_warnings.log ]]; then
			assert_eq 10 "$(sed -n 's/^- Warning\/error lines: \([0-9][0-9]*\)$/\1/p' \
				"$tmp/native_$name.md")" 'native warning count'
		fi
		assert_scanned "$name" "$tmp/native_$name.md"
		if [[ $name != trtexec_empty.log && $name != trtexec_blank.log ]]; then
			assert_table_well_formed "$tmp/native_$name.md" "native table rows for $name"
		fi
	done
	# Known, asserted divergence: the fallback strips a pipe out of a layer
	# name (it splits on "|"), while the native core escapes it. Both keep the
	# same timing, so only the label differs.
	assert_contains "$tmp/native_trtexec_malformed.log.md" '| `single\|pipe` | 0.75 |' \
		'native escapes pipe in malformed fixture'
	assert_contains "$tmp/fallback_trtexec_malformed.log.md" '| single | 0.750 |' \
		'fallback drops the piped half of the name'

	# "H2D Latency:" and "D2H Latency:" both contain "Latency:", so the
	# specific arms must be tested before the generic one. When they were
	# tested after it, every transfer line overwrote the overall latency mean
	# and the transfer metrics were never emitted at all.
	printf '[T] [TRT] Latency: min = 1.000 ms, mean = 0.500 ms, percentile(90%%) = 0.900 ms\n[T] [TRT] H2D Latency: min = 0.100 ms, mean = 0.200 ms\n[T] [TRT] D2H Latency: min = 0.010 ms, mean = 0.020 ms\n' \
		>"$tmp/h2d.log"
	run_native "$tmp/native_h2d.md" "$tmp/h2d.log"
	run_fallback "$tmp/fallback_h2d.md" "$tmp/h2d.log"
	assert_contains "$tmp/native_h2d.md" '- Latency mean: 0.5 ms' 'native latency mean survives h2d/d2h lines'
	assert_contains "$tmp/native_h2d.md" '- Latency p90: 0.9 ms' 'native latency p90 survives h2d/d2h lines'
	assert_contains "$tmp/native_h2d.md" '- H2D mean: 0.2 ms' 'native h2d mean field'
	assert_contains "$tmp/native_h2d.md" '- D2H mean: 0.02 ms' 'native d2h mean field'
	assert_contains "$tmp/fallback_h2d.md" 'mean=0.500 ms' 'fallback keeps latency mean'
	assert_contains "$tmp/fallback_h2d.md" 'H2D Latency: min=0.100 ms, mean=0.200 ms' 'fallback h2d mean'
fi

# ---------------------------------------------------------------------------
# Fallback half. Runs everywhere, including machines without Mojo.
# ---------------------------------------------------------------------------
PATH="/usr/bin:/bin" XDG_CACHE_HOME="$tmp/fallback" PROFILE_MD_DISABLE_NATIVE=1 \
	"$wrapper" "$fixtures/trtexec.log" \
	--out "$tmp/fallback.md" --top 1 --max-chars 2000
grep -q 'TensorRT trtexec Report' "$tmp/fallback.md"
grep -q 'attention_block' "$tmp/fallback.md"
if grep -q 'conv1' "$tmp/fallback.md"; then
	echo "fallback --top 1 retained more than one layer" >&2
	exit 1
fi
test "$(grep -c '^| attention_block |' "$tmp/fallback.md")" -eq 1

run_fallback "$tmp/fb_help.md" --help
assert_eq 0 $? 'fallback --help exit code'
assert_contains "$tmp/fb_help.md" 'usage: profile-md' 'fallback --help usage line'

# Fallback rejects the same bad invocations, on stderr.
assert_fallback_rejects() {
	# assert_fallback_rejects <expected-message> <args...>
	local want="$1"
	shift
	local out="$tmp/fb_err.md"
	set +e
	run_fallback "$out" "$@"
	local rc=$?
	set -e
	if [[ $rc -eq 0 ]]; then
		fail "fallback error path [$*] exited 0"
		return
	fi
	pass
	assert_contains "$out.err" "$want" "fallback error path [$*] message"
}

assert_fallback_rejects 'unrecognized arguments' \
	"$fixtures/trtexec.log" "$fixtures/trtexec_nosummary.log"
assert_fallback_rejects 'unrecognized arguments' "$fixtures/trtexec.log" --bogus
assert_fallback_rejects 'expected one argument' "$fixtures/trtexec.log" --out
assert_fallback_rejects 'expected one argument' "$fixtures/trtexec.log" --top
assert_fallback_rejects 'invalid choice' "$fixtures/trtexec.log" --kind bogus
assert_fallback_rejects '--top must be positive' "$fixtures/trtexec.log" --top 0
assert_fallback_rejects '--max-chars must be at least 1000' \
	"$fixtures/trtexec.log" --max-chars 999

	# Expected to fail, so the runner's non-zero status must not trip `set -e`.
	set +e
	run_fallback "$tmp/fb_missing.md"
	fb_missing_rc=$?
	set -e
	assert_ne 0 "$fb_missing_rc" 'fallback missing input exit code'
	assert_contains "$tmp/fb_missing.md.err" 'required' 'fallback missing input message'

run_fallback "$tmp/fb_cap1000.md" "$fixtures/trtexec_large.log" --top 40 --max-chars 1000
assert_eq 0 $? 'fallback --max-chars 1000'
run_fallback "$tmp/fb_cap1001.md" "$fixtures/trtexec_large.log" --top 40 --max-chars 1001
assert_eq 0 $? 'fallback --max-chars 1001'
fb_cap_bytes=$(wc -c <"$tmp/fb_cap1000.md")
if [[ $fb_cap_bytes -le 1000 ]]; then
	pass
else
	fail "fallback --max-chars 1000 emitted $fb_cap_bytes bytes"
fi
assert_contains "$tmp/fb_cap1000.md" '_Output capped by `--max-chars`._' 'fallback cap marker'

run_fallback "$tmp/fb_compact.md" "$fixtures/trtexec_large.log" --compact
assert_eq 10 "$(grep -c '^| [a-z]' "$tmp/fb_compact.md")" 'fallback --compact rows'

run_fallback "$tmp/fb_top9999.md" "$fixtures/trtexec_nosummary.log" --top 9999
assert_eq 5 "$(grep -c '^| [a-z]' "$tmp/fb_top9999.md")" 'fallback --top above layer count'

run_fallback "$tmp/fb_summary.md" "$fixtures/trtexec.log"
assert_contains "$tmp/fb_summary.md" '- Throughput: 1234.56 qps' 'fallback throughput field'
assert_contains "$tmp/fb_summary.md" 'mean=0.150 ms' 'fallback latency mean field'
assert_contains "$tmp/fb_summary.md" 'p90=0.180 ms' 'fallback latency p90 field'
assert_contains "$tmp/fb_summary.md" '- Enqueue Time: min=0.050 ms' 'fallback enqueue field'
assert_contains "$tmp/fb_summary.md" '- GPU Compute Time: min=0.040 ms' 'fallback gpu field'

run_fallback "$tmp/fb_nosummary.md" "$fixtures/trtexec_nosummary.log"
assert_contains "$tmp/fb_nosummary.md" '- No performance summary parsed.' \
	'fallback missing-summary branch'

# Fallback keeps every warning line as a note, including case variants.
run_fallback "$tmp/fb_warnings.md" "$fixtures/trtexec_warnings.log"
assert_eq 7 "$(grep -c '^- \[10/05/2026' "$tmp/fb_warnings.md")" 'fallback note count'
assert_not_contains "$tmp/fb_warnings.md" 'non-TRT line' 'fallback ignores non-TRT lines'

run_fallback "$tmp/fb_malformed.md" "$fixtures/trtexec_malformed.log"
assert_eq 8 "$(grep -c '^| [a-z]' "$tmp/fb_malformed.md")" 'fallback malformed layer count'
assert_not_contains "$tmp/fb_malformed.md" 'negative_time' 'fallback drops negative timings'
assert_not_contains "$tmp/fb_malformed.md" 'no_digits_here' 'fallback drops digitless timings'
assert_not_contains "$tmp/fb_malformed.md" 'truncated_last_line' 'fallback drops truncated last line'

run_fallback "$tmp/fb_crllf.md" "$fixtures/trtexec_crlf.log"
assert_contains "$tmp/fb_crllf.md" '| attention_block | 0.456 |' 'fallback crlf hottest layer'

run_fallback "$tmp/fb_unicode.md" "$fixtures/trtexec_unicode.log"
assert_contains "$tmp/fb_unicode.md" '| ぁいうえお層 | 0.700 |' 'fallback unicode layer name'

run_fallback "$tmp/fb_empty.md" "$fixtures/trtexec_empty.log"
assert_not_contains "$tmp/fb_empty.md" 'Per-Layer Runtime' 'fallback empty has no table'
run_fallback "$tmp/fb_blank.md" "$fixtures/trtexec_blank.log"
assert_not_contains "$tmp/fb_blank.md" 'Per-Layer Runtime' 'fallback blank has no table'
	# Drop the header row: it starts with a capital like a layer name but is
	# not a data row.
	bad_rows=$(grep -E '^\| [a-zA-Z]' "$tmp/fallback_trtexec_large.log.md" 2>/dev/null |
		grep -v '^| Layer |' |
		grep -vcE '^\| .* \| [0-9]+\.[0-9]{3} \|$' || true)
assert_eq 0 "$bad_rows" 'fallback table rows well formed'

echo
echo "passed: $pass_count  failed: $fail_count  skipped: $skip_count"
if [[ $native_available -eq 0 ]]; then
	echo "SKIPPED: native Mojo half (toolchain unavailable)"
fi
[[ $fail_count -eq 0 ]] || exit 1
