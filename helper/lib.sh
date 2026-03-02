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

check_host_memory(){
    installed_memory=""
    while read -r label value _; do
    if [[ "$label" == "MemTotal:" ]]; then
        installed_memory=$(( value / 1048576 )) # Get it in GB for ease
        break
    fi
    done < /proc/meminfo

    if [[ "$installed_memory" -lt $MEMORY_LIMIT_GB ]]; then
        echo "❌ Installed memory is less than minimum requirements: $installed_memory GB < $MEMORY_LIMIT_GB GB"
        return 1;
    fi
    echo "✅ Host meets minimum installed Memory"
    return 0;
}

check_host_cpu(){
    count=0
    while read -r line; do
        # Matching "processor" at the start of the line
        if [[ "$line" =~ ^processor ]]; then
            count=$((count + 1))
        fi
    done < /proc/cpuinfo
    if [[ $count -lt "$CPU_LIMIT_CORE" ]]; then
        echo "❌ Available CPU is less than minimum requirements: $count cores < $CPU_LIMIT_CORE cores"
        return 1;
    fi
    echo "✅ Host meets minimum CPU core count"
    return 0;
}

check_host_resources(){
    local return_code=0
    if ! check_host_memory; then
        return_code=1
    fi
    
    if ! check_host_cpu; then
        return_code=1
    fi

    if [[ $return_code -ne 0 ]]; then 
        prompt CONFIRM "❓ Continue with installation anyway? [y/N]: " "N"
        case "$CONFIRM" in
            [Yy])
                echo "👍 Proceeding... Please be aware there may be resource allocation issues during and after install"
                ;;
            *)
                echo "❌ Installation aborted by user."
                exit 1
                ;;
        esac
    else
        echo "🏆 All resource requirements met!"
    fi
}