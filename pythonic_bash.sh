#!/usr/bin/env bash
#
# Pythonic Bash: Bridge shell scripts with JSON/YAML configuration
#
# License: MIT
# Author: Extracted from lakeflow-community-connectors project
# Requires: bash 4.0+, yq 4.0+
#
# Usage:
#   source pythonic_bash.sh
#   declare -A config
#   json_to_associative_array config "credentials.json"
#   echo "${config[azure_storage_account]}"

set -u  # Exit on undefined variable

# Version
PYTHONIC_BASH_VERSION="1.0.0"

# Check prerequisites
check_prerequisites() {
    local missing_deps=()
    
    # Check Bash version (need 4.0+ for associative arrays)
    if [ -z "$BASH_VERSINFO" ] || [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
        echo "❌ Error: Bash 4.0+ required (found: $BASH_VERSION)" >&2
        echo "   Install: brew install bash (macOS)" >&2
        return 1
    fi
    
    # Check yq
    if ! command -v yq &> /dev/null; then
        missing_deps+=("yq")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "❌ Error: Missing required dependencies: ${missing_deps[*]}" >&2
        echo "   Install: brew install ${missing_deps[*]} (macOS)" >&2
        echo "   or: sudo snap install ${missing_deps[*]} (Linux)" >&2
        return 1
    fi
    
    # Check yq version (need 4.0+)
    local yq_version
    yq_version=$(yq --version 2>&1 | grep -oE 'version [0-9]+' | awk '{print $2}')
    if [ -n "$yq_version" ] && [ "$yq_version" -lt 4 ]; then
        echo "⚠️  Warning: yq version 4.0+ recommended (found: $yq_version)" >&2
    fi
    
    return 0
}

# Convert JSON/YAML file to Bash associative array
#
# Args:
#   $1: Name of associative array variable (nameref)
#   $2: Path to JSON/YAML file, or omit for stdin
#
# Usage:
#   declare -A config
#   json_to_associative_array config "config.json"
#   echo "${config[database__host]}"
#
# Nested objects use "__" as separator:
#   {"database": {"host": "localhost"}} -> config[database__host]="localhost"
#
json_to_associative_array() {
    local -n json_to_associative_array_credentials="$1"  # nameref to associative array (passed by name)
    local json_file="${2:-/dev/stdin}"                    # path to JSON file (default: stdin via /dev/stdin)

    # Validate that the target variable is an associative array
    if [ "$(declare -p "$1" 2>/dev/null | grep -o 'declare -A')" != "declare -A" ]; then
        echo "❌ Error: Variable '$1' is not an associative array" >&2
        echo "   Use: declare -A $1" >&2
        return 1
    fi

    # Check if file exists (only if not stdin)
    if [ "$json_file" != "/dev/stdin" ] && [ ! -f "$json_file" ]; then
        echo "❌ Error: File not found: $json_file" >&2
        return 1
    fi

    # Note: To read from stdin, use file redirection or process substitution:
    #   json_to_associative_array myarray < file.json
    #   json_to_associative_array myarray < <(command)
    # Do NOT use direct pipe (creates subshell): echo | json_to_associative_array myarray

    while IFS='=' read -r key value; do
        value="${value%\'}"                               # strip trailing single quote
        value="${value#\'}"                               # strip leading single quote
        json_to_associative_array_credentials["$key"]="$value"
    done < <(yq -o=shell --shell-key-separator "__" "$json_file" 2>&1)
    
    if [ $? -ne 0 ]; then
        echo "❌ Error: Failed to parse $json_file" >&2
        return 1
    fi
    
    return 0
}
export -f json_to_associative_array

# Convert Bash associative array to JSON/YAML file
#
# Args:
#   $1: Name of associative array variable (nameref)
#   $2: Path to output file (optional, defaults to stdout)
#
# Usage:
#   declare -A config
#   config[app]="myapp"
#   config[database__host]="localhost"
#   associative_array_to_json_file config "output.json"
#
# Nested objects:
#   config[database__host]="localhost" -> {"database": {"host": "localhost"}}
#
associative_array_to_json_file() {
    local -n associative_array_to_json_file_credentials="$1"  # nameref to associative array (passed by name)
    local json_file="${2:-}"                                   # path to JSON file (default: stdout)

    # Validate that the source variable is an associative array
    if [ "$(declare -p "$1" 2>/dev/null | grep -o 'declare -A')" != "declare -A" ]; then
        echo "❌ Error: Variable '$1' is not an associative array" >&2
        return 1
    fi

    # Check if array is empty
    # Note: Save and restore nounset option state to avoid changing caller's environment
    # This is necessary because checking array size with namerefs can trigger
    # unbound variable errors when set -u is active
    local nounset_was_set=false
    [[ $- =~ u ]] && nounset_was_set=true
    
    set +u
    local array_size=${#associative_array_to_json_file_credentials[@]}
    $nounset_was_set && set -u
    
    if [[ $array_size -eq 0 ]]; then
        if [ -n "$json_file" ]; then
            echo '{}' > "$json_file"
        else
            echo '{}'
        fi
        return 0
    fi

    # Build yq eval expression to set each path
    # Keys with "__" separator become nested objects (e.g., "managed_identity__type" -> {"managed_identity": {"type": "..."}})
    local eval_expr=""
    # Iterate over keys in sorted order for consistent output
    # Note: Using while loop with process substitution is safe with set -u
    while IFS= read -r key; do
        local yq_path="${key//__/.}"                          # Convert __ to . for yq path notation
        local value="${associative_array_to_json_file_credentials[$key]}"
        value="${value//\"/\\\"}"                             # Escape quotes in value
        [ -n "$eval_expr" ] && eval_expr+=" | "
        eval_expr+=".${yq_path} = \"${value}\""
    done < <(printf '%s\n' "${!associative_array_to_json_file_credentials[@]}" | sort)
    
    # Stream yq output directly to file or stdout
    if [ -n "$json_file" ]; then
        mkdir -p "$(dirname "$json_file")"
        echo '{}' | yq eval "$eval_expr" -o json - > "$json_file" 2>&1
        if [ $? -ne 0 ]; then
            echo "❌ Error: Failed to write $json_file" >&2
            return 1
        fi
    else
        echo '{}' | yq eval "$eval_expr" -o json - 2>&1
        if [ $? -ne 0 ]; then
            echo "❌ Error: Failed to generate JSON" >&2
            return 1
        fi
    fi
    
    return 0
}
export -f associative_array_to_json_file

# Helper: Convert JSON to YAML file
#
# Args:
#   $1: Name of associative array variable
#   $2: Path to output YAML file
#
associative_array_to_yaml_file() {
    local -n array="$1"
    local yaml_file="$2"
    
    # Generate JSON then convert to YAML
    local json_output
    json_output=$(associative_array_to_json_file "$1")
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    mkdir -p "$(dirname "$yaml_file")"
    echo "$json_output" | yq eval -P - > "$yaml_file" 2>&1
    if [ $? -ne 0 ]; then
        echo "❌ Error: Failed to write YAML to $yaml_file" >&2
        return 1
    fi
    
    return 0
}
export -f associative_array_to_yaml_file

# Helper: Pretty-print associative array (debugging)
#
# Args:
#   $1: Name of associative array variable
#
print_associative_array() {
    local -n array="$1"
    
    # Check if array is empty (save/restore nounset state)
    local nounset_was_set=false
    [[ $- =~ u ]] && nounset_was_set=true
    
    set +u
    local array_size=${#array[@]}
    $nounset_was_set && set -u
    
    if [[ $array_size -eq 0 ]]; then
        echo "(empty array)"
        return
    fi
    
    echo "Associative array '$1' ($array_size keys):"
    
    # Iterate using while loop - process substitution is inherently safe
    while IFS= read -r key; do
        printf "  %-40s = %s\n" "$key" "${array[$key]}"
    done < <(printf '%s\n' "${!array[@]}" | sort)
}
export -f print_associative_array

# Helper: Merge two associative arrays
#
# Args:
#   $1: Name of destination array (will be modified)
#   $2: Name of source array (read-only)
#   $3: Optional prefix to add to source keys
#
# Usage:
#   declare -A base env_config
#   json_to_associative_array base "base.json"
#   json_to_associative_array env_config "prod.json"
#   merge_associative_arrays base env_config
#
merge_associative_arrays() {
    local -n dest_array="$1"
    local -n src_array="$2"
    local prefix="${3:-}"
    
    # Iterate using while loop (safe with set -u)
    while IFS= read -r key; do
        if [ -n "$prefix" ]; then
            dest_array["${prefix}${key}"]="${src_array[$key]}"
        else
            dest_array["$key"]="${src_array[$key]}"
        fi
    done < <(printf '%s\n' "${!src_array[@]}")
}
export -f merge_associative_arrays

# Helper: Validate required keys exist in associative array
#
# Args:
#   $1: Name of associative array
#   $2+: Required key names
#
# Returns: 0 if all keys present, 1 otherwise
#
# Usage:
#   validate_required_keys config "database__host" "database__port" "api_key"
#
validate_required_keys() {
    local -n array="$1"
    shift
    local required_keys=("$@")
    local missing_keys=()
    
    for key in "${required_keys[@]}"; do
        if [ -z "${array[$key]:-}" ]; then
            missing_keys+=("$key")
        fi
    done
    
    if [ ${#missing_keys[@]} -gt 0 ]; then
        echo "❌ Error: Missing required configuration keys:" >&2
        for key in "${missing_keys[@]}"; do
            echo "   - $key" >&2
        done
        return 1
    fi
    
    return 0
}
export -f validate_required_keys

# Run prerequisite check on source
if ! check_prerequisites; then
    return 1 2>/dev/null || exit 1  # return if sourced, exit if executed
fi

# Success message (can be disabled by setting PYTHONIC_BASH_QUIET=1)
if [ "${PYTHONIC_BASH_QUIET:-0}" != "1" ]; then
    echo "✅ pythonic_bash.sh v${PYTHONIC_BASH_VERSION} loaded" >&2
    echo "   Functions: json_to_associative_array, associative_array_to_json_file" >&2
fi
