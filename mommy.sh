#!/bin/bash
# shellcheck disable=SC2294,SC1090

mommy() (
    # Stop if the env var MOMMY_SESSION_DISABLED is set to true
    if [ -n "${MOMMY_SESSION_DISABLED}" ]; then
        return
    fi

    # First, some definitions
    PARSED_RESPONSES_PATH=$HOME/.local/share/bash-mommy/responses.sh
    COLORS_LIGHT_PINK='\e[38;5;217m'
    COLORS_LIGHT_BLUE='\e[38;5;117m'
    COLORS_RESET='\e[0m'
    emotes=(❤️ 💖 💗 💓 💞)
    
    update() (
        responses_cdn='https://cdn.jsdelivr.net/gh/Gankra/cargo-mommy/responses.json'
        upstream_repo='https://api.github.com/repos/Gankra/cargo-mommy'

        # Make the shell-mommy directory if it doesn't exist somehow
        if [ ! -d "$HOME/.local/share/bash-mommy" ]; then
            mkdir -p "$HOME/.local/share/bash-mommy"
        fi

        # Some command definitions
        JQ=jq

        # Check if jq exists for the user.
        if ! command -v $JQ &>/dev/null; then
            JQ=$HOME/.local/share/bash-mommy/mommy-jq
            # We check if our own jq binary exists
            if [ -f "$HOME/.local/share/bash-mommy/mommy-jq" ]; then
                # We can do nothing here
                :
            else
                # If not, we download it from 1bin
                curl -SsL -o "$HOME/.local/share/bash-mommy/mommy-jq" 'https://1bin.org/Linux/jq'
                chmod +x "$HOME/.local/share/bash-mommy/mommy-jq"
            fi
        fi

        # only continue if we successfully got a response
        if response=$(curl -SsL $responses_cdn); then
            :
        else
            echo "mommy: couldn't get responses~~"
            export MOMMY_SESSION_DISABLED=true
        fi
        echo "MOMMY_LAST_UPSTREAM_UPDATE=$(curl -SsL "$upstream_repo" | $JQ -r '.pushed_at')" > "$PARSED_RESPONSES_PATH"
        echo >> "$PARSED_RESPONSES_PATH"

        # First we use jq to get the moods
        moods=$(echo "$response" | $JQ -r '.moods | keys[]')
        # Now, for each mood, we have to get the "positive", "negative" and "overflow" responses
        possible_responses="positive negative overflow"
        for mood in $moods; do
            for possible_response in $possible_responses; do
                # Convert mood and possible_response to uppercase
                this_resps=$(echo "$response" | $JQ ".moods.$mood.$possible_response | .[]")
                echo "MOMMY_${mood^^}_${possible_response^^}=($this_resps)" >> "$PARSED_RESPONSES_PATH"
                echo >> "$PARSED_RESPONSES_PATH"
            done
        done

        # Write the last pushed date of upstream into the PARSED_RESPONSES_PATH
        echo "mommy: manifestation completed~~"
    )


    respond() (
        # Check if the user have overriden any of our env
        if [ -z "$BASH_MOMMY_MOOD" ]; then
            BASH_MOMMY_MOOD="chill"
        fi
        if [ -z "$BASH_MOMMY_PRONOUN" ]; then
            BASH_MOMMY_PRONOUN="her"
        fi
        if [ -z "$BASH_MOMMY_ROLE" ]; then
            BASH_MOMMY_ROLE="mommy"
        fi
        if [ -z "$BASH_MOMMY_AFFECTIONATE_TERM" ]; then
            BASH_MOMMY_AFFECTIONATE_TERM="girl"
        fi

        # These only gets enabled on "yikes"
        if [ "$BASH_MOMMY_MOOD" = "yikes" ]; then
            if [ -z "$BASH_MOMMY_PART" ]; then
                BASH_MOMMY_PART="milk"
            fi
            if [ -z "$BASH_MOMMY_DENIGRATING_TERM" ]; then
                BASH_MOMMY_DENIGRATING_TERM="pet"
            fi
        fi

        # check if $1 == true
        if [ "$1" = true ]; then
            STATE="positive"
        else 
            STATE="negative"
        fi

        # gacha
        # Define the dynamic array name based on mood and state
        mommy_access_string="MOMMY_${BASH_MOMMY_MOOD^^}_${STATE^^}"
        resp_count=$(eval "echo \${#${mommy_access_string}[@]}")

        # Generate a random number between 0 and the number of members
        random=$((RANDOM % resp_count))

        # Access the array element dynamically
        response=$(eval "echo \${${mommy_access_string}[$random]}")

        # Pick a random emote
        random_emote=$((RANDOM % 4))
        emote=${emotes[$random_emote]}

        # Add the emote to the response
        response="$response $emote"

        # colors
        if [ "$BASH_MOMMY_MOOD" = "yikes" ]; then
            echo -ne "${COLORS_LIGHT_BLUE}"
        else
            echo -ne "${COLORS_LIGHT_PINK}"
        fi

        printf '%b\n' "$response" | sed -e "s/{pronoun}/$BASH_MOMMY_PRONOUN/g" \
        -e "s/{role}/$BASH_MOMMY_ROLE/g" \
        -e "s/{affectionate_term}/$BASH_MOMMY_AFFECTIONATE_TERM/g" \
        -e "s/{part}/$BASH_MOMMY_PART/g" \
        -e "s/{denigrating_term}/$BASH_MOMMY_DENIGRATING_TERM/g"

        echo -ne "${COLORS_RESET}"
    )

    success() (
        respond true
    )

    failure() (
        respond false
    )

    # Check if the response file exists
    if [ ! -f "$PARSED_RESPONSES_PATH" ]; then
        update
    fi

    source "$PARSED_RESPONSES_PATH"

    # eval "$@"
    if eval "$@"; then
        success
    else
        failure
    fi
    return $?
)