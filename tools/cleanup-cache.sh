#!/usr/bin/env bash
# cleanup-cache.sh - reclaim disk from snap revisions, package caches and build artifacts.
#
# Usage:
#   ./cleanup-cache.sh                 # dry run, shows what would be removed
#   ./cleanup-cache.sh --apply         # actually delete
#   ./cleanup-cache.sh --apply --code-root ~/projects   # limit dotnet clean to that tree
#
# The dotnet step searches for .sln/.csproj under --code-root (default: $HOME),
# runs 'dotnet clean' on each, then removes leftover bin/obj directories.
#
# Sections can be skipped with --no-snap, --no-pip, --no-nuget, --no-dotnet,
# --no-npm, --no-apt.

set -euo pipefail

APPLY=0
CODE_ROOT=""
DO_SNAP=1 DO_PIP=1 DO_NUGET=1 DO_DOTNET=1 DO_NPM=1 DO_APT=1

while [ $# -gt 0 ]; do
    case "$1" in
        --apply)      APPLY=1 ;;
        --code-root)  CODE_ROOT="${2:-}"; shift ;;
        --no-snap)    DO_SNAP=0 ;;
        --no-pip)     DO_PIP=0 ;;
        --no-nuget)   DO_NUGET=0 ;;
        --no-dotnet)  DO_DOTNET=0 ;;
        --no-npm)     DO_NPM=0 ;;
        --no-apt)     DO_APT=0 ;;
        -h|--help)    sed -n '2,12p' "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

have() { command -v "$1" >/dev/null 2>&1; }

say() { printf '\n== %s ==\n' "$1"; }

# Run a command, or just print it when not applying.
run() {
    if [ "$APPLY" -eq 1 ]; then
        "$@"
    else
        printf '[dry-run] %s\n' "$*"
    fi
}

# Same, but a non-zero exit is reported and ignored instead of aborting.
run_soft() {
    if [ "$APPLY" -eq 1 ]; then
        "$@" || echo "   (failed, continuing)" >&2
    else
        printf '[dry-run] %s\n' "$*"
    fi
}

used_before=$(df -P / | awk 'NR==2{print $3}')

# --- snap: remove disabled (old) revisions and the download cache ---------
if [ "$DO_SNAP" -eq 1 ] && have snap; then
    say "snap disabled revisions"
    LANG=en_US.UTF-8 snap list --all | awk '/disabled/{print $1, $3}' |
        while read -r snapname revision; do
            run sudo snap remove "$snapname" --revision="$revision"
        done

    say "snap download cache"
    run sudo find /var/lib/snapd/cache -mindepth 1 -delete
fi

# --- pip ------------------------------------------------------------------
if [ "$DO_PIP" -eq 1 ]; then
    say "pip cache"
    for pip in pip3 pip; do
        if have "$pip"; then
            "$pip" cache dir 2>/dev/null || true
            "$pip" cache info 2>/dev/null || true
            run "$pip" cache purge
            break
        fi
    done
    have uv && run uv cache clean
fi

# --- dotnet build artifacts ----------------------------------------------
if [ "$DO_DOTNET" -eq 1 ]; then
    root="${CODE_ROOT:-$HOME}"
    say "dotnet clean under $root"
    if [ ! -d "$root" ]; then
        echo "code root not found: $root" >&2
    elif ! have dotnet; then
        echo "dotnet not installed, skipping" >&2
    else
        # Skip directories that are never worth walking.
        # ProjectTemplates holds VS scaffolding whose project files contain
        # $placeholder$ tokens and cannot be restored or cleaned.
        # tizen-studio ships ~100 template projects that import targets
        # missing on disk (MSB4019); cleaning them only prints errors.
        prune=( -name node_modules -o -name .git -o -name bin -o -name obj
                -o -name .nuget -o -name .cache -o -name snap
                -o -name ProjectTemplates -o -name ItemTemplates
                -o -name tizen-studio -o -name cs-templates )

        # Prefer solutions: one clean covers every project they contain.
        mapfile -t slns < <(find "$root" \( "${prune[@]}" \) -prune -o \
            -type f \( -name '*.sln' -o -name '*.slnx' \) -print | sort)

        mapfile -t projs < <(find "$root" \( "${prune[@]}" \) -prune -o \
            -type f \( -name '*.csproj' -o -name '*.fsproj' -o -name '*.vbproj' \) -print | sort)

        # Drop projects already covered by a solution in an ancestor directory.
        targets=()
        for sln in "${slns[@]}"; do targets+=( "$sln" ); done
        for proj in "${projs[@]}"; do
            covered=0
            for sln in "${slns[@]}"; do
                case "$proj" in "$(dirname "$sln")"/*) covered=1; break ;; esac
            done
            [ "$covered" -eq 0 ] && targets+=( "$proj" )
        done

        if [ "${#targets[@]}" -eq 0 ]; then
            echo "no solutions or projects found under $root"
        fi

        for t in "${targets[@]}"; do
            echo "-- $t"
            # dotnet clean only removes what the last build configuration
            # produced, so sweep both common configurations.
            run_soft dotnet clean "$t" -c Debug --nologo -v quiet
            run_soft dotnet clean "$t" -c Release --nologo -v quiet
        done

        # dotnet clean leaves the bin/obj shells and any output from other
        # configurations or TFMs behind; remove them next to each project.
        say "leftover bin/obj"
        for proj in "${projs[@]}"; do
            projdir=$(dirname "$proj")
            for d in "$projdir/bin" "$projdir/obj"; do
                [ -d "$d" ] && run rm -rf "$d"
            done
        done
    fi
fi

# --- nuget / dotnet caches ------------------------------------------------
if [ "$DO_NUGET" -eq 1 ] && have dotnet; then
    say "nuget caches (http-cache, temp, global-packages)"
    dotnet nuget locals all --list || true
    # http-cache and temp are always safe. global-packages forces a re-restore
    # of every project on this machine, so keep it opt-in via NUGET_ALL=1.
    if [ "${NUGET_ALL:-0}" = "1" ]; then
        run dotnet nuget locals all --clear
    else
        run dotnet nuget locals http-cache --clear
        run dotnet nuget locals temp --clear
    fi
fi

# --- npm / yarn / pnpm ----------------------------------------------------
if [ "$DO_NPM" -eq 1 ]; then
    say "js package manager caches"
    have npm  && run npm cache clean --force
    have yarn && run yarn cache clean
    have pnpm && run pnpm store prune
fi

# --- apt + journal --------------------------------------------------------
if [ "$DO_APT" -eq 1 ] && have apt-get; then
    say "apt cache and old journals"
    run sudo apt-get clean
    run sudo apt-get autoremove --purge -y
    have journalctl && run sudo journalctl --vacuum-time=14d
fi

used_after=$(df -P / | awk 'NR==2{print $3}')
if [ "$APPLY" -eq 1 ]; then
    printf '\nFreed on /: %s MiB\n' "$(( (used_before - used_after) / 1024 ))"
else
    printf '\nDry run. Re-run with --apply to delete.\n'
fi
