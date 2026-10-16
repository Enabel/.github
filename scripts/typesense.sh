#!/usr/bin/env bash
# Start a throwaway Typesense server for the tests and export the variables the
# enabel/typesense bundle reads. Typesense runs outside Upsun (Typesense Cloud),
# so its version cannot be read from the Upsun config: the caller passes it.
#
# Usage: typesense.sh <version>   (e.g. 29.0)
#
# Environment:
#   TYPESENSE_DRY_RUN  1 = print what would start, no docker call
#   TYPESENSE_TIMEOUT  seconds to wait for /health (default: 60)
#   GITHUB_ENV         when set, variables are written there instead of printed
set -euo pipefail

version=${1:-}
dry_run=${TYPESENSE_DRY_RUN:-0}
image="typesense/typesense:$version"
port=8108
api_key=ci

error() {
    echo "::error::$*" >&2
    exit 1
}

[ -n "$version" ] || error "Typesense version missing (e.g. typesense.sh 29.0)"

exports=(
    "TYPESENSE_URL=http://127.0.0.1:$port"
    "TYPESENSE_KEY=$api_key"
    "TYPESENSE_PREFIX=ci_"
)

if [ "$dry_run" = 1 ]; then
    echo "start typesense $image"
    printf 'export %s\n' "${exports[@]}"
    exit 0
fi

output=$(docker pull -q "$image" 2>&1) || error "Typesense: image $image not found or pull failed: $output"
docker rm -f ci-typesense >/dev/null 2>&1 || true
output=$(docker run -d --name ci-typesense -p "127.0.0.1:$port:$port" "$image" \
    --data-dir /tmp --api-key="$api_key" --enable-cors 2>&1) || error "Typesense: cannot start $image: $output"

timeout=${TYPESENSE_TIMEOUT:-60}
elapsed=0
until [ "$(curl -s "http://127.0.0.1:$port/health" || true)" = '{"ok":true}' ]; do
    if [ "$elapsed" -ge "$timeout" ]; then
        docker logs ci-typesense >&2 || true
        error "Typesense not healthy after ${timeout}s"
    fi
    sleep 1
    elapsed=$((elapsed + 1))
done

for line in "${exports[@]}"; do
    if [ -n "${GITHUB_ENV:-}" ]; then
        echo "$line" >>"$GITHUB_ENV"
    else
        echo "export $line"
    fi
done
