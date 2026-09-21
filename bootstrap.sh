#!/usr/bin/env bash
set -Eeuo pipefail

readonly MCSR_SETUP_REPO="${MCSR_SETUP_REPO:-https://github.com/diamondgather1n/mcsr-setup.git}"
readonly MCSR_SETUP_REF="${MCSR_SETUP_REF:-814cfcf87668ae5ca2dc348d607f600705a1e722}"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly PROFILE="${1:-}"

die() {
    printf 'mcsr bootstrap: %s\n' "$*" >&2
    exit 1
}

case "$PROFILE" in
    NLmcsrWL|LmcsrWL|NLmcsrX11|LmcsrX11|MNLmcsrWL|MLmcsrWL|MNLmcsrX11|MLmcsrX11)
        ;;
    *)
        die "unknown profile: ${PROFILE:-missing}"
        ;;
esac

command -v git >/dev/null 2>&1 || die "git is required"
[[ -n "${HOME:-}" && -d "$HOME" ]] || die "HOME must name an existing directory"

readonly CHECKOUT="${MCSR_BOOTSTRAP_CHECKOUT_DIR:-$HOME/mcsr-setup}"
[[ ! -e "$CHECKOUT" ]] || die "refusing to overwrite existing path: $CHECKOUT"
mkdir -p -- "$(dirname -- "$CHECKOUT")"

workdir="$(mktemp -d "${TMPDIR:-/tmp}/mcsr-bootstrap.XXXXXXXX")"
cleanup() {
    rm -rf -- "$workdir"
}
trap cleanup EXIT

git init -q -- "$CHECKOUT"
git -C "$CHECKOUT" remote add origin "$MCSR_SETUP_REPO"
git -C "$CHECKOUT" fetch --quiet --depth=1 --filter=blob:none origin "$MCSR_SETUP_REF" \
    || die "could not fetch pinned mcsr-setup ref $MCSR_SETUP_REF"

commit="$(git -C "$CHECKOUT" rev-parse FETCH_HEAD)"
manifest="profiles/${PROFILE}.manifest"
paths_file="$workdir/paths"
: >"$paths_file"

declare -A seen_manifests=()
declare -A seen_paths=()
add_path() {
    local path=$1
    if [[ -z "${seen_paths[$path]+x}" ]]; then
        seen_paths["$path"]=1
        printf '%s\n' "$path" >>"$paths_file"
    fi
}

read_manifest() {
    local name=$1
    local line kind path
    [[ -n "${seen_manifests[$name]+x}" ]] && return
    seen_manifests["$name"]=1
    add_path "$name"
    local manifest_file="$workdir/manifest-${#seen_manifests[@]}"
    git -C "$CHECKOUT" show "$commit:$name" >"$manifest_file" \
        || die "pinned profile is missing $name"
    while IFS=$'\t' read -r kind path; do
        [[ -z "$kind" || "$kind" == \#* ]] && continue
        case "$kind" in
            include)
                read_manifest "profiles/$path"
                ;;
            file|tree)
                add_path "$path"
                ;;
            '')
                ;;
            *)
                die "unsupported manifest entry in $name: $kind"
                ;;
        esac
    done <"$manifest_file"
}

read_manifest "$manifest"
git -C "$CHECKOUT" sparse-checkout init --no-cone
mapfile -t sparse_paths < <(LC_ALL=C sort -u "$paths_file")
git -C "$CHECKOUT" sparse-checkout set --no-cone "${sparse_paths[@]}"
git -C "$CHECKOUT" checkout --quiet --detach "$commit"

entry="$PROFILE.sh"
[[ -f "$CHECKOUT/$entry" ]] || die "selected profile entry point was not downloaded: $entry"
[[ -f "$CHECKOUT/shared/install-common.sh" ]] || die "common installer was not downloaded"
[[ -f "$CHECKOUT/profiles/versions.env" ]] || die "version pins were not downloaded"

if [[ "${MCSR_BOOTSTRAP_DRY_RUN:-0}" == 1 ]]; then
    printf 'profile=%s\ncommit=%s\ncheckout=%s\n' "$PROFILE" "$commit" "$CHECKOUT"
    printf '%s\n' "${sparse_paths[@]}"
    exit 0
fi

rm -rf -- "$workdir"
trap - EXIT
exec "$CHECKOUT/$entry"
