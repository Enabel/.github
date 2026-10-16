#!/usr/bin/env bash
# Tests for scripts/typesense.sh. Run through `make test`.
set -u

cd "$(dirname "$0")/.." || exit 1

SCRIPT=scripts/typesense.sh
failures=0
CASE=""
out=""
status=0

fail() { echo "FAIL $1"; failures=$((failures + 1)); }
expect_status() { [ "$status" -eq "$1" ] || fail "$CASE: status $status, expected $1"; }
expect_line() { grep -qxF -- "$1" <<<"$out" || fail "$CASE: missing line: $1"; }

# --- Dry run ------------------------------------------------------------------

CASE=dry-run
out=$(TYPESENSE_DRY_RUN=1 bash "$SCRIPT" 29.0 2>&1)
status=$?
expect_status 0
expect_line "start typesense typesense/typesense:29.0"
expect_line "export TYPESENSE_URL=http://127.0.0.1:8108"
expect_line "export TYPESENSE_KEY=ci"
expect_line "export TYPESENSE_PREFIX=ci_"

CASE=no-version
out=$(TYPESENSE_DRY_RUN=1 bash "$SCRIPT" 2>&1)
status=$?
expect_status 1
grep -q '^::error::.*version' <<<"$out" || fail "$CASE: no ::error:: about the version"

# --- Integration: real container (SKIP_DOCKER=1 to skip) ----------------------

if [ "${SKIP_DOCKER:-0}" != 1 ]; then
    cleanup() { docker rm -f ci-typesense >/dev/null 2>&1 || true; }
    tmp=$(mktemp -d)
    trap 'cleanup; rm -rf "$tmp"' EXIT

    CASE=integration-typesense
    cleanup
    : >"$tmp/github_env"
    out=$(GITHUB_ENV="$tmp/github_env" bash "$SCRIPT" 29.0 2>&1)
    status=$?
    expect_status 0
    grep -qxF "TYPESENSE_URL=http://127.0.0.1:8108" "$tmp/github_env" || fail "$CASE: TYPESENSE_URL not in GITHUB_ENV"
    [ "$(curl -s http://127.0.0.1:8108/health)" = '{"ok":true}' ] || fail "$CASE: /health is not ok"
    [ "$(curl -s -o /dev/null -w '%{http_code}' -H 'X-TYPESENSE-API-KEY: ci' http://127.0.0.1:8108/collections)" = 200 ] \
        || fail "$CASE: API key ci rejected"
    cleanup

    CASE=integration-missing-tag
    out=$(GITHUB_ENV="$tmp/unused" bash "$SCRIPT" 0.0.0 2>&1)
    status=$?
    expect_status 1
    grep -q '^::error::.*typesense/typesense:0.0.0' <<<"$out" || fail "$CASE: no ::error:: naming the image"
    cleanup
fi

# ------------------------------------------------------------------------------

if [ "$failures" -gt 0 ]; then
    echo "$failures failure(s)"
    exit 1
fi
echo "All tests passed"
