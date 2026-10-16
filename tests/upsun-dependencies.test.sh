#!/usr/bin/env bash
# Tests for scripts/upsun-dependencies.sh. Run through `make test`.
set -u

cd "$(dirname "$0")/.." || exit 1

SCRIPT=scripts/upsun-dependencies.sh
FIXTURES=tests/fixtures
failures=0
CASE=""
out=""
status=0

fail() { echo "FAIL $1"; failures=$((failures + 1)); }

# run_case <fixture>: dry run, sets $out (stdout+stderr) and $status
run_case() {
    CASE=$1
    out=$(UPSUN_DEPENDENCIES_DRY_RUN=1 bash "$SCRIPT" "$FIXTURES/$1/config.yaml" 2>&1)
    status=$?
}

expect_status() { [ "$status" -eq "$1" ] || fail "$CASE: status $status, expected $1"; }
expect_line() { grep -qxF -- "$1" <<<"$out" || fail "$CASE: missing line: $1"; }
expect_no_match() { ! grep -qF -- "$1" <<<"$out" || fail "$CASE: unexpected output containing: $1"; }

# --- Dry run: Upsun python3 dependencies -> pip requirements -----------------

run_case python-pinned
expect_status 0
expect_line "pip-install weasyprint==70.0"

run_case python-star
expect_status 0
expect_line "pip-install weasyprint"

run_case python-range
expect_status 0
expect_line "pip-install weasyprint>=70,<71"
expect_line "pip-install pydyf==0.11.0"

run_case deps-other
expect_status 0
expect_line "pip-install weasyprint==70.0"
grep -q '^::warning::.*nodejs' <<<"$out" || fail "$CASE: no ::warning:: about nodejs"
expect_no_match "pip-install sass"

run_case none
expect_status 0
[ -z "$out" ] || fail "$CASE: expected empty output, got: $out"

# --- Integration: real pip install (RUN_PIP_INTEGRATION=1, CI runner only) ----

if [ "${RUN_PIP_INTEGRATION:-0}" = 1 ]; then
    CASE=integration-pip
    tmp=$(mktemp -d)
    printf "applications:\n  app:\n    dependencies:\n      python3:\n        six: '1.16.0'\n" >"$tmp/config.yaml"
    out=$(GITHUB_PATH="$tmp/path" bash "$SCRIPT" "$tmp/config.yaml" 2>&1)
    status=$?
    expect_status 0
    [ "$(python3 -c 'import six; print(six.__version__)' 2>&1)" = 1.16.0 ] || fail "$CASE: six 1.16.0 not importable"
    grep -q '/.local/bin$' "$tmp/path" || fail "$CASE: ~/.local/bin not added to GITHUB_PATH"
    rm -rf "$tmp"
fi

# ------------------------------------------------------------------------------

if [ "$failures" -gt 0 ]; then
    echo "$failures failure(s)"
    exit 1
fi
echo "All tests passed"
