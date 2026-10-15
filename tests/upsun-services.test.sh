#!/usr/bin/env bash
# Tests for scripts/upsun-services.sh. Run through `make test`.
set -u

cd "$(dirname "$0")/.." || exit 1

SCRIPT=scripts/upsun-services.sh
FIXTURES=tests/fixtures
failures=0
CASE=""
out=""
status=0

fail() { echo "FAIL $1"; failures=$((failures + 1)); }

# run_case <fixture>: dry run, sets $out (stdout+stderr) and $status
run_case() {
    CASE=$1
    out=$(UPSUN_SERVICES_DRY_RUN=1 bash "$SCRIPT" "$FIXTURES/$1/config.yaml" 2>&1)
    status=$?
}

expect_status() { [ "$status" -eq "$1" ] || fail "$CASE: status $status, expected $1"; }
expect_line() { grep -qxF -- "$1" <<<"$out" || fail "$CASE: missing line: $1"; }
expect_no_match() { ! grep -qF -- "$1" <<<"$out" || fail "$CASE: unexpected output containing: $1"; }
# expect_annotation <prefix> <word>...: one line starting with prefix and containing every word
expect_annotation() {
    local prefix=$1 line word
    shift
    while IFS= read -r line; do
        [[ $line == "$prefix"* ]] || continue
        for word in "$@"; do
            [[ $line == *"$word"* ]] || continue 2
        done
        return 0
    done <<<"$out"
    fail "$CASE: no '$prefix' line containing: $*"
}

# --- Dry run: translation Upsun type -> image and variables -------------------

run_case mariadb
expect_status 0
expect_line "start database mariadb:12.3"
expect_line "start redis redis:8.0"
expect_line "export DATABASE_URL=mysql://root:root@127.0.0.1:3306/app?serverVersion=12.3.0-MariaDB"
expect_line "export REDIS_URL=redis://127.0.0.1:6379"

run_case mysql-alias
expect_status 0
expect_line "start database mariadb:11.8"
expect_line "export DATABASE_URL=mysql://root:root@127.0.0.1:3306/app?serverVersion=11.8.0-MariaDB"

run_case oracle-mysql
expect_status 0
expect_line "start database mysql:8.4"
expect_line "export DATABASE_URL=mysql://root:root@127.0.0.1:3306/app?serverVersion=8.4"

run_case four-spaces
expect_status 0
expect_line "start database mysql:8.4"
expect_line "start redis redis:8.0"
expect_line "export DATABASE_URL=mysql://root:root@127.0.0.1:3306/app?serverVersion=8.4"
expect_line "export REDIS_URL=redis://127.0.0.1:6379"

run_case redis-only
expect_status 0
expect_line "start redis redis:7.2"
expect_no_match "DATABASE_URL"

run_case none
expect_status 0
[ -z "$out" ] || fail "$CASE: expected empty output, got: $out"

run_case unknown
expect_status 0
expect_line "start redis redis:8.0"
expect_annotation "::warning::" search opensearch:2
expect_no_match "start search"

run_case two-databases
expect_status 1
expect_annotation "::error::" database legacy
expect_no_match "start "

run_case no-version
expect_status 1
expect_annotation "::error::" database mariadb
expect_no_match "start "

# --- Relationships drive what starts and how variables are named --------------

# OWL: relationship `database` targets service `mariadb`; the old
# `database` service (oracle-mysql) is a leftover with no relationship.
run_case owl
expect_status 0
expect_line "start mariadb mariadb:12.3"
expect_line "start redis redis:8.0"
expect_line "export DATABASE_URL=mysql://root:root@127.0.0.1:3306/app?serverVersion=12.3.0-MariaDB"
expect_line "export REDIS_URL=redis://127.0.0.1:6379"
expect_annotation "::warning::" database oracle-mysql:8.4
expect_no_match "start database"
expect_no_match "MARIADB_URL"

run_case shared-service
expect_status 0
expect_line "start db mariadb:11.8"
[ "$(grep -c '^start ' <<<"$out")" -eq 1 ] || fail "$CASE: service started more than once"
expect_line "export DATABASE_URL=mysql://root:root@127.0.0.1:3306/app?serverVersion=11.8.0-MariaDB"
expect_line "export DATABASE_RO_URL=mysql://root:root@127.0.0.1:3306/app?serverVersion=11.8.0-MariaDB"

run_case legacy-string
expect_status 0
expect_line "start db mysql:8.4"
expect_line "export DATABASE_URL=mysql://root:root@127.0.0.1:3306/app?serverVersion=8.4"

run_case app-relationship
expect_status 0
expect_line "start redis redis:8.0"
expect_line "export REDIS_URL=redis://127.0.0.1:6379"
expect_annotation "::warning::" api backend
expect_no_match "API_URL"

# --- Integration: real docker run (SKIP_DOCKER=1 to skip) ---------------------

if [ "${SKIP_DOCKER:-0}" != 1 ]; then
    cleanup() { docker rm -f ci-redis ci-database >/dev/null 2>&1 || true; }
    tmp=$(mktemp -d)
    trap 'cleanup; rm -rf "$tmp"' EXIT

    CASE=integration-redis
    cleanup
    env_file="$tmp/github_env"
    : >"$env_file"
    out=$(GITHUB_ENV="$env_file" bash "$SCRIPT" "$FIXTURES/redis-only/config.yaml" 2>&1)
    status=$?
    expect_status 0
    [ "$(cat "$env_file")" = "REDIS_URL=redis://127.0.0.1:6379" ] \
        || fail "$CASE: GITHUB_ENV content: $(cat "$env_file")"
    [ "$(docker exec ci-redis redis-cli ping 2>&1)" = PONG ] || fail "$CASE: redis not answering PONG"
    cleanup

    CASE=integration-missing-tag
    mkdir -p "$tmp/missing-tag"
    printf 'applications:\n  app:\n    relationships:\n      redis: {}\nservices:\n  redis:\n    type: redis:0.0\n' >"$tmp/missing-tag/config.yaml"
    out=$(GITHUB_ENV="$tmp/unused" bash "$SCRIPT" "$tmp/missing-tag/config.yaml" 2>&1)
    status=$?
    expect_status 1
    expect_annotation "::error::" redis redis:0.0
    [ -z "$(docker ps -aq --filter name=^ci-redis$)" ] || fail "$CASE: container ci-redis left behind"
    cleanup

    CASE=integration-port-taken
    docker run -d --name ci-test-blocker -p 127.0.0.1:6379:6379 redis:7.2 >/dev/null
    out=$(GITHUB_ENV="$tmp/unused" bash "$SCRIPT" "$FIXTURES/redis-only/config.yaml" 2>&1)
    status=$?
    docker rm -f ci-test-blocker >/dev/null
    expect_status 1
    expect_annotation "::error::" redis redis:7.2
    cleanup

    CASE=integration-timeout
    # MariaDB alone: with a second service, its slower pull could leave MariaDB
    # healthy before the wait starts, and the timeout would never trigger.
    mkdir -p "$tmp/mariadb-only"
    printf 'applications:\n  app:\n    relationships:\n      database: {}\nservices:\n  database:\n    type: mariadb:12.3\n' \
        >"$tmp/mariadb-only/config.yaml"
    out=$(UPSUN_SERVICES_TIMEOUT=1 GITHUB_ENV="$tmp/unused" bash "$SCRIPT" "$tmp/mariadb-only/config.yaml" 2>&1)
    status=$?
    expect_status 1
    expect_annotation "::error::" database
    # MariaDB entrypoint log line, proving `docker logs` was dumped
    grep -qi "entrypoint" <<<"$out" || fail "$CASE: container logs not shown"
    cleanup
fi

# ------------------------------------------------------------------------------

if [ "$failures" -gt 0 ]; then
    echo "$failures failure(s)"
    exit 1
fi
echo "All tests passed"
