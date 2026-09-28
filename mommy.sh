#!/usr/bin/env bash
# shellcheck shell=bash

if [ -z "${BASH_VERSION:-}" ]; then
    echo "mommy: mommy only speaks bash~~" >&2
    # shellcheck disable=SC2317 # exit is reached when run instead of sourced
    return 1 2>/dev/null || exit 1
fi
if (( BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4) )); then
    echo "mommy: mommy needs bash 4.4 or newer~~" >&2
    # shellcheck disable=SC2317 # exit is reached when run instead of sourced
    return 1 2>/dev/null || exit 1
fi

_MOMMY_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/bash-mommy"
_MOMMY_RESPONSES_URL='https://cdn.jsdelivr.net/gh/Gankra/cargo-mommy/responses.json'
_MOMMY_JQ_VERSION='jq-1.8.2'
# Refresh responses from upstream once a week
_MOMMY_MAX_AGE=$((7 * 24 * 60 * 60))

# Prints the path to a usable jq, fetching a verified one from jqlang if needed
_mommy_jq() {
    if command -v jq &>/dev/null; then
        echo jq
        return 0
    fi

    local jq_bin="$_MOMMY_DATA_DIR/$_MOMMY_JQ_VERSION" arch sum
    if [ -x "$jq_bin" ]; then
        echo "$jq_bin"
        return 0
    fi

    # Checksums from https://github.com/jqlang/jq/releases/download/jq-1.8.2/sha256sum.txt
    case "$(uname -s)/$(uname -m)" in
        Linux/x86_64) arch=amd64 sum=b1c22172dd303f3be49e935aa56aa48a8b7a46e0bc838b4997d3bb451495870f ;;
        Linux/aarch64) arch=arm64 sum=8b85c817833814ddca00a144c33705546355afccf0cf39b188f3cdb48b852309 ;;
        Linux/armv7l) arch=armhf sum=78458244fb546469b4042e9e07cf78714ef6848895eb9515df76b4eb0b1dc992 ;;
        Linux/i?86) arch=i386 sum=ba996e8ce436973e2f39e2639405a37e8c81ba8c722b71c83996278ad0af16dd ;;
        *)
            echo "mommy: mommy can't fetch jq for $(uname -sm), please install it~~" >&2
            return 1
            ;;
    esac

    mkdir -p "$_MOMMY_DATA_DIR" || return 1
    if ! curl -fsSL --max-time 30 -o "$jq_bin.tmp" \
        "https://github.com/jqlang/jq/releases/download/$_MOMMY_JQ_VERSION/jq-linux-$arch"; then
        rm -f "$jq_bin.tmp"
        echo "mommy: couldn't get jq~~" >&2
        return 1
    fi
    if ! echo "$sum  $jq_bin.tmp" | sha256sum -c --status; then
        rm -f "$jq_bin.tmp"
        echo "mommy: the jq mommy got doesn't look right, not using it~~" >&2
        return 1
    fi
    chmod +x "$jq_bin.tmp" && mv "$jq_bin.tmp" "$jq_bin" && echo "$jq_bin"
}

# Fetches upstream responses into $_MOMMY_DATA_DIR/responses/<mood>.<state>,
# one NUL-terminated response per entry. The old cache is kept on failure.
mommy_update() {
    local jq tmp mood state moods_raw
    local -a moods

    mkdir -p "$_MOMMY_DATA_DIR" || return 1
    # Record the attempt even if it fails, so a dead network doesn't stall every prompt
    touch "$_MOMMY_DATA_DIR/last-update"

    jq=$(_mommy_jq) || return 1
    tmp=$(mktemp -d "$_MOMMY_DATA_DIR/.update.XXXXXX") || return 1

    if ! curl -fsSL --max-time 10 -o "$tmp/responses.json" "$_MOMMY_RESPONSES_URL" ||
        ! moods_raw=$("$jq" -r '.moods | keys[]' "$tmp/responses.json"); then
        echo "mommy: couldn't get responses~~" >&2
        rm -rf "$tmp"
        return 1
    fi
    mapfile -t moods <<<"$moods_raw"

    for mood in "${moods[@]}"; do
        # Mood names become file names, so don't trust anything odd
        [[ $mood =~ ^[a-z]+$ ]] || continue
        for state in positive negative; do
            # shellcheck disable=SC2016 # $m and $s are jq variables
            if ! "$jq" -j --arg m "$mood" --arg s "$state" \
                '.moods[$m][$s] // [] | .[] | strings | . + "\u0000"' \
                "$tmp/responses.json" >"$tmp/$mood.$state"; then
                echo "mommy: couldn't understand the responses~~" >&2
                rm -rf "$tmp"
                return 1
            fi
        done
    done
    rm -f "$tmp/responses.json"

    rm -rf "$_MOMMY_DATA_DIR/responses" &&
        mv "$tmp" "$_MOMMY_DATA_DIR/responses" || return 1
    # Clean up files from older versions of bash-mommy
    rm -f "$_MOMMY_DATA_DIR/responses.sh" "$_MOMMY_DATA_DIR/mommy-jq"
    echo "mommy: manifestation completed~~" >&2
}

# Makes sure there is a usable response cache, refreshing it when stale
_mommy_ensure_responses() {
    local stamp="$_MOMMY_DATA_DIR/last-update" now mtime

    if [ -d "$_MOMMY_DATA_DIR/responses" ] && [ -f "$stamp" ]; then
        printf -v now '%(%s)T' -1
        mtime=$(stat -c %Y "$stamp" 2>/dev/null) || mtime=0
        (( now - mtime < _MOMMY_MAX_AGE )) && return 0
    fi

    mommy_update
    [ -d "$_MOMMY_DATA_DIR/responses" ]
}

_mommy_respond() {
    local status=$1 mood=${BASH_MOMMY_MOOD:-chill} state file response emote color
    local reset=$'\e[0m'
    local -a responses emotes=(❤️ 💖 💗 💓 💞) known

    if [ -n "${MOMMY_SESSION_DISABLED:-}" ]; then
        return 0
    fi
    if ! _mommy_ensure_responses; then
        echo "mommy: mommy will be quiet for this session~~" >&2
        MOMMY_SESSION_DISABLED=true
        return 0
    fi

    if [ "$status" -eq 0 ]; then
        state=positive
    else
        state=negative
    fi

    file="$_MOMMY_DATA_DIR/responses/$mood.$state"
    if [[ ! $mood =~ ^[a-z]+$ ]] || [ ! -s "$file" ]; then
        known=("$_MOMMY_DATA_DIR"/responses/*."$state")
        known=("${known[@]##*/}")
        echo "mommy: mommy doesn't know how to be \"$mood\"~ try: ${known[*]%."$state"}" >&2
        return 0
    fi

    mapfile -d '' -t responses <"$file"
    response=${responses[RANDOM % ${#responses[@]}]}
    emote=${emotes[RANDOM % ${#emotes[@]}]}

    # Quoted replacements so '&' stays literal with bash 5.2's patsub_replacement
    response=${response//"{pronoun}"/"${BASH_MOMMY_PRONOUN:-her}"}
    response=${response//"{role}"/"${BASH_MOMMY_ROLE:-mommy}"}
    response=${response//"{affectionate_term}"/"${BASH_MOMMY_AFFECTIONATE_TERM:-girl}"}
    response=${response//"{part}"/"${BASH_MOMMY_PART:-milk}"}
    response=${response//"{denigrating_term}"/"${BASH_MOMMY_DENIGRATING_TERM:-pet}"}

    if [ "$mood" = "yikes" ]; then
        color=$'\e[38;5;117m'
    else
        color=$'\e[38;5;217m'
    fi

    printf '%s%s %s%s\n' "$color" "$response" "$emote" "$reset" >&2
}

# Usage: mommy <command> [args...]
# Runs the command in the current shell and responds to how it went.
mommy() {
    if [ $# -eq 0 ]; then
        echo "usage: mommy <command> [args...]" >&2
        return 2
    fi

    "$@"
    local status=$?
    _mommy_respond "$status"
    return "$status"
}

# For PROMPT_COMMAND: responds to the exit status of the last command.
mommy_status() {
    local status=$?
    _mommy_respond "$status"
    return "$status"
}
