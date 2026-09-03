#!/usr/bin/env bash
# ==============================================================================
# OpenShift Cluster Inventory & Credentials Parser (Pure Bash / Awk)
# ==============================================================================
# Fast, zero-dependency bash parser for clusters.yaml and credentials.local.yaml.
# Compatible with macOS default Bash 3.2 and Linux Bash 4/5.
#
# Usage:
#   ./parse_inventory.sh <config_dir> <command> [arguments...]
#
# Commands:
#   list                        - Lists all clusters in formatted table
#   get-cluster <target>        - Resolves cluster alias / fuzzy search (returns id|api|flavour|env|platform)
#   get-env-clusters <env>      - Returns cluster IDs for environment (space-separated)
#   get-credentials <cluster_id>- Returns auth_type|username|password|token|insecure
# ==============================================================================

set -euo pipefail

to_lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

to_upper() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

CONFIG_DIR="${1:-}"
COMMAND="${2:-}"

if [ -z "$CONFIG_DIR" ] || [ -z "$COMMAND" ]; then
    echo "Usage: $0 <config_dir> <list|get-cluster|get-env-clusters|get-credentials> [args...]" >&2
    exit 1
fi

CLUSTERS_FILE="${CONFIG_DIR}/clusters.yaml"
CREDS_LOCAL="${CONFIG_DIR}/credentials.local.yaml"
CREDS_EXAMPLE="${CONFIG_DIR}/credentials.example.yaml"

if [ -f "$CREDS_LOCAL" ]; then
    CREDS_FILE="$CREDS_LOCAL"
else
    CREDS_FILE="$CREDS_EXAMPLE"
fi

# ------------------------------------------------------------------------------
# Function: Parse all clusters from clusters.yaml into raw pipe-delimited lines:
# Format: id|env|platform|flavour|api_url|console_url
# ------------------------------------------------------------------------------
get_all_clusters_raw() {
    if [ ! -f "$CLUSTERS_FILE" ]; then
        return 0
    fi

    awk '
    BEGIN { in_aliases = 0; curr_id = ""; env = ""; plat = ""; flav = ""; api = ""; console = ""; }
    /^[[:space:]]*#/ { next; }
    /^[[:space:]]*$/ { next; }
    /^cluster_aliases:/ { in_aliases = 1; next; }
    /^[a-zA-Z0-9_-]+:/ && !/^cluster_aliases:/ && !/^[[:space:]]/ { in_aliases = 0; }
    in_aliases {
        if ($0 ~ /^[[:space:]]{2}[a-zA-Z0-9_-]+:[[:space:]]*$/) {
            if (curr_id != "") {
                print curr_id "|" env "|" plat "|" flav "|" api "|" console;
            }
            sub(/^[[:space:]]+/, "");
            sub(/:.*$/, "");
            curr_id = $0;
            env = ""; plat = ""; flav = ""; api = ""; console = "";
            next;
        }
        if ($0 ~ /^[[:space:]]{4}[a-zA-Z0-9_-]+:/) {
            line = $0;
            sub(/^[[:space:]]+/, "", line);
            split(line, parts, ":");
            key = parts[1];
            sub(/^[^:]*:[[:space:]]*/, "", line);
            sub(/^["'\''"]+/, "", line);
            sub(/["'\''"]+$/, "", line);
            val = line;
            if (key == "env") env = val;
            else if (key == "platform") plat = val;
            else if (key == "flavour") flav = val;
            else if (key == "api_url") api = val;
            else if (key == "console_url") console = val;
        }
    }
    END {
        if (curr_id != "") {
            print curr_id "|" env "|" plat "|" flav "|" api "|" console;
        }
    }
    ' "$CLUSTERS_FILE"
}

# ------------------------------------------------------------------------------
# Function: Parse a specific credentials block from credentials file
# Returns: auth_type|username|password|token|insecure_skip_tls_verify
# ------------------------------------------------------------------------------
get_raw_credentials_block() {
    local target_key="$1"
    if [ ! -f "$CREDS_FILE" ]; then
        echo "password|l1_operator|||false"
        return 0
    fi

    awk -v target="$target_key" '
    BEGIN { in_target = 0; auth = ""; user = ""; pass = ""; token = ""; insecure = ""; found = 0; }
    /^[[:space:]]*#/ { next; }
    /^[[:space:]]*$/ { next; }
    $0 ~ "^" target ":" {
        in_target = 1;
        found = 1;
        next;
    }
    /^[a-zA-Z0-9_-]+:/ && !/^[[:space:]]/ {
        if (in_target) {
            exit;
        }
    }
    in_target {
        line = $0;
        sub(/^[[:space:]]+/, "", line);
        split(line, parts, ":");
        k = parts[1];
        sub(/^[^:]*:[[:space:]]*/, "", line);
        sub(/^["'\''"]+/, "", line);
        sub(/["'\''"]+$/, "", line);
        v = line;
        if (k == "auth_type") auth = v;
        else if (k == "username") user = v;
        else if (k == "password") pass = v;
        else if (k == "token") token = v;
        else if (k == "insecure_skip_tls_verify") insecure = v;
    }
    END {
        if (found) {
            print auth "|" user "|" pass "|" token "|" insecure;
        }
    }
    ' "$CREDS_FILE"
}

# ------------------------------------------------------------------------------
# Command Handlers
# ------------------------------------------------------------------------------

case "$COMMAND" in
    list)
        printf "%-12s | %-10s | %-16s | %-14s | %s\n" "ENVIRONMENT" "PLATFORM" "FLAVOUR" "CLUSTER ID" "API URL"
        printf "%s\n" "------------------------------------------------------------------------------------------------"
        while IFS='|' read -r c_id c_env c_plat c_flav c_api c_console; do
            [ -z "$c_id" ] && continue
            printf "%-12s | %-10s | %-16s | %-14s | %s\n" "$c_env" "$c_plat" "$c_flav" "$c_id" "$c_api"
        done < <(get_all_clusters_raw)
        ;;

    get-cluster)
        TARGET="${3:-}"
        if [ -z "$TARGET" ]; then
            echo "Error: Missing cluster target" >&2
            exit 1
        fi

        TARGET_LOWER=$(to_lower "$TARGET")
        CLEAN_TARGET=$(echo "$TARGET_LOWER" | tr -cd '[:alnum:]')
        MATCH_FOUND=""

        # Pass 1: Exact match by cluster ID or environment
        while IFS='|' read -r c_id c_env c_plat c_flav c_api c_console; do
            [ -z "$c_id" ] && continue
            c_id_lower=$(to_lower "$c_id")
            c_env_lower=$(to_lower "$c_env")
            if [ "$c_id_lower" = "$TARGET_LOWER" ] || [ "$c_env_lower" = "$TARGET_LOWER" ]; then
                MATCH_FOUND="${c_id}|${c_api}|${c_flav}|${c_env}|${c_plat}"
                break
            fi
        done < <(get_all_clusters_raw)

        # Pass 2: Fuzzy match (strip spaces and hyphens)
        if [ -z "$MATCH_FOUND" ]; then
            while IFS='|' read -r c_id c_env c_plat c_flav c_api c_console; do
                [ -z "$c_id" ] && continue
                clean_id=$(to_lower "$c_id" | tr -cd '[:alnum:]')
                if [[ "$clean_id" == *"$CLEAN_TARGET"* ]] || [[ "$CLEAN_TARGET" == *"$clean_id"* ]]; then
                    MATCH_FOUND="${c_id}|${c_api}|${c_flav}|${c_env}|${c_plat}"
                    break
                fi
            done < <(get_all_clusters_raw)
        fi

        # Pass 3: Environment partial match (e.g. "dev" -> first dev cluster)
        if [ -z "$MATCH_FOUND" ]; then
            while IFS='|' read -r c_id c_env c_plat c_flav c_api c_console; do
                [ -z "$c_id" ] && continue
                c_id_lower=$(to_lower "$c_id")
                if [[ "$c_id_lower" == *"$TARGET_LOWER"* ]]; then
                    MATCH_FOUND="${c_id}|${c_api}|${c_flav}|${c_env}|${c_plat}"
                    break
                fi
            done < <(get_all_clusters_raw)
        fi

        if [ -n "$MATCH_FOUND" ]; then
            echo "$MATCH_FOUND"
            exit 0
        else
            echo "Cluster '$TARGET' not found" >&2
            exit 1
        fi
        ;;

    get-env-clusters)
        ENV_TARGET="${3:-dev}"
        ENV_CLEAN=$(to_lower "$ENV_TARGET")
        
        CLUSTERS_OUT=()
        while IFS='|' read -r c_id c_env c_plat c_flav c_api c_console; do
            [ -z "$c_id" ] && continue
            c_env_lower=$(to_lower "$c_env")
            if [ "$ENV_CLEAN" = "all" ] || [ "$ENV_CLEAN" = "everything" ]; then
                CLUSTERS_OUT+=("$c_id")
            elif [ "$c_env_lower" = "$ENV_CLEAN" ]; then
                CLUSTERS_OUT+=("$c_id")
            elif [ "$ENV_CLEAN" = "staging" ] && [ "$c_env_lower" = "uat" ]; then
                CLUSTERS_OUT+=("$c_id")
            elif [ "$ENV_CLEAN" = "uat" ] && [ "$c_env_lower" = "staging" ]; then
                CLUSTERS_OUT+=("$c_id")
            fi
        done < <(get_all_clusters_raw)

        echo "${CLUSTERS_OUT[*]}"
        ;;

    get-credentials)
        CLUSTER_ID="${3:-}"
        if [ -z "$CLUSTER_ID" ]; then
            echo "Error: Missing cluster ID" >&2
            exit 1
        fi

        # 1. Fetch cluster profile (env, platform, flavour)
        c_env=""
        c_plat=""
        c_flav=""
        cluster_id_lower=$(to_lower "$CLUSTER_ID")
        while IFS='|' read -r r_id r_env r_plat r_flav r_api r_console; do
            r_id_lower=$(to_lower "$r_id")
            if [ "$r_id_lower" = "$cluster_id_lower" ]; then
                c_env="$r_env"
                c_plat="$r_plat"
                c_flav="$r_flav"
                break
            fi
        done < <(get_all_clusters_raw)

        # 2. Check direct cluster ID override in credentials
        raw_creds=$(get_raw_credentials_block "$CLUSTER_ID")

        # 3. Check composite profile key: <env>-<platform>-<flavour>
        if [ -z "$raw_creds" ] && [ -n "$c_env" ] && [ -n "$c_plat" ] && [ -n "$c_flav" ]; then
            composite_key="${c_env}-${c_plat}-${c_flav}"
            raw_creds=$(get_raw_credentials_block "$composite_key")
        fi

        # 4. Fallback to default_credentials
        default_raw=$(get_raw_credentials_block "default_credentials")

        IFS='|' read -r def_auth def_user def_pass def_token def_insecure <<< "${default_raw:-password|l1_operator|||false}"
        IFS='|' read -r c_auth c_user c_pass c_token c_insecure <<< "${raw_creds:-||||}"

        final_auth="${c_auth:-$def_auth}"
        final_user="${c_user:-$def_user}"
        final_pass="${c_pass:-$def_pass}"
        final_token="${c_token:-$def_token}"
        final_insecure="${c_insecure:-$def_insecure}"

        [ -z "$final_auth" ] && final_auth="password"
        [ -z "$final_insecure" ] && final_insecure="false"

        echo "${final_auth}|${final_user}|${final_pass}|${final_token}|${final_insecure}"
        ;;

    *)
        echo "Unknown command: $COMMAND" >&2
        echo "Supported commands: list, get-cluster, get-env-clusters, get-credentials" >&2
        exit 1
        ;;
esac

