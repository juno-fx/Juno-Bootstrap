#!/bin/bash

# ssh-safe prompts
prompt() {
    local var_name="$1"
    local prompt_text="$2"
    local default_value="${3:-}"

    local input=""
    if [ -t 0 ]; then
        # stdin is a terminal, safe to read
        read -rp "$prompt_text" input
    elif [ -r /dev/tty ]; then
        # read from /dev/tty if available
        read -rp "$prompt_text" input < /dev/tty
    else
        # fallback: use default automatically
        input="$default_value"
        echo "$prompt_text $input (auto)"
    fi

    # Use default if empty
    input="${input:-$default_value}"

    # Assign to the variable name
    printf -v "$var_name" '%s' "$input"
}
