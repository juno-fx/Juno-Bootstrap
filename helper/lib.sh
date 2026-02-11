#!/bin/bash

# ssh-safe prompts
prompt() {
    local var_name="$1"
    local prompt_text="$2"
    local default_value="${3:-}"
    local is_password="${4:-false}"

    local read_flags="p"
    if [ "$is_password" = "true" ]; then
        read_flags="sp" # Add -s to hide input for passwords
    fi

    local input=""
    if [ -t 0 ]; then
        # stdin is a terminal, safe to read
        read -r"${read_flags?}" "${prompt_text?}" input
    elif [ -r /dev/tty ]; then
        # read from /dev/tty if available
        read -r"${read_flags?}" "${prompt_text?}" input < /dev/tty
    else
        # fallback: use default automatically
        input="$default_value"
        echo "$prompt_text $input (auto)"
    fi

    # If its a password add in a newline as -s doesn't move the cursor as expected
    [ "$is_password" = "true" ] && echo ""

    # Use default if empty
    input="${input:-$default_value}"

    # Assign to the variable name
    printf -v "$var_name" '%s' "$input"
}
