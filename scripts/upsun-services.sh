#!/usr/bin/env bash
# Start the CI services (database, Redis) an Upsun application reaches through
# its relationships, with the same images and versions, and export their URLs
# the way Upsun names them (relationship `database` -> DATABASE_URL).
#
# Usage: upsun-services.sh [config_path]   (default: .upsun/config.yaml)
#
# Environment:
#   YQ                      yq command (default: yq), e.g. "docker run --rm -i mikefarah/yq:4"
#   UPSUN_SERVICES_DRY_RUN  1 = print what would start, no docker call
#   UPSUN_SERVICES_TIMEOUT  seconds to wait for each service to be healthy (default: 60)
#   GITHUB_ENV              when set, variables are written there instead of printed
set -euo pipefail

config=${1:-.upsun/config.yaml}
dry_run=${UPSUN_SERVICES_DRY_RUN:-0}
read -ra yq_cmd <<<"${YQ:-yq}"

error() {
    echo "::error::$*" >&2
    exit 1
}

warning() {
    echo "::warning::$*" >&2
}

[ -f "$config" ] || error "Upsun config not found: $config"

services=$("${yq_cmd[@]}" -o=tsv '.services // {} | to_entries | .[] | [.key, .value.type] | @tsv' <"$config")
# Relationship -> target service. Forms: `rel: {service: X, ...}`, `rel: {}` or
# `rel:` (target = relationship name), legacy string `rel: "X:endpoint"`.
relationships=$("${yq_cmd[@]}" -o=tsv '.applications // {} | .[] | .relationships // {} | to_entries | .[]
    | [.key, ((.value | select(tag == "!!str") | split(":") | .[0]) // .value.service // "")] | @tsv' <"$config")

declare -A service_type=() referenced=() started=() target_of=()
while IFS=$'\t' read -r name type; do
    [ -n "$name" ] && service_type[$name]=$type
done <<<"$services"

# Validate every entry before starting anything: an invalid config starts no container.
names=()
images=()
engines=()
exports=()
database=""
while IFS=$'\t' read -r rel service; do
    [ -n "$rel" ] || continue
    service=${service:-$rel}
    if [ -n "${target_of[$rel]:-}" ]; then
        [ "${target_of[$rel]}" = "$service" ] \
            || error "Relationship $rel targets both ${target_of[$rel]} and $service"
        continue
    fi
    target_of[$rel]=$service
    if [ -z "${service_type[$service]+set}" ]; then
        warning "Relationship $rel: $service is not a service (another application?), ignored"
        continue
    fi
    referenced[$service]=1
    type=${service_type[$service]}
    version=${type#*:}
    if [[ $type != *:* || -z $version ]]; then
        error "Service $service: type '$type' has no version"
    fi
    case ${type%%:*} in
        mariadb | mysql) # `mysql` is MariaDB on Upsun
            engine=mariadb
            image="mariadb:$version"
            url="mysql://root:root@127.0.0.1:3306/app?serverVersion=${version}.0-MariaDB"
            ;;
        oracle-mysql)
            engine=mysql
            image="mysql:$version"
            url="mysql://root:root@127.0.0.1:3306/app?serverVersion=${version}"
            ;;
        redis)
            engine=redis
            image="redis:$version"
            url="redis://127.0.0.1:6379"
            ;;
        *)
            warning "Service $service: type $type is not supported in CI, not started"
            continue
            ;;
    esac
    if [ -z "${started[$service]:-}" ]; then
        if [ "$engine" != redis ]; then
            [ -z "$database" ] || error "Services $database and $service are both databases, only one is supported"
            database=$service
        fi
        started[$service]=1
        names+=("$service")
        images+=("$image")
        engines+=("$engine")
    fi
    var=$(tr 'a-z-' 'A-Z_' <<<"$rel")_URL
    exports+=("$var=$url")
done <<<"$relationships"

# A service no relationship uses is a leftover (e.g. after moving to another
# database service): Upsun keeps it running, the application never reaches it.
while IFS=$'\t' read -r name type; do
    if [ -n "$name" ] && [ -z "${referenced[$name]:-}" ]; then
        warning "Service $name ($type) is not used by any relationship, not started"
    fi
done <<<"$services"

# start_service <name> <image> <engine>: container ci-<name>, port published on 127.0.0.1
start_service() {
    local name=$1 image=$2 engine=$3 port args=()
    case $engine in
        mariadb)
            port=3306
            args=(-e MARIADB_ROOT_PASSWORD=root -e MARIADB_DATABASE=app
                --health-cmd "healthcheck.sh --connect --innodb_initialized")
            ;;
        mysql)
            port=3306
            args=(-e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=app
                --health-cmd "mysqladmin ping -h 127.0.0.1 -uroot -proot")
            ;;
        redis)
            port=6379
            args=(--health-cmd "redis-cli ping")
            ;;
    esac
    # Explicit pull: a tag missing from Docker Hub must fail with a clear message,
    # never fall back to another version than the one Upsun runs.
    local output
    output=$(docker pull -q "$image" 2>&1) || error "Service $name: image $image not found or pull failed: $output"
    docker rm -f "ci-$name" >/dev/null 2>&1 || true
    output=$(docker run -d --name "ci-$name" -p "127.0.0.1:$port:$port" --health-interval 2s \
        "${args[@]}" "$image" 2>&1) || error "Service $name: cannot start $image: $output"
}

wait_healthy() {
    local name=$1 timeout=${UPSUN_SERVICES_TIMEOUT:-60} elapsed=0
    until [ "$(docker inspect --format '{{.State.Health.Status}}' "ci-$name")" = healthy ]; do
        if [ "$elapsed" -ge "$timeout" ]; then
            docker logs "ci-$name" >&2 || true
            error "Service $name not healthy after ${timeout}s"
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
}

for i in "${!names[@]}"; do
    if [ "$dry_run" = 1 ]; then
        echo "start ${names[$i]} ${images[$i]}"
    else
        start_service "${names[$i]}" "${images[$i]}" "${engines[$i]}"
    fi
done

if [ "$dry_run" != 1 ]; then
    for name in "${names[@]}"; do
        wait_healthy "$name"
    done
fi

for line in "${exports[@]}"; do
    if [ "$dry_run" != 1 ] && [ -n "${GITHUB_ENV:-}" ]; then
        echo "$line" >>"$GITHUB_ENV"
    else
        echo "export $line"
    fi
done
