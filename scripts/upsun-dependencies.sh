#!/usr/bin/env bash
# Install the Python dependencies an Upsun application declares
# (applications.*.dependencies.python3), with the versions production uses.
#
# Usage: upsun-dependencies.sh [config_path]   (default: .upsun/config.yaml)
#
# Environment:
#   YQ                          yq command (default: yq)
#   UPSUN_DEPENDENCIES_DRY_RUN  1 = print the pip requirements, install nothing
#   GITHUB_PATH                 when set, ~/.local/bin is added to it (pip --user scripts)
set -euo pipefail

config=${1:-.upsun/config.yaml}
dry_run=${UPSUN_DEPENDENCIES_DRY_RUN:-0}
read -ra yq_cmd <<<"${YQ:-yq}"

error() {
    echo "::error::$*" >&2
    exit 1
}

[ -f "$config" ] || error "Upsun config not found: $config"

# One line per dependency: <type> <TAB> <name> <TAB> <version>
# shellcheck disable=SC2016 # $type is a yq variable
entries=$("${yq_cmd[@]}" -o=tsv '.applications // {} | .[] | .dependencies // {} | to_entries | .[]
    | .key as $type | .value // {} | to_entries | .[] | [$type, .key, .value] | @tsv' <"$config")

requirements=()
while IFS=$'\t' read -r type name version; do
    [ -n "$type" ] || continue
    if [ "$type" != python3 ]; then
        echo "::warning::Upsun dependency $type/$name is not installed in CI (only python3 is)" >&2
        continue
    fi
    case $version in
        '' | '*') requirements+=("$name") ;;          # any version
        [0-9]*) requirements+=("$name==$version") ;; # exact version, as Upsun pins it
        *) requirements+=("$name$version") ;;        # already a specifier: >=70,<71
    esac
done <<<"$entries"

[ "${#requirements[@]}" -gt 0 ] || exit 0

if [ "$dry_run" = 1 ]; then
    printf 'pip-install %s\n' "${requirements[@]}"
    exit 0
fi

# --user: no root needed; --break-system-packages: the runner's Python is
# marked as externally managed (PEP 668) and this environment is throwaway.
python3 -m pip install --user --break-system-packages --no-cache-dir "${requirements[@]}"

if [ -n "${GITHUB_PATH:-}" ]; then
    echo "$HOME/.local/bin" >>"$GITHUB_PATH"
fi
