#!/bin/bash

# ============================================================================
# SCP File Transfer Manager - Interactive Bash Utility
# A robust, colorful, and feature-rich SCP file transfer tool
# ============================================================================

VERSION="2.0.0"
SCRIPT_NAME="SCP Manager"

# Color definitions
declare -A COLORS=(
    [RED]='\033[0;31m'
    [GREEN]='\033[0;32m'
    [YELLOW]='\033[0;33m'
    [BLUE]='\033[0;34m'
    [PURPLE]='\033[0;35m'
    [CYAN]='\033[0;36m'
    [WHITE]='\033[0;37m'
    [BOLD]='\033[1m'
    [UNDERLINE]='\033[4m'
    [BLINK]='\033[5m'
    [REVERSE]='\033[7m'
    [BOLD_RED]='\033[1;31m'
    [BOLD_GREEN]='\033[1;32m'
    [BOLD_YELLOW]='\033[1;33m'
    [BOLD_BLUE]='\033[1;34m'
    [BOLD_PURPLE]='\033[1;35m'
    [BOLD_CYAN]='\033[1;36m'
    [BOLD_WHITE]='\033[1;37m'
    [BG_RED]='\033[41m'
    [BG_GREEN]='\033[42m'
    [BG_YELLOW]='\033[43m'
    [BG_BLUE]='\033[44m'
    [BG_PURPLE]='\033[45m'
    [BG_CYAN]='\033[46m'
    [BG_WHITE]='\033[47m'
    [RESET]='\033[0m'
)

# Global variables
DEBUG=false
VERBOSE=false
SSH_KEY=""
REMOTE_HOST=""
REMOTE_USER=""
REMOTE_PORT="22"
REMOTE_PASSWORD=""
LOCAL_PATH=""
REMOTE_PATH=""
CONNECTION_TIMEOUT="10"

# Last validated connection tracking
LAST_VALIDATED_NAME=""
LAST_VALIDATED_HOST=""
LAST_VALIDATED_USER=""
LAST_VALIDATED_PORT=""
LAST_VALIDATED_AUTH_TYPE=""
LAST_VALIDATED_TIMESTAMP=""
LAST_VALIDATION_SUCCESS=""
CONNECTIONS_DIR="$HOME/.scp_manager"
SAVED_CONNECTIONS_FILE="$CONNECTIONS_DIR/connections.json"
SAVED_PATHS_FILE="$CONNECTIONS_DIR/saved_paths.json"

# Utility functions
print_color() {
    local color="$1"
    local message="$2"
    echo -e "${COLORS[$color]}$message${COLORS[RESET]}"
}

print_header() {
    clear
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')
    print_color "BOLD_CYAN" "════════════════════════════════════════════════════════════════════════════════════"
    print_color "BOLD_CYAN" "                        🚀 SCP FILE TRANSFER MANAGER 🚀"
    print_color "BOLD_CYAN" "                  Advanced Interactive File Transfer Utility"
    print_color "BOLD_CYAN" "                           Version $VERSION"
    print_color "BOLD_CYAN" "                        ⏰ $current_time"
    print_color "BOLD_CYAN" "════════════════════════════════════════════════════════════════════════════════════"
    echo
}

print_section_header() {
    local title="$1"
    local current_time=$(date '+%H:%M:%S')
    echo
    print_color "BOLD_BLUE" "────────────────────────────────────────────────────────────────────────────────────"
    print_color "BOLD_WHITE" "  $title ⏰ $current_time"
    print_color "BOLD_BLUE" "────────────────────────────────────────────────────────────────────────────────────"
    echo
}

print_menu_option() {
    local number="$1"
    local title="$2"
    local description="$3"
    printf "${COLORS[BOLD_GREEN]}[%s]${COLORS[RESET]} ${COLORS[BOLD_WHITE]}%-25s${COLORS[RESET]} ${COLORS[YELLOW]}%s${COLORS[RESET]}\n" "$number" "$title" "$description"
}

print_status() {
    local status="$1"
    local message="$2"
    case "$status" in
        "SUCCESS") print_color "BOLD_GREEN" "✅ $message" ;;
        "ERROR") print_color "BOLD_RED" "❌ $message" ;;
        "WARNING") print_color "BOLD_YELLOW" "⚠️  $message" ;;
        "INFO") print_color "BOLD_CYAN" "ℹ️  $message" ;;
        "DEBUG") [[ "$DEBUG" == true ]] && print_color "PURPLE" "🐛 DEBUG: $message" ;;
    esac
}

print_progress() {
    local message="$1"
    print_color "BOLD_YELLOW" "⏳ $message"
}

debug_log() {
    [[ "$DEBUG" == true ]] && print_status "DEBUG" "$1"
}

prompt_input() {
    local prompt="$1"
    local default="$2"
    local response
    
    echo
    if [[ -n "$default" ]]; then
        echo -n "❯ $prompt [default: $default]: "
    else
        echo -n "❯ $prompt: "
    fi
    
    read response
    echo "${response:-$default}"
}

prompt_password() {
    local prompt="$1"
    echo
    echo -n "🔐 $prompt: "
    read -s response
    echo
    echo "$response"
}

prompt_menu_choice() {
    local max_option="$1"
    local choice
    
    debug_log "Prompting for menu choice (1-$max_option)"
    
    while true; do
        choice=$(prompt_input "Select option (1-$max_option)")
        debug_log "User entered: '$choice'"
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "$max_option" ]]; then
            echo "$choice"
            break
        else
            print_status "ERROR" "Invalid choice. Please enter a number between 1 and $max_option"
        fi
    done
}

press_enter_to_continue() {
    echo
    print_color "BOLD_WHITE" "Press Enter to continue..."
    read -r
}

# Connection Management Functions
initialize_connections_dir() {
    if [[ ! -d "$CONNECTIONS_DIR" ]]; then
        mkdir -p "$CONNECTIONS_DIR"
        debug_log "Created connections directory: $CONNECTIONS_DIR"
    fi
    
    if [[ ! -f "$SAVED_CONNECTIONS_FILE" ]]; then
        echo "[]" > "$SAVED_CONNECTIONS_FILE"
        debug_log "Created connections file: $SAVED_CONNECTIONS_FILE"
    fi
    
    if [[ ! -f "$SAVED_PATHS_FILE" ]]; then
        echo '{"upload_paths": [], "download_paths": []}' > "$SAVED_PATHS_FILE"
        debug_log "Created saved paths file: $SAVED_PATHS_FILE"
    fi
}

generate_connection_id() {
    # Generate a random number between 1 and 1000 for unique connection ID
    echo $((RANDOM % 1000 + 1))
}

save_connection_data() {
    local connection_name="$1"
    local host="$2"
    local user="$3"
    local port="$4"
    local ssh_key="$5"
    local remote_path="$6"
    local protocol="ssh"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    initialize_connections_dir
    
    # Create connection JSON object
    local connection_json=$(cat << EOF
{
    "id": "$(generate_connection_id)",
    "name": "$connection_name",
    "host": "$host",
    "user": "$user", 
    "port": "$port",
    "ssh_key": "$ssh_key",
    "remote_path": "$remote_path",
    "protocol": "$protocol",
    "created": "$timestamp",
    "last_used": "$timestamp"
}
EOF
)
    
    # Read existing connections
    local existing_connections=""
    if [[ -f "$SAVED_CONNECTIONS_FILE" ]] && [[ -s "$SAVED_CONNECTIONS_FILE" ]]; then
        existing_connections=$(cat "$SAVED_CONNECTIONS_FILE")
    else
        existing_connections="[]"
    fi
    
    # Generate new random ID and add connection (no duplicate checking needed with random IDs)
    local updated_connections
    updated_connections=$(echo "$existing_connections" | jq --argjson conn "$connection_json" \
        '. + [$conn]')
    debug_log "Added new connection with random ID"
    
    echo "$updated_connections" > "$SAVED_CONNECTIONS_FILE"
    print_status "SUCCESS" "Connection saved: $connection_name"
}

load_connection_by_id() {
    local connection_id="$1"
    
    if [[ ! -f "$SAVED_CONNECTIONS_FILE" ]]; then
        return 1
    fi
    
    local connection_data=$(cat "$SAVED_CONNECTIONS_FILE" | jq -r ".[] | select(.id == \"$connection_id\")")
    
    if [[ -n "$connection_data" ]]; then
        REMOTE_HOST=$(echo "$connection_data" | jq -r '.host')
        REMOTE_USER=$(echo "$connection_data" | jq -r '.user')
        REMOTE_PORT=$(echo "$connection_data" | jq -r '.port')
        SSH_KEY=$(echo "$connection_data" | jq -r '.ssh_key')
        REMOTE_PATH=$(echo "$connection_data" | jq -r '.remote_path')
        
        # Update last_used timestamp
        local updated_connections=$(cat "$SAVED_CONNECTIONS_FILE" | jq \
            --arg id "$connection_id" \
            --arg timestamp "$(date '+%Y-%m-%d %H:%M:%S')" \
            'map(if .id == $id then .last_used = $timestamp else . end)')
        echo "$updated_connections" > "$SAVED_CONNECTIONS_FILE"
        
        debug_log "Loaded connection: $connection_id"
        return 0
    else
        return 1
    fi
}

list_saved_connections() {
    initialize_connections_dir
    
    if [[ ! -f "$SAVED_CONNECTIONS_FILE" ]] || [[ ! -s "$SAVED_CONNECTIONS_FILE" ]]; then
        print_status "INFO" "No saved connections found"
        return 1
    fi
    
    local connections_count=$(cat "$SAVED_CONNECTIONS_FILE" | jq 'length')
    
    if [[ "$connections_count" -eq 0 ]]; then
        print_status "INFO" "No saved connections found"
        return 1
    fi
    
    print_section_header "Saved Connections ($connections_count found)"
    
    echo
    printf "%-3s %-20s %-15s %-10s %-20s %-15s\n" "No." "Name" "Host" "User" "SSH Key/Password" "Last Used"
    print_color "BOLD_BLUE" "$(printf '%*s' 85 | tr ' ' '=')"
    
    local counter=1
    cat "$SAVED_CONNECTIONS_FILE" | jq -r '.[] | "\(.name)|\(.host)|\(.user)|\(.ssh_key)|\(.last_used)"' | \
    while IFS='|' read -r name host user ssh_key last_used; do
        local key_display="${ssh_key##*/}"  # Show only filename
        [[ -z "$key_display" ]] && key_display="Password"
        printf "%-3s %-20s %-15s %-10s %-20s %-15s\n" "$counter" "$name" "$host" "$user" "$key_display" "$last_used"
        ((counter++))
    done
    
    return 0
}

delete_connection() {
    local connection_id="$1"
    
    if [[ ! -f "$SAVED_CONNECTIONS_FILE" ]]; then
        print_status "ERROR" "No connections file found"
        return 1
    fi
    
    local updated_connections=$(cat "$SAVED_CONNECTIONS_FILE" | jq \
        --arg id "$connection_id" \
        'map(select(.id != $id))')
    
    echo "$updated_connections" > "$SAVED_CONNECTIONS_FILE"
    print_status "SUCCESS" "Connection deleted: $connection_id"
}

# SSH Connection Management
test_ssh_connection() {
    local host="$1"
    local user="$2"
    local port="$3"
    local key="$4"
    
    debug_log "Testing SSH connection to $user@$host:$port"
    
    local ssh_opts="-o ConnectTimeout=$CONNECTION_TIMEOUT -o BatchMode=yes -o StrictHostKeyChecking=no"
    
    if [[ -n "$key" ]]; then
        ssh_opts="$ssh_opts -i $key"
    fi
    
    if ssh $ssh_opts -p "$port" "$user@$host" "echo 'Connection successful'" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to record connection validation attempts
record_connection_validation() {
    local connection_name="$1"
    local host="$2"
    local user="$3"
    local port="$4"
    local auth_type="$5"  # "SSH Key" or "Password"
    local success="$6"    # true or false
    
    LAST_VALIDATED_NAME="$connection_name"
    LAST_VALIDATED_HOST="$host"
    LAST_VALIDATED_USER="$user"
    LAST_VALIDATED_PORT="$port"
    LAST_VALIDATED_AUTH_TYPE="$auth_type"
    LAST_VALIDATED_TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
    LAST_VALIDATION_SUCCESS="$success"
    
    # Also save to a file for persistence across sessions
    local validation_file="$HOME/.scp_manager/last_validation.json"
    mkdir -p "$(dirname "$validation_file")"
    
    cat > "$validation_file" << EOF
{
    "name": "$connection_name",
    "host": "$host",
    "user": "$user",
    "port": "$port",
    "auth_type": "$auth_type",
    "timestamp": "$LAST_VALIDATED_TIMESTAMP",
    "success": $success
}
EOF
}

# Function to load last validation from file
load_last_validation() {
    local validation_file="$HOME/.scp_manager/last_validation.json"
    
    if [[ -f "$validation_file" ]]; then
        LAST_VALIDATED_NAME=$(jq -r '.name // ""' "$validation_file" 2>/dev/null)
        LAST_VALIDATED_HOST=$(jq -r '.host // ""' "$validation_file" 2>/dev/null)
        LAST_VALIDATED_USER=$(jq -r '.user // ""' "$validation_file" 2>/dev/null)
        LAST_VALIDATED_PORT=$(jq -r '.port // ""' "$validation_file" 2>/dev/null)
        LAST_VALIDATED_AUTH_TYPE=$(jq -r '.auth_type // ""' "$validation_file" 2>/dev/null)
        LAST_VALIDATED_TIMESTAMP=$(jq -r '.timestamp // ""' "$validation_file" 2>/dev/null)
        LAST_VALIDATION_SUCCESS=$(jq -r '.success // ""' "$validation_file" 2>/dev/null)
    fi
}

test_ssh_connection_with_password() {
    local host="$1"
    local user="$2"
    local port="$3"
    local password="$4"
    
    debug_log "Testing SSH connection with password to $user@$host:$port"
    
    # Use sshpass if available, otherwise use expect
    if command -v sshpass &> /dev/null; then
        local ssh_opts="-o ConnectTimeout=$CONNECTION_TIMEOUT -o StrictHostKeyChecking=no"
        if sshpass -p "$password" ssh $ssh_opts -p "$port" "$user@$host" "echo 'Connection successful'" &>/dev/null; then
            return 0
        else
            return 1
        fi
    else
        # Fallback to expect if sshpass is not available
        if command -v expect &> /dev/null; then
            expect -c "
                set timeout $CONNECTION_TIMEOUT
                spawn ssh -o StrictHostKeyChecking=no -p $port $user@$host echo 'Connection successful'
                expect {
                    \"password:\" { send \"$password\r\"; exp_continue }
                    \"Password:\" { send \"$password\r\"; exp_continue }
                    \"Connection successful\" { exit 0 }
                    timeout { exit 1 }
                    eof { exit 1 }
                }
            " &>/dev/null
            return $?
        else
            # If neither sshpass nor expect are available, use interactive SSH
            print_status "WARNING" "sshpass and expect not found. Testing with interactive SSH..."
            echo "Please enter password when prompted:"
            
            local ssh_opts="-o ConnectTimeout=$CONNECTION_TIMEOUT -o StrictHostKeyChecking=no"
            if ssh $ssh_opts -p "$port" "$user@$host" "echo 'Connection successful'" 2>/dev/null; then
                return 0
            else
                return 1
            fi
        fi
    fi
}

setup_ssh_connection() {
    print_section_header "SSH Connection Setup"
    
    # Get connection name
    echo
    echo -n "❯ Connection name (for easy identification): "
    read CONNECTION_NAME
    
    # Get remote host
    echo -n "❯ Remote hostname or IP address: "
    read REMOTE_HOST
    
    # Get remote user
    echo -n "❯ Remote username [default: ubuntu]: "
    read REMOTE_USER
    REMOTE_USER="${REMOTE_USER:-ubuntu}"
    
    # Get remote port
    echo -n "❯ SSH port [default: 22]: "
    read REMOTE_PORT
    REMOTE_PORT="${REMOTE_PORT:-22}"
    
    # Get default remote path
    echo -n "❯ Default remote path [default: ~]: "
    read REMOTE_PATH
    REMOTE_PATH="${REMOTE_PATH:-~}"
    
    print_color "BOLD_YELLOW" "\nAuthentication method:"
    print_menu_option "1" "SSH Key" "Use SSH private key file"
    print_menu_option "2" "Password" "Use password authentication"
    print_menu_option "3" "Default SSH Key" "Use ~/.ssh/id_rsa"
    
    echo
    local auth_choice
    
    # Direct prompt without command substitution
    while true; do
        echo -n "❯ Select option (1-3): "
        read auth_choice
        if [[ "$auth_choice" =~ ^[0-9]+$ ]] && [[ "$auth_choice" -ge 1 ]] && [[ "$auth_choice" -le 3 ]]; then
            break
        else
            echo "❌ Invalid choice. Please enter a number between 1 and 3"
        fi
    done
    
    local use_password=false
    local password=""
    
    case "$auth_choice" in
        1)
            echo -n "❯ Path to SSH private key [default: $HOME/.ssh/id_rsa]: "
            read SSH_KEY
            SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_rsa}"
            if [[ ! -f "$SSH_KEY" ]]; then
                print_status "ERROR" "SSH key file not found: $SSH_KEY"
                return 1
            fi
            ;;
        2)
            SSH_KEY=""
            use_password=true
            echo -n "❯ Enter password for $REMOTE_USER@$REMOTE_HOST: "
            read -s password
            echo  # Add newline after hidden password input
            if [[ -z "$password" ]]; then
                print_status "ERROR" "Password cannot be empty"
                return 1
            fi
            ;;
        3)
            SSH_KEY="$HOME/.ssh/id_rsa"
            if [[ ! -f "$SSH_KEY" ]]; then
                print_status "WARNING" "Default SSH key not found, will use password authentication"
                SSH_KEY=""
                use_password=true
                echo -n "❯ Enter password for $REMOTE_USER@$REMOTE_HOST: "
                read -s password
                echo  # Add newline after hidden password input
                if [[ -z "$password" ]]; then
                    print_status "ERROR" "Password cannot be empty"
                    return 1
                fi
            fi
            ;;
    esac
    
    echo
    print_progress "Testing SSH connection..."
    
    # Test connection based on authentication method
    local connection_successful=false
    
    if [[ "$use_password" == true ]]; then
        # Test password-based connection
        if test_ssh_connection_with_password "$REMOTE_HOST" "$REMOTE_USER" "$REMOTE_PORT" "$password"; then
            connection_successful=true
        fi
    else
        # Test key-based connection
        if test_ssh_connection "$REMOTE_HOST" "$REMOTE_USER" "$REMOTE_PORT" "$SSH_KEY"; then
            connection_successful=true
        fi
    fi
    
    # Record the validation attempt
    local auth_type_display
    if [[ "$use_password" == true ]]; then
        auth_type_display="Password"
    else
        auth_type_display="SSH Key"
    fi
    
    record_connection_validation "$CONNECTION_NAME" "$REMOTE_HOST" "$REMOTE_USER" "$REMOTE_PORT" "$auth_type_display" "$connection_successful"
    
    if [[ "$connection_successful" == true ]]; then
        print_status "SUCCESS" "SSH connection established successfully!"
        echo
        echo -n "❯ Save this connection? (Y/n): "
        read save_choice
        if [[ "$save_choice" =~ ^[Nn] ]]; then
            print_status "INFO" "Connection not saved"
            return 0
        fi
        
        # Save connection with all details (but not the password for security)
        save_connection_data "$CONNECTION_NAME" "$REMOTE_HOST" "$REMOTE_USER" "$REMOTE_PORT" "$SSH_KEY" "$REMOTE_PATH"
        
        if [[ "$use_password" == true ]]; then
            print_status "INFO" "Connection saved (password authentication)"
            print_color "YELLOW" "💡 Note: Passwords are not saved for security. You'll need to enter it each time."
        else
            print_status "INFO" "Connection saved (SSH key authentication)"
        fi
        
        return 0
    else
        print_status "ERROR" "Failed to establish SSH connection"
        echo
        print_color "YELLOW" "💡 Troubleshooting tips:"
        print_color "YELLOW" "   • Verify the hostname/IP is correct: $REMOTE_HOST"
        print_color "YELLOW" "   • Check if the port is accessible: $REMOTE_PORT"
        print_color "YELLOW" "   • Confirm the username is correct: $REMOTE_USER"
        if [[ "$use_password" == true ]]; then
            print_color "YELLOW" "   • Verify the password is correct"
            print_color "YELLOW" "   • Check if password authentication is enabled on the server"
        else
            print_color "YELLOW" "   • Verify the SSH key path: $SSH_KEY"
            print_color "YELLOW" "   • Check if the public key is authorized on the server"
        fi
        
        echo
        echo -n "❯ Try again with different settings? (y/N): "
        read retry_choice
        if [[ "$retry_choice" =~ ^[Yy] ]]; then
            setup_ssh_connection
        fi
        
        return 1
    fi
}

# Legacy function - replaced by save_connection_data

load_saved_connections() {
    initialize_connections_dir
    
    if [[ ! -f "$SAVED_CONNECTIONS_FILE" ]] || [[ ! -s "$SAVED_CONNECTIONS_FILE" ]]; then
        print_status "INFO" "No saved connections found"
        return 1
    fi
    
    local connections_count=$(cat "$SAVED_CONNECTIONS_FILE" | jq 'length')
    
    if [[ "$connections_count" -eq 0 ]]; then
        print_status "INFO" "No saved connections found"
        return 1
    fi
    
    print_section_header "Saved Connections"
    
    echo
    local connection_ids=()
    readarray -t connection_ids < <(cat "$SAVED_CONNECTIONS_FILE" | jq -r '.[].id')
    
    # Display connections without using subshell
    local counter=1
    while read -r line; do
        IFS='|' read -r name host user <<< "$line"
        print_menu_option "$counter" "$name" "$user@$host"
        ((counter++))
    done < <(cat "$SAVED_CONNECTIONS_FILE" | jq -r '.[] | "\(.name)|\(.host)|\(.user)"')
    
    echo
    echo "[n] New Connection - Setup a new SSH connection"
    
    echo
    local choice
    
    # Direct prompt without command substitution
    while true; do
        echo -n "❯ Select connection (1-$connections_count) or 'n' for new connection: "
        read choice
        if [[ "$choice" == "n" ]] || [[ "$choice" == "N" ]]; then
            return 1  # New connection
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "$connections_count" ]]; then
            break
        else
            echo "❌ Invalid choice. Please enter a number between 1 and $connections_count, or 'n' for new connection"
        fi
    done
    
    local selected_id="${connection_ids[$((choice-1))]}"
    
    print_progress "Loading saved connection..."
    if load_connection_by_id "$selected_id"; then
        print_progress "Testing saved connection..."
        if test_ssh_connection "$REMOTE_HOST" "$REMOTE_USER" "$REMOTE_PORT" "$SSH_KEY"; then
            print_status "SUCCESS" "Connected to saved connection: ${selected_id}"
            return 0
        else
            print_status "ERROR" "Failed to connect to saved connection"
            return 1
        fi
    else
        print_status "ERROR" "Failed to load connection data"
        return 1
    fi
}

# Connection selection helper
select_saved_connection() {
    local purpose="$1"  # "upload", "download", "browse"
    
    initialize_connections_dir
    
    if [[ ! -f "$SAVED_CONNECTIONS_FILE" ]] || [[ ! -s "$SAVED_CONNECTIONS_FILE" ]]; then
        print_status "ERROR" "No saved connections found. Please setup a connection first (Option 1)."
        return 1
    fi
    
    local connections_count=$(cat "$SAVED_CONNECTIONS_FILE" | jq 'length')
    
    if [[ "$connections_count" -eq 0 ]]; then
        print_status "ERROR" "No saved connections found. Please setup a connection first (Option 1)."
        return 1
    fi
    
    print_section_header "Select Connection for ${purpose^}"
    
    echo
    echo "Available connections:"
    
    local connection_ids=()
    readarray -t connection_ids < <(cat "$SAVED_CONNECTIONS_FILE" | jq -r '.[].id')
    
    # Display connections without using subshell
    local counter=1
    while read -r line; do
        IFS='|' read -r name host user <<< "$line"
        print_menu_option "$counter" "$name" "$user@$host"
        ((counter++))
    done < <(cat "$SAVED_CONNECTIONS_FILE" | jq -r '.[] | "\(.name)|\(.host)|\(.user)"')
    
    echo
    echo "[c] Cancel - Return to main menu"
    
    echo
    local choice
    
    # Direct prompt without command substitution
    while true; do
        echo -n "❯ Select connection (1-$connections_count) or 'c' to cancel: "
        read choice
        if [[ "$choice" == "c" ]] || [[ "$choice" == "C" ]]; then
            return 1  # Cancel
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "$connections_count" ]]; then
            break
        else
            echo "❌ Invalid choice. Please enter a number between 1 and $connections_count, or 'c' to cancel"
        fi
    done
    
    local selected_id="${connection_ids[$((choice-1))]}"
    
    print_progress "Loading connection..."
    if load_connection_by_id "$selected_id"; then
        print_status "SUCCESS" "Loaded connection: $selected_id"
        
        # Test the connection before proceeding
        echo
        print_progress "Testing connection..."
        
        local connection_successful=false
        
        if [[ -z "$SSH_KEY" ]]; then
            # Password authentication - prompt for password
            echo
            echo -n "❯ Enter password for $REMOTE_USER@$REMOTE_HOST: "
            read -s password
            echo  # Add newline after hidden password input
            
            if [[ -n "$password" ]]; then
                if test_ssh_connection_with_password "$REMOTE_HOST" "$REMOTE_USER" "$REMOTE_PORT" "$password"; then
                    connection_successful=true
                    # Store password for this session (temporary)
                    REMOTE_PASSWORD="$password"
                fi
            fi
        else
            # SSH key authentication
            if test_ssh_connection "$REMOTE_HOST" "$REMOTE_USER" "$REMOTE_PORT" "$SSH_KEY"; then
                connection_successful=true
            fi
        fi
        
        # Get connection name for recording
        local connection_name=$(cat "$SAVED_CONNECTIONS_FILE" | jq -r ".[] | select(.id == \"$selected_id\") | .name" 2>/dev/null)
        
        # Record the validation attempt
        local auth_type_display
        if [[ -z "$SSH_KEY" ]]; then
            auth_type_display="Password"
        else
            auth_type_display="SSH Key"
        fi
        
        record_connection_validation "$connection_name" "$REMOTE_HOST" "$REMOTE_USER" "$REMOTE_PORT" "$auth_type_display" "$connection_successful"
        
        if [[ "$connection_successful" == true ]]; then
            print_status "SUCCESS" "Connection test successful"
            return 0
        else
            print_status "ERROR" "Connection test failed - please check connection details"
            echo -n "❯ Continue anyway? (y/N) [default: n]: "
            read continue_anyway
            continue_anyway="${continue_anyway:-n}"
            if [[ "$continue_anyway" =~ ^[Yy] ]]; then
                print_status "WARNING" "Proceeding with untested connection"
                # For password auth, still prompt for password if continuing
                if [[ -z "$SSH_KEY" ]] && [[ -z "$REMOTE_PASSWORD" ]]; then
                    echo
                    echo -n "❯ Enter password for connection (needed for operations): "
                    read -s password
                    echo
                    REMOTE_PASSWORD="$password"
                fi
                return 0
            else
                return 1
            fi
        fi
    else
        print_status "ERROR" "Failed to load connection data"
        return 1
    fi
}

# Saved Paths Management Functions
add_saved_path() {
    local path_type="$1"  # "upload" or "download"
    local path="$2"
    
    initialize_connections_dir
    
    local paths_data=$(cat "$SAVED_PATHS_FILE")
    local path_array="${path_type}_paths"
    
    # Check if path already exists
    local exists=$(echo "$paths_data" | jq -r ".${path_array}[] | select(. == \"$path\")")
    
    if [[ -n "$exists" ]]; then
        debug_log "Path already exists in saved $path_type paths: $path"
        return 0
    fi
    
    # Add path to the appropriate array
    local updated_data=$(echo "$paths_data" | jq ".${path_array} += [\"$path\"]")
    echo "$updated_data" > "$SAVED_PATHS_FILE"
    
    debug_log "Added $path_type path: $path"
}

get_saved_paths() {
    local path_type="$1"  # "upload" or "download"
    
    if [[ "$DEBUG" == true ]]; then
        debug_log "get_saved_paths called for: $path_type"
    fi
    
    initialize_connections_dir
    
    if [[ ! -f "$SAVED_PATHS_FILE" ]]; then
        if [[ "$DEBUG" == true ]]; then
            debug_log "No saved paths file found: $SAVED_PATHS_FILE"
        fi
        return
    fi
    
    if [[ ! -s "$SAVED_PATHS_FILE" ]]; then
        if [[ "$DEBUG" == true ]]; then
            debug_log "Saved paths file is empty: $SAVED_PATHS_FILE"
        fi
        return
    fi
    
    local path_array="${path_type}_paths"
    if [[ "$DEBUG" == true ]]; then
        debug_log "Looking for paths in array: $path_array"
        debug_log "Saved paths file content: $(cat "$SAVED_PATHS_FILE" 2>/dev/null)"
    fi
    
    # Use a more robust approach to get paths
    local result
    result=$(timeout 5 jq -r ".${path_array}[]?" "$SAVED_PATHS_FILE" 2>/dev/null || echo "")
    
    if [[ "$DEBUG" == true ]]; then
        debug_log "get_saved_paths result for $path_type: '$result'"
    fi
    
    if [[ -n "$result" ]]; then
        echo "$result"
    fi
}

select_saved_path() {
    local path_type="$1"  # "upload" or "download"
    local operation="$2"  # "for upload" or "for download"
    
    if [[ "$DEBUG" == true ]]; then
        debug_log "select_saved_path called for $path_type $operation"
    fi
    
    initialize_connections_dir
    
    local saved_paths=()
    local paths_output
    paths_output=$(get_saved_paths "$path_type")
    
    if [[ -n "$paths_output" ]]; then
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                saved_paths+=("$line")
            fi
        done <<< "$paths_output"
    fi
    
    if [[ "$DEBUG" == true ]]; then
        debug_log "Found ${#saved_paths[@]} saved paths for $path_type"
        if [[ ${#saved_paths[@]} -gt 0 ]]; then
            debug_log "Paths: ${saved_paths[*]}"
        fi
    fi
    
    if [[ ${#saved_paths[@]} -eq 0 ]]; then
        if [[ "$DEBUG" == true ]]; then
            debug_log "No saved paths available, returning 1"
        fi
        print_status "INFO" "No saved $path_type paths found. You'll be prompted to enter a path manually."
        echo
        return 1
    fi
    
    print_section_header "Select Saved Path $operation"
    
    echo "Saved ${path_type} paths:"
    local counter=1
    for path in "${saved_paths[@]}"; do
        print_menu_option "$counter" "$(basename "$path")" "$path"
        ((counter++))
    done
    
    echo
    echo "[n] Enter new path manually"
    echo "[c] Cancel - use default"
    
    echo
    local choice
    
    while true; do
        echo -n "❯ Select path (1-${#saved_paths[@]}) or 'n'/'c': "
        read choice
        if [[ "$choice" == "c" ]] || [[ "$choice" == "C" ]]; then
            return 1
        elif [[ "$choice" == "n" ]] || [[ "$choice" == "N" ]]; then
            return 2  # Manual entry
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#saved_paths[@]}" ]]; then
            echo "${saved_paths[$((choice-1))]}"
            return 0
        else
            echo "❌ Invalid choice. Please enter a number between 1 and ${#saved_paths[@]}, 'n' for new, or 'c' to cancel"
        fi
    done
}

# Remote file operations
execute_remote_command() {
    local command="$1"
    local ssh_opts="-o ConnectTimeout=$CONNECTION_TIMEOUT -o StrictHostKeyChecking=no"
    
    if [[ -n "$SSH_KEY" ]]; then
        ssh_opts="$ssh_opts -i $SSH_KEY"
    fi
    
    # Add verbose flag if DEBUG or VERBOSE is enabled
    if [[ "$VERBOSE" == true ]] || [[ "$DEBUG" == true ]]; then
        ssh_opts="$ssh_opts -v"
    fi
    
    # Debug logging to stderr to avoid interfering with command output
    if [[ "$DEBUG" == true ]]; then
        echo "🐛 DEBUG: SSH command: ssh $ssh_opts -p $REMOTE_PORT $REMOTE_USER@$REMOTE_HOST '$command'" >&2
    fi
    
    # Execute with appropriate error handling based on debug/verbose mode
    if [[ "$DEBUG" == true ]] || [[ "$VERBOSE" == true ]]; then
        # Show all output including errors when debugging/verbose
        ssh $ssh_opts -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "$command"
    else
        # Suppress error output in normal mode
        ssh $ssh_opts -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "$command" 2>/dev/null
    fi
}

list_remote_directory() {
    local path="$1"
    local show_hidden="$2"
    local view_mode="$3"  # "detailed", "copy", "simple"
    
    # Default to detailed view if not specified
    [[ -z "$view_mode" ]] && view_mode="detailed"
    
    print_progress "Listing remote directory: $path"
    
    local ls_command="ls -la"
    if [[ "$show_hidden" != "true" ]]; then
        ls_command="ls -l"
    fi
    
    # First check if directory exists and is accessible
    local test_result
    if [[ "$DEBUG" == true ]] || [[ "$VERBOSE" == true ]]; then
        test_result=$(execute_remote_command "test -d '$path'" 2>&1)
        local test_exit=$?
    else
        test_result=$(execute_remote_command "test -d '$path'" 2>/dev/null)
        local test_exit=$?
    fi
    
    if [[ $test_exit -ne 0 ]]; then
        print_status "ERROR" "Directory does not exist or is not accessible: $path"
        if [[ "$DEBUG" == true ]] && [[ -n "$test_result" ]]; then
            echo "Debug: $test_result" >&2
        fi
        return 1
    fi
    
    local result
    result=$(execute_remote_command "cd '$path' && $ls_command")
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]] && [[ -n "$result" ]]; then
        echo
        
        case "$view_mode" in
            "detailed")
                display_detailed_view "$path" "$result"
                ;;
            "copy")
                display_copy_view "$path" "$result"
                ;;
            "simple")
                display_simple_view "$path" "$result"
                ;;
            *)
                display_detailed_view "$path" "$result"
                ;;
        esac
        return 0
    else
        print_status "ERROR" "Failed to list directory: $path"
        if [[ -n "$result" ]]; then
            echo "Error details: $result"
        fi
        return 1
    fi
}

# Display functions for different view modes
display_detailed_view() {
    local path="$1"
    local result="$2"
    
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo "📁 Remote Directory: $path"
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo
    
    # Check if terminal supports colors
    local use_colors=false
    if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
        local colors=$(tput colors 2>/dev/null)
        if [[ -n "$colors" ]] && [[ "$colors" -ge 8 ]]; then
            use_colors=true
        fi
    fi
    
    # Process each line and add color/icons
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            # Skip total line
            if [[ "$line" =~ ^total ]]; then
                continue
            fi
            
            # Parse file info
            local permissions=$(echo "$line" | awk '{print $1}')
            local filename=$(echo "$line" | awk '{for(i=9;i<=NF;i++) printf "%s%s", $i, (i==NF?"\n":" ")}' | sed 's/[[:space:]]*$//')
            
            # Determine file type and add appropriate icon
            local icon="📄"
            local color_start=""
            local color_end=""
            
            if [[ "$use_colors" == true ]]; then
                if [[ "$permissions" =~ ^d ]]; then
                    icon="📁"
                    color_start="$(tput setaf 4)$(tput bold)"  # Blue for directories
                    color_end="$(tput sgr0)"
                elif [[ "$permissions" =~ ^l ]]; then
                    icon="🔗"
                    color_start="$(tput setaf 6)$(tput bold)"  # Cyan for symlinks
                    color_end="$(tput sgr0)"
                elif [[ "$permissions" =~ x ]]; then
                    icon="⚙️"
                    color_start="$(tput setaf 2)$(tput bold)"  # Green for executables
                    color_end="$(tput sgr0)"
                fi
            else
                # Fallback for terminals without color support
                if [[ "$permissions" =~ ^d ]]; then
                    icon="📁"
                elif [[ "$permissions" =~ ^l ]]; then
                    icon="🔗"
                elif [[ "$permissions" =~ x ]]; then
                    icon="⚙️"
                fi
            fi
            
            # Print with color and icon (ensure clean output)
            if [[ -n "$color_start" ]] && [[ -n "$color_end" ]]; then
                printf "%s %s%s%s\n" "$icon" "$color_start" "$line" "$color_end"
            else
                printf "%s %s\n" "$icon" "$line"
            fi
        fi
    done <<< "$result"
}

display_copy_view() {
    local path="$1"
    local result="$2"
    
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo "📁 Remote Directory: $path"
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo
    
    # Check if terminal supports colors
    local use_colors=false
    if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
        local colors=$(tput colors 2>/dev/null)
        if [[ -n "$colors" ]] && [[ "$colors" -ge 8 ]]; then
            use_colors=true
        fi
    fi
    
    # Show detailed listing first
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            # Skip total line
            if [[ "$line" =~ ^total ]]; then
                continue
            fi
            
            # Parse file info
            local permissions=$(echo "$line" | awk '{print $1}')
            local filename=$(echo "$line" | awk '{for(i=9;i<=NF;i++) printf "%s%s", $i, (i==NF?"\n":" ")}' | sed 's/[[:space:]]*$//')
            
            # Determine file type and add appropriate icon
            local icon="📄"
            local color_start=""
            local color_end=""
            
            if [[ "$use_colors" == true ]]; then
                if [[ "$permissions" =~ ^d ]]; then
                    icon="📁"
                    color_start="$(tput setaf 4)$(tput bold)"  # Blue for directories
                    color_end="$(tput sgr0)"
                elif [[ "$permissions" =~ ^l ]]; then
                    icon="🔗"
                    color_start="$(tput setaf 6)$(tput bold)"  # Cyan for symlinks
                    color_end="$(tput sgr0)"
                elif [[ "$permissions" =~ x ]]; then
                    icon="⚙️"
                    color_start="$(tput setaf 2)$(tput bold)"  # Green for executables
                    color_end="$(tput sgr0)"
                fi
            else
                # Fallback for terminals without color support
                if [[ "$permissions" =~ ^d ]]; then
                    icon="📁"
                elif [[ "$permissions" =~ ^l ]]; then
                    icon="🔗"
                elif [[ "$permissions" =~ x ]]; then
                    icon="⚙️"
                fi
            fi
            
            # Print with color and icon (ensure clean output)
            if [[ -n "$color_start" ]] && [[ -n "$color_end" ]]; then
                printf "%s %s%s%s\n" "$icon" "$color_start" "$line" "$color_end"
            else
                printf "%s %s\n" "$icon" "$line"
            fi
        fi
    done <<< "$result"
    
    echo
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo "📋 Copying view format:"
    echo "════════════════════════════════════════════════════════════════════════════════"
    
    # Show simple paths for easy copying
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            # Skip total line
            if [[ "$line" =~ ^total ]]; then
                continue
            fi
            
            # Extract filename
            local filename=$(echo "$line" | awk '{for(i=9;i<=NF;i++) printf "%s%s", $i, (i==NF?"\n":" ")}' | sed 's/[[:space:]]*$//')
            
            # Skip current and parent directory entries
            if [[ "$filename" != "." && "$filename" != ".." ]]; then
                # Remove trailing slash from path if present, then add filename
                local clean_path="${path%/}"
                echo "$clean_path/$filename"
            fi
        fi
    done <<< "$result"
}

display_simple_view() {
    local path="$1"
    local result="$2"
    
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo "📁 Remote Directory: $path"
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo
    
    # Show only filenames with minimal formatting
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            # Skip total line
            if [[ "$line" =~ ^total ]]; then
                continue
            fi
            
            # Extract filename and permissions
            local permissions=$(echo "$line" | awk '{print $1}')
            local filename=$(echo "$line" | awk '{for(i=9;i<=NF;i++) printf "%s%s", $i, (i==NF?"\n":" ")}' | sed 's/[[:space:]]*$//')
            
            # Skip current and parent directory entries
            if [[ "$filename" != "." && "$filename" != ".." ]]; then
                # Add simple indicator for type
                if [[ "$permissions" =~ ^d ]]; then
                    echo "$filename/"
                else
                    echo "$filename"
                fi
            fi
        fi
    done <<< "$result"
}

browse_remote_directory() {
    local current_path="$1"
    local view_mode="${2:-detailed}"  # Default to detailed view
    
    # Check if we have a valid connection
    if [[ -z "$REMOTE_HOST" ]] || [[ -z "$REMOTE_USER" ]]; then
        print_status "ERROR" "No active connection. Please select a connection first."
        return 1
    fi
    
    # Initialize with actual home directory path instead of ~
    if [[ -z "$current_path" ]] || [[ "$current_path" == "~" ]]; then
        print_progress "Determining home directory..."
        
        # Method 1: Use pwd (gets current directory when SSH connects)
        current_path=$(execute_remote_command "pwd")
        if [[ "$DEBUG" == true ]]; then
            echo "🐛 DEBUG: pwd returned: '$current_path'" >&2
        fi
        
        # Method 2: If pwd failed or returned empty, try $HOME
        if [[ -z "$current_path" ]]; then
            current_path=$(execute_remote_command "echo \$HOME")
            if [[ "$DEBUG" == true ]]; then
                echo "🐛 DEBUG: \$HOME returned: '$current_path'" >&2
            fi
        fi
        
        # Method 3: If still empty, try standard Linux home path
        if [[ -z "$current_path" ]]; then
            current_path="/home/$REMOTE_USER"
            if [[ "$DEBUG" == true ]]; then
                echo "🐛 DEBUG: Using constructed path: '$current_path'" >&2
            fi
        fi
        
        # Verify the resolved path actually exists
        if ! execute_remote_command "test -d '$current_path'" >/dev/null 2>&1; then
            if [[ "$DEBUG" == true ]]; then
                echo "🐛 DEBUG: Resolved path '$current_path' doesn't exist, trying alternatives" >&2
            fi
            
            # Try other common paths
            local alt_paths=("/home/$REMOTE_USER" "/root" "/")
            for alt_path in "${alt_paths[@]}"; do
                if execute_remote_command "test -d '$alt_path'" >/dev/null 2>&1; then
                    current_path="$alt_path"
                    if [[ "$DEBUG" == true ]]; then
                        echo "🐛 DEBUG: Using alternative path: '$current_path'" >&2
                    fi
                    break
                fi
            done
        fi
        
        if [[ "$DEBUG" == true ]]; then
            echo "🐛 DEBUG: Final resolved home directory: '$current_path'" >&2
        fi
    fi
    
    while true; do
        print_header
        print_section_header "Remote Directory Browser"
        
        echo "Connected to: $REMOTE_USER@$REMOTE_HOST"
        echo "Current directory: $current_path"
        echo
        
        # List directory contents
        if ! list_remote_directory "$current_path" false "$view_mode"; then
            print_status "ERROR" "Failed to access directory: $current_path"
            echo "Attempting to resolve home directory..."
            
            # Try different approaches to get a valid directory
            local fallback_path
            fallback_path=$(execute_remote_command "echo \$HOME" 2>/dev/null)
            
            if [[ -n "$fallback_path" ]] && [[ "$fallback_path" != "$current_path" ]]; then
                current_path="$fallback_path"
                echo "Using resolved home: $current_path"
            else
                # Try /home/$USER
                fallback_path="/home/$REMOTE_USER"
                if execute_remote_command "test -d '$fallback_path'" >/dev/null 2>&1; then
                    current_path="$fallback_path"
                    echo "Using /home/$REMOTE_USER directory"
                else
                    # Last resort: root directory
                    current_path="/"
                    echo "Using root directory as fallback"
                fi
            fi
        fi
        
        echo
        print_section_header "Directory Navigation"
        print_menu_option "1" "Change Directory" "Navigate to a different directory"
        print_menu_option "2" "Parent Directory" "Go up one level (..)"
        print_menu_option "3" "Home Directory" "Go to home directory (~)"
        print_menu_option "4" "Refresh" "Refresh current directory"
        print_menu_option "5" "Select Current Dir" "Use this directory for file operations"
        
        echo
        print_section_header "View Options (Current: $view_mode)"
        print_menu_option "6" "Detailed View" "Show full file details with icons and colors"
        print_menu_option "7" "Copy View" "Show details + full paths for easy copying"
        print_menu_option "8" "Simple View" "Show filenames only"
        
        echo
        print_menu_option "9" "Back to Main Menu" "Return to main menu"
        
        echo
        local choice
        
        # Direct prompt without command substitution
        while true; do
            echo -n "❯ Select option (1-9): "
            read choice
            if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le 9 ]]; then
                break
            else
                echo "❌ Invalid choice. Please enter a number between 1 and 9"
            fi
        done
        
        case "$choice" in
            1)
                local new_path
                echo -n "❯ Enter directory path: "
                read new_path
                if [[ -n "$new_path" ]]; then
                    # Resolve the actual path
                    local resolved_path
                    resolved_path=$(execute_remote_command "cd '$new_path' && pwd")
                    local cd_exit=$?
                    if [[ $cd_exit -eq 0 ]] && [[ -n "$resolved_path" ]]; then
                        current_path="$resolved_path"
                        print_status "SUCCESS" "Changed to directory: $current_path"
                    else
                        print_status "ERROR" "Cannot access directory: $new_path"
                        if [[ "$DEBUG" == true ]]; then
                            echo "Debug: cd command failed with exit code $cd_exit" >&2
                        fi
                        press_enter_to_continue
                    fi
                fi
                ;;
            2)
                # Go to parent directory
                local parent_path
                parent_path=$(execute_remote_command "cd '$current_path/..' && pwd")
                local parent_exit=$?
                if [[ $parent_exit -eq 0 ]] && [[ -n "$parent_path" ]]; then
                    current_path="$parent_path"
                    if [[ "$DEBUG" == true ]]; then
                        echo "🐛 DEBUG: Changed to parent directory: $current_path" >&2
                    fi
                else
                    print_status "ERROR" "Cannot access parent directory"
                    if [[ "$DEBUG" == true ]]; then
                        echo "Debug: parent directory command failed with exit code $parent_exit" >&2
                    fi
                    press_enter_to_continue
                fi
                ;;
            3)
                # Go to home directory using robust method
                local home_path
                
                # Try multiple approaches to get home directory
                home_path=$(execute_remote_command "echo \$HOME")
                local home_exit=$?
                
                if [[ $home_exit -eq 0 ]] && [[ -n "$home_path" ]]; then
                    # Verify the directory exists
                    if execute_remote_command "test -d '$home_path'" >/dev/null 2>&1; then
                        current_path="$home_path"
                        if [[ "$DEBUG" == true ]]; then
                            echo "🐛 DEBUG: Changed to home directory: $current_path" >&2
                        fi
                    else
                        # Try /home/$USER if $HOME doesn't exist
                        home_path="/home/$REMOTE_USER"
                        if execute_remote_command "test -d '$home_path'" >/dev/null 2>&1; then
                            current_path="$home_path"
                            if [[ "$DEBUG" == true ]]; then
                                echo "🐛 DEBUG: Used /home/$REMOTE_USER: $current_path" >&2
                            fi
                        else
                            print_status "WARNING" "Cannot determine home directory, staying in current location"
                            press_enter_to_continue
                        fi
                    fi
                else
                    # Fallback to /home/$USER
                    home_path="/home/$REMOTE_USER"
                    if execute_remote_command "test -d '$home_path'" >/dev/null 2>&1; then
                        current_path="$home_path"
                        if [[ "$DEBUG" == true ]]; then
                            echo "🐛 DEBUG: Fallback to /home/$REMOTE_USER: $current_path" >&2
                        fi
                    else
                        print_status "WARNING" "Cannot access home directory"
                        press_enter_to_continue
                    fi
                fi
                ;;
            4)
                # Refresh - just continue the loop
                if [[ "$DEBUG" == true ]]; then
                    echo "🐛 DEBUG: Refreshing directory listing" >&2
                fi
                ;;
            5)
                # Get the actual resolved path before setting
                local resolved_path
                resolved_path=$(execute_remote_command "cd '$current_path' && pwd")
                local resolve_exit=$?
                if [[ $resolve_exit -eq 0 ]] && [[ -n "$resolved_path" ]]; then
                    REMOTE_PATH="$resolved_path"
                    print_status "SUCCESS" "Selected remote directory: $REMOTE_PATH"
                    if [[ "$DEBUG" == true ]]; then
                        echo "🐛 DEBUG: Set REMOTE_PATH to: $REMOTE_PATH" >&2
                    fi
                else
                    REMOTE_PATH="$current_path"
                    print_status "SUCCESS" "Selected remote directory: $REMOTE_PATH"
                    if [[ "$DEBUG" == true ]]; then
                        echo "Debug: path resolution failed, using current path: $REMOTE_PATH" >&2
                    fi
                fi
                press_enter_to_continue
                return 0
                ;;
            6)
                # Switch to detailed view
                view_mode="detailed"
                print_status "SUCCESS" "Switched to detailed view"
                ;;
            7)
                # Switch to copy view
                view_mode="copy"
                print_status "SUCCESS" "Switched to copy view"
                ;;
            8)
                # Switch to simple view
                view_mode="simple"
                print_status "SUCCESS" "Switched to simple view"
                ;;
            9)
                return 1
                ;;
        esac
    done
}

# File transfer operations
build_scp_command() {
    local operation="$1"  # "upload" or "download"
    local source="$2"
    local destination="$3"
    
    # Start with basic options (without -r)
    local scp_opts="-P $REMOTE_PORT -o ConnectTimeout=$CONNECTION_TIMEOUT -o StrictHostKeyChecking=no"
    
    # Add recursive flag only if source is a directory
    if [[ "$operation" == "upload" ]] && [[ -d "$source" ]]; then
        scp_opts="-r $scp_opts"
        debug_log "Added recursive flag for directory upload: $source"
    elif [[ "$operation" == "download" ]]; then
        # For downloads, check if remote source is a directory
        if execute_remote_command "test -d '$source'" >/dev/null 2>&1; then
            scp_opts="-r $scp_opts"
            debug_log "Added recursive flag for directory download: $source"
        fi
    fi
    
    if [[ -n "$SSH_KEY" ]]; then
        scp_opts="$scp_opts -i $SSH_KEY"
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        scp_opts="$scp_opts -v"
    fi
    
    local scp_command
    if [[ "$operation" == "upload" ]]; then
        scp_command="scp $scp_opts '$source' '$REMOTE_USER@$REMOTE_HOST:$destination'"
    else
        scp_command="scp $scp_opts '$REMOTE_USER@$REMOTE_HOST:$source' '$destination'"
    fi
    
    echo "$scp_command"
}

execute_file_transfer() {
    local operation="$1"
    local source="$2"
    local destination="$3"
    
    local scp_command
    scp_command=$(build_scp_command "$operation" "$source" "$destination")
    
    debug_log "SCP Command: $scp_command"
    
    print_progress "Executing file transfer..."
    
    if [[ "$DEBUG" == true ]]; then
        print_color "PURPLE" "🐛 DEBUG MODE: Will show command details"
        print_color "WHITE" "Command: $scp_command"
        echo
    fi
    
    # Execute the command
    eval "$scp_command"
    local exit_code=$?
    
    echo
    if [[ $exit_code -eq 0 ]]; then
        print_status "SUCCESS" "File transfer completed successfully!"
    else
        print_status "ERROR" "File transfer failed with exit code: $exit_code"
    fi
    
    return $exit_code
}

upload_files() {
    print_header
    print_section_header "Upload Files to Remote Host"
    
    if [[ "$DEBUG" == true ]]; then
        debug_log "Starting upload_files function"
    fi
    
    # Check for saved connections first
    initialize_connections_dir
    
    if [[ ! -f "$SAVED_CONNECTIONS_FILE" ]] || [[ ! -s "$SAVED_CONNECTIONS_FILE" ]]; then
        print_status "ERROR" "No saved connections found. Please setup a connection first (Option 1)."
        return 1
    fi
    
    local connections_count=$(cat "$SAVED_CONNECTIONS_FILE" | jq 'length')
    
    if [[ "$connections_count" -eq 0 ]]; then
        print_status "ERROR" "No saved connections found. Please setup a connection first (Option 1)."
        return 1
    fi
    
    # Select a saved connection
    if ! select_saved_connection "upload"; then
        return 1
    fi
    
    echo  # Add some spacing after connection loading
    
    # Get local source with saved paths option
    local local_source
    if [[ "$DEBUG" == true ]]; then
        debug_log "About to handle path selection for upload"
    fi
    
    # Check if there are saved paths without using command substitution
    local saved_paths_output
    saved_paths_output=$(get_saved_paths "upload")
    
    if [[ -n "$saved_paths_output" ]]; then
        # There are saved paths - show the selection menu
        if [[ "$DEBUG" == true ]]; then
            debug_log "Found saved upload paths, showing menu"
        fi
        
        print_section_header "Select Saved Path for Upload"
        echo "Saved upload paths:"
        
        local paths_array=()
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                paths_array+=("$line")
            fi
        done <<< "$saved_paths_output"
        
        local counter=1
        for path in "${paths_array[@]}"; do
            print_menu_option "$counter" "$(basename "$path")" "$path"
            ((counter++))
        done
        
        echo
        echo "[n] Enter new path manually"
        echo "[c] Cancel - use default"
        
        echo
        local choice
        while true; do
            echo -n "❯ Select path (1-${#paths_array[@]}) or 'n'/'c': "
            read choice
            if [[ "$choice" == "c" ]] || [[ "$choice" == "C" ]]; then
                break  # Use default handling below
            elif [[ "$choice" == "n" ]] || [[ "$choice" == "N" ]]; then
                break  # Use manual entry below
            elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#paths_array[@]}" ]]; then
                local_source="${paths_array[$((choice-1))]}"
                print_status "INFO" "Using saved path: $local_source"
                break
            else
                echo "❌ Invalid choice. Please enter a number between 1 and ${#paths_array[@]}, 'n' for new, or 'c' to cancel"
            fi
        done
        
        # If a path was selected, we're done with path selection
        if [[ -n "$local_source" ]]; then
            if [[ "$DEBUG" == true ]]; then
                debug_log "Selected saved path: $local_source"
            fi
        else
            # User chose manual entry or cancel - fall through to manual entry
            if [[ "$DEBUG" == true ]]; then
                debug_log "User chose manual entry or cancel"
            fi
        fi
    else
        # No saved paths available
        if [[ "$DEBUG" == true ]]; then
            debug_log "No saved upload paths found"
        fi
        print_status "INFO" "No saved upload paths found. You'll be prompted to enter a path manually."
        echo
    fi
    
    # If no path selected yet, prompt for manual entry
    if [[ -z "$local_source" ]]; then
        print_section_header "Enter Upload Source Path"
        echo -n "❯ Local file/directory path to upload [default: $PWD]: "
        read local_source
        local_source="${local_source:-$PWD}"
        
        # Ask if user wants to save this path
        echo -n "❯ Save this path for future uploads? (y/N) [default: n]: "
        read save_path
        save_path="${save_path:-n}"
        if [[ "$save_path" =~ ^[Yy] ]]; then
            add_saved_path "upload" "$local_source"
            print_status "SUCCESS" "Upload path saved: $local_source"
        fi
    fi
    
    # Select transfer type
    if ! select_transfer_type "$local_source" "upload"; then
        print_status "ERROR" "Transfer type selection failed"
        return 1
    fi
    
    # Continue with file validation and transfer
    while true; do
        echo
        print_progress "Validating local path..."
        if [[ -e "$local_source" ]]; then
            print_status "SUCCESS" "Local path validated: $local_source"
            break
        else
            print_status "ERROR" "Local path does not exist: $local_source"
            echo
            echo "Options:"
            echo "[1] Enter a different path"
            echo "[2] Browse local directory to find correct path"
            echo "[3] Cancel and return to main menu"
            echo
            echo -n "❯ Choose option (1-3): "
            read retry_choice
            
            case "$retry_choice" in
                1)
                    echo -n "❯ Enter new local path: "
                    read local_source
                    if [[ -z "$local_source" ]]; then
                        local_source="$PWD"
                    fi
                    ;;
                2)
                    # Show the directory contents
                    local browse_dir=$(dirname "$local_source")
                    if [[ -d "$browse_dir" ]]; then
                        echo
                        print_status "INFO" "Showing contents of: $browse_dir"
                        echo
                        ls -la "$browse_dir" 2>/dev/null || echo "Cannot list directory contents"
                    else
                        echo
                        print_status "INFO" "Parent directory doesn't exist either. Showing current directory:"
                        echo
                        ls -la . 2>/dev/null || echo "Cannot list directory contents"
                    fi
                    echo
                    echo -n "❯ Enter correct local path from above listing: "
                    read local_source
                    if [[ -z "$local_source" ]]; then
                        local_source="$PWD"
                    fi
                    ;;
                3|*)
                    return 1
                    ;;
            esac
        fi
    done
    
    # Get remote destination
    echo -n "❯ Remote destination path [default: ${REMOTE_PATH:-~}]: "
    read remote_dest
    remote_dest="${remote_dest:-${REMOTE_PATH:-~}}"
    
    # Check if remote destination already exists
    local filename=$(basename "$local_source")
    local remote_full_path="$remote_dest/$filename"
    
    if execute_remote_command "test -e '$remote_full_path'" >/dev/null 2>&1; then
        echo
        print_color "YELLOW" "⚠️  WARNING: Remote destination already exists!"
        
        # Check if it's a directory or file
        if execute_remote_command "test -d '$remote_full_path'" >/dev/null 2>&1; then
            print_color "YELLOW" "   Directory: $remote_full_path"
        else
            print_color "YELLOW" "   File: $remote_full_path"
            local remote_size=$(execute_remote_command "du -h '$remote_full_path' 2>/dev/null | cut -f1" 2>/dev/null || echo "unknown")
            print_color "YELLOW" "   Size: $remote_size"
        fi
        echo
        echo -n "❯ This will overwrite the existing file/directory. Continue? (y/N) [default: n]: "
        read overwrite_confirm
        overwrite_confirm="${overwrite_confirm:-n}"
        
        if [[ ! "$overwrite_confirm" =~ ^[Yy] ]]; then
            print_status "INFO" "Upload cancelled to prevent overwrite"
            return 1
        fi
        
        # Extra warning for directories
        if execute_remote_command "test -d '$remote_full_path'" >/dev/null 2>&1; then
            echo
            print_color "RED" "⚠️  WARNING: You're about to overwrite a remote directory!"
            echo -n "❯ Are you absolutely sure? Type 'YES' to confirm: "
            read final_confirm
            if [[ "$final_confirm" != "YES" ]]; then
                print_status "INFO" "Upload cancelled"
                return 1
            fi
        fi
        
        if [[ "$DEBUG" == true ]]; then
            debug_log "User confirmed overwrite of existing remote destination: $remote_full_path"
        fi
    fi
    
    # Show transfer summary
    echo
    print_color "BOLD_YELLOW" "📤 UPLOAD SUMMARY"
    print_color "BOLD_BLUE" "$(printf '%*s' 50 | tr ' ' '=')"
    print_color "WHITE" "Source:      $local_source"
    print_color "WHITE" "Destination: $REMOTE_USER@$REMOTE_HOST:$remote_dest"
    print_color "WHITE" "SSH Key:     ${SSH_KEY:-'Password Authentication'}"
    echo
    
    local confirm
    echo -n "❯ Proceed with upload? (y/N) [default: n]: "
    read confirm
    confirm="${confirm:-n}"
    
    if [[ "$confirm" =~ ^[Yy] ]]; then
        execute_file_transfer "upload" "$local_source" "$remote_dest"
    else
        print_status "INFO" "Upload cancelled"
    fi
}

download_files() {
    print_header
    print_section_header "Download Files from Remote Host"
    
    if [[ "$DEBUG" == true ]]; then
        debug_log "Starting download_files function"
    fi
    
    # Check for saved connections first
    initialize_connections_dir
    
    if [[ ! -f "$SAVED_CONNECTIONS_FILE" ]] || [[ ! -s "$SAVED_CONNECTIONS_FILE" ]]; then
        print_status "ERROR" "No saved connections found. Please setup a connection first (Option 1)."
        return 1
    fi
    
    local connections_count=$(cat "$SAVED_CONNECTIONS_FILE" | jq 'length')
    
    if [[ "$connections_count" -eq 0 ]]; then
        print_status "ERROR" "No saved connections found. Please setup a connection first (Option 1)."
        return 1
    fi
    
    # Select a saved connection
    if ! select_saved_connection "download"; then
        return 1
    fi
    
    echo  # Add some spacing after connection loading
    
    # Get remote source
    print_section_header "Enter Download Source Path"
    echo -n "❯ Remote file/directory path to download [default: ${REMOTE_PATH:-~}]: "
    read remote_source
    remote_source="${remote_source:-${REMOTE_PATH:-~}}"
    
    # Validate that the remote source exists  
    while true; do
        echo
        print_progress "Validating remote path..."
        if execute_remote_command "test -e '$remote_source'" >/dev/null 2>&1; then
            print_status "SUCCESS" "Remote path validated: $remote_source"
            break
        else
            print_status "ERROR" "Remote path does not exist: $remote_source"
            echo
            echo "Options:"
            echo "[1] Enter a different path"
            echo "[2] Browse remote directory to find correct path"
            echo "[3] Cancel and return to main menu"
            echo
            echo -n "❯ Choose option (1-3): "
            read retry_choice
            
            case "$retry_choice" in
                1)
                    echo -n "❯ Enter new remote path: "
                    read remote_source
                    if [[ -z "$remote_source" ]]; then
                        remote_source="${REMOTE_PATH:-~}"
                    fi
                    ;;
                2)
                    # Get the directory part of the path to browse
                    local browse_dir=$(dirname "$remote_source")
                    if execute_remote_command "test -d '$browse_dir'" >/dev/null 2>&1; then
                        echo
                        print_status "INFO" "Showing contents of: $browse_dir"
                        echo
                        list_remote_directory "$browse_dir" false "copy"
                    else
                        echo
                        print_status "INFO" "Parent directory doesn't exist either. Showing home directory:"
                        echo
                        list_remote_directory "~" false "copy"
                    fi
                    echo
                    echo -n "❯ Enter correct remote path from above listing: "
                    read remote_source
                    if [[ -z "$remote_source" ]]; then
                        remote_source="${REMOTE_PATH:-~}"
                    fi
                    ;;
                3|*)
                    return 1
                    ;;
            esac
        fi
    done
    
    # Select transfer type for remote source
    if ! select_transfer_type "$remote_source" "download"; then
        print_status "ERROR" "Transfer type selection failed"
        return 1
    fi
    
    # Get local destination with saved paths option
    local local_dest
    if [[ "$DEBUG" == true ]]; then
        debug_log "About to handle destination path selection for download"
    fi
    
    # Check if there are saved paths without using command substitution
    local saved_paths_output
    saved_paths_output=$(get_saved_paths "download")
    
    if [[ -n "$saved_paths_output" ]]; then
        # There are saved paths - show the selection menu
        if [[ "$DEBUG" == true ]]; then
            debug_log "Found saved download paths, showing menu"
        fi
        
        print_section_header "Select Saved Path for Download"
        echo "Saved download paths:"
        
        local paths_array=()
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                paths_array+=("$line")
            fi
        done <<< "$saved_paths_output"
        
        local counter=1
        for path in "${paths_array[@]}"; do
            print_menu_option "$counter" "$(basename "$path")" "$path"
            ((counter++))
        done
        
        echo
        echo "[n] Enter new path manually"
        echo "[c] Cancel - use default"
        
        echo
        local choice
        while true; do
            echo -n "❯ Select path (1-${#paths_array[@]}) or 'n'/'c': "
            read choice
            if [[ "$choice" == "c" ]] || [[ "$choice" == "C" ]]; then
                break  # Use default handling below
            elif [[ "$choice" == "n" ]] || [[ "$choice" == "N" ]]; then
                break  # Use manual entry below
            elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#paths_array[@]}" ]]; then
                local_dest="${paths_array[$((choice-1))]}"
                print_status "INFO" "Using saved path: $local_dest"
                break
            else
                echo "❌ Invalid choice. Please enter a number between 1 and ${#paths_array[@]}, 'n' for new, or 'c' to cancel"
            fi
        done
        
        # If a path was selected, we're done with path selection
        if [[ -n "$local_dest" ]]; then
            if [[ "$DEBUG" == true ]]; then
                debug_log "Selected saved destination path: $local_dest"
            fi
        else
            # User chose manual entry or cancel - fall through to manual entry
            if [[ "$DEBUG" == true ]]; then
                debug_log "User chose manual entry or cancel for destination"
            fi
        fi
    else
        # No saved paths available
        if [[ "$DEBUG" == true ]]; then
            debug_log "No saved download paths found"
        fi
        print_status "INFO" "No saved download paths found. You'll be prompted to enter a path manually."
        echo
    fi
    
    # If no path selected yet, prompt for manual entry
    if [[ -z "$local_dest" ]]; then
        print_section_header "Enter Download Destination Path"
        echo -n "❯ Local destination path [default: $PWD]: "
        read local_dest
        local_dest="${local_dest:-$PWD}"
        
        # Ask if user wants to save this path
        echo -n "❯ Save this path for future downloads? (y/N) [default: n]: "
        read save_path
        save_path="${save_path:-n}"
        if [[ "$save_path" =~ ^[Yy] ]]; then
            add_saved_path "download" "$local_dest"
            print_status "SUCCESS" "Download path saved: $local_dest"
        fi
    fi
    
    # Create local destination if it doesn't exist
    if [[ ! -d "$local_dest" ]]; then
        mkdir -p "$local_dest" 2>/dev/null || {
            print_status "ERROR" "Cannot create local destination: $local_dest"
            return 1
        }
    fi
    
    # Check for existing files/directories that might conflict
    local filename=$(basename "$remote_source")
    local full_dest_path="$local_dest/$filename"
    
    if [[ -e "$full_dest_path" ]]; then
        echo
        print_color "YELLOW" "⚠️  WARNING: Destination already exists!"
        if [[ -d "$full_dest_path" ]]; then
            print_color "YELLOW" "   Directory: $full_dest_path"
        else
            print_color "YELLOW" "   File: $full_dest_path"
            local file_size=$(du -h "$full_dest_path" 2>/dev/null | cut -f1)
            print_color "YELLOW" "   Size: ${file_size:-unknown}"
        fi
        echo
        echo -n "❯ This will overwrite the existing file/directory. Continue? (y/N) [default: n]: "
        read overwrite_confirm
        overwrite_confirm="${overwrite_confirm:-n}"
        
        if [[ ! "$overwrite_confirm" =~ ^[Yy] ]]; then
            print_status "INFO" "Download cancelled to prevent overwrite"
            return 1
        fi
        
        # If it's a directory, warn about recursive overwrite
        if [[ -d "$full_dest_path" ]]; then
            echo
            print_color "RED" "⚠️  WARNING: You're about to overwrite a directory!"
            echo -n "❯ Are you absolutely sure? Type 'YES' to confirm: "
            read final_confirm
            if [[ "$final_confirm" != "YES" ]]; then
                print_status "INFO" "Download cancelled"
                return 1
            fi
        fi
        
        if [[ "$DEBUG" == true ]]; then
            debug_log "User confirmed overwrite of existing destination: $full_dest_path"
        fi
    fi
    
    # Show transfer summary
    echo
    print_color "BOLD_YELLOW" "📥 DOWNLOAD SUMMARY"
    print_color "BOLD_BLUE" "$(printf '%*s' 50 | tr ' ' '=')"
    print_color "WHITE" "Source:      $REMOTE_USER@$REMOTE_HOST:$remote_source"
    print_color "WHITE" "Destination: $local_dest"
    print_color "WHITE" "SSH Key:     ${SSH_KEY:-'Password Authentication'}"
    echo
    
    local confirm
    echo -n "❯ Proceed with download? (y/N) [default: n]: "
    read confirm
    confirm="${confirm:-n}"
    
    if [[ "$confirm" =~ ^[Yy] ]]; then
        execute_file_transfer "download" "$remote_source" "$local_dest"
    else
        print_status "INFO" "Download cancelled"
    fi
}

# Saved paths menu functions
manage_saved_paths_menu() {
    while true; do
        print_header
        print_section_header "Manage Saved Paths"
        
        print_menu_option "1" "View Upload Paths" "Show all saved upload paths"
        print_menu_option "2" "View Download Paths" "Show all saved download paths"
        print_menu_option "3" "Add Upload Path" "Add a new upload path"
        print_menu_option "4" "Add Download Path" "Add a new download path"
        print_menu_option "5" "Remove Upload Path" "Delete a saved upload path"
        print_menu_option "6" "Remove Download Path" "Delete a saved download path"
        print_menu_option "7" "Clear All Paths" "Remove all saved paths"
        print_menu_option "8" "Back to Main Menu" "Return to main menu"
        
        echo
        local choice
        
        while true; do
            echo -n "❯ Select option (1-8): "
            read choice
            if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le 8 ]]; then
                break
            else
                echo "❌ Invalid choice. Please enter a number between 1 and 8"
            fi
        done
        
        case "$choice" in
            1)
                view_saved_paths "upload"
                press_enter_to_continue
                ;;
            2)
                view_saved_paths "download"
                press_enter_to_continue
                ;;
            3)
                add_saved_path_interactive "upload"
                press_enter_to_continue
                ;;
            4)
                add_saved_path_interactive "download"
                press_enter_to_continue
                ;;
            5)
                remove_saved_path_interactive "upload"
                press_enter_to_continue
                ;;
            6)
                remove_saved_path_interactive "download"
                press_enter_to_continue
                ;;
            7)
                clear_all_saved_paths
                press_enter_to_continue
                ;;
            8)
                return
                ;;
        esac
    done
}

view_saved_paths() {
    local path_type="$1"
    
    print_header
    print_section_header "Saved ${path_type^} Paths"
    
    local saved_paths
    readarray -t saved_paths < <(get_saved_paths "$path_type")
    
    if [[ ${#saved_paths[@]} -eq 0 ]] || [[ -z "${saved_paths[0]}" ]]; then
        print_status "INFO" "No saved ${path_type} paths found"
        return
    fi
    
    echo "Saved ${path_type} paths:"
    echo
    local counter=1
    for path in "${saved_paths[@]}"; do
        print_color "BOLD_WHITE" "[$counter] $path"
        ((counter++))
    done
}

add_saved_path_interactive() {
    local path_type="$1"
    
    print_header
    print_section_header "Add Saved ${path_type^} Path"
    
    echo -n "❯ Enter ${path_type} path to save: "
    read new_path
    
    if [[ -z "$new_path" ]]; then
        print_status "ERROR" "Path cannot be empty"
        return
    fi
    
    # Expand path
    new_path=$(eval echo "$new_path")
    
    # For upload paths, check if local path exists
    if [[ "$path_type" == "upload" ]] && [[ ! -e "$new_path" ]]; then
        print_status "WARNING" "Local path does not exist: $new_path"
        echo -n "❯ Save anyway? (y/N) [default: n]: "
        read confirm
        confirm="${confirm:-n}"
        if [[ ! "$confirm" =~ ^[Yy] ]]; then
            print_status "INFO" "Path not saved"
            return
        fi
    fi
    
    add_saved_path "$path_type" "$new_path"
    print_status "SUCCESS" "Saved ${path_type} path: $new_path"
}

remove_saved_path_interactive() {
    local path_type="$1"
    
    print_header
    print_section_header "Remove Saved ${path_type^} Path"
    
    local saved_paths
    readarray -t saved_paths < <(get_saved_paths "$path_type")
    
    if [[ ${#saved_paths[@]} -eq 0 ]] || [[ -z "${saved_paths[0]}" ]]; then
        print_status "INFO" "No saved ${path_type} paths found"
        return
    fi
    
    echo "Select path to remove:"
    echo
    local counter=1
    for path in "${saved_paths[@]}"; do
        print_menu_option "$counter" "$(basename "$path")" "$path"
        ((counter++))
    done
    
    echo
    echo "[c] Cancel"
    
    echo
    local choice
    
    while true; do
        echo -n "❯ Select path to remove (1-${#saved_paths[@]}) or 'c' to cancel: "
        read choice
        if [[ "$choice" == "c" ]] || [[ "$choice" == "C" ]]; then
            return
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#saved_paths[@]}" ]]; then
            break
        else
            echo "❌ Invalid choice. Please enter a number between 1 and ${#saved_paths[@]} or 'c' to cancel"
        fi
    done
    
    local path_to_remove="${saved_paths[$((choice-1))]}"
    
    echo -n "❯ Remove path '$path_to_remove'? (y/N) [default: n]: "
    read confirm
    confirm="${confirm:-n}"
    
    if [[ "$confirm" =~ ^[Yy] ]]; then
        remove_saved_path "$path_type" "$path_to_remove"
        print_status "SUCCESS" "Removed ${path_type} path: $path_to_remove"
    else
        print_status "INFO" "Path removal cancelled"
    fi
}

clear_all_saved_paths() {
    print_header
    print_section_header "Clear All Saved Paths"
    
    print_color "RED" "⚠️  WARNING: This will remove ALL saved paths (upload and download)!"
    echo
    echo -n "❯ Are you sure? Type 'YES' to confirm: "
    read confirm
    
    if [[ "$confirm" == "YES" ]]; then
        echo '{"upload_paths": [], "download_paths": []}' > "$SAVED_PATHS_FILE"
        print_status "SUCCESS" "All saved paths cleared"
    else
        print_status "INFO" "Operation cancelled"
    fi
}

# Main menu functions
show_connection_status() {
    # Always refresh validation data from file
    load_last_validation
    
    echo
    print_color "BOLD_CYAN" "📡 LAST CONNECTION VALIDATED"
    print_color "BOLD_BLUE" "$(printf '%*s' 50 | tr ' ' '=')"
    
    if [[ -n "$LAST_VALIDATED_HOST" ]]; then
        if [[ "$LAST_VALIDATION_SUCCESS" == "true" ]]; then
            local status_icon="✅"
            local status_color="GREEN"
            local status_text="SUCCESSFUL"
        else
            local status_icon="❌"
            local status_color="RED"
            local status_text="FAILED"
        fi
        
        print_color "$status_color" "$status_icon Name:        ${LAST_VALIDATED_NAME:-'Unknown'}"
        print_color "$status_color" "$status_icon Host:        $LAST_VALIDATED_HOST"
        print_color "$status_color" "$status_icon User:        $LAST_VALIDATED_USER"
        print_color "$status_color" "$status_icon Port:        $LAST_VALIDATED_PORT"
        print_color "$status_color" "$status_icon Auth Type:   $LAST_VALIDATED_AUTH_TYPE"
        print_color "$status_color" "$status_icon Status:      $status_text"
        print_color "$status_color" "$status_icon Validated:   $LAST_VALIDATED_TIMESTAMP"
    else
        print_color "YELLOW" "⚠️  No connections validated yet"
        print_color "YELLOW" "   Use Setup Connection or select a saved connection to validate"
    fi
    
    echo
    print_color "BOLD_CYAN" "⚙️  SETTINGS"
    print_color "BOLD_BLUE" "$(printf '%*s' 50 | tr ' ' '=')"
    print_color "WHITE" "Debug Mode:    $([ "$DEBUG" == true ] && echo "🟢 ON" || echo "🔴 OFF")"
    print_color "WHITE" "Verbose Mode:  $([ "$VERBOSE" == true ] && echo "🟢 ON" || echo "🔴 OFF")"
    print_color "WHITE" "Timeout:       ${CONNECTION_TIMEOUT}s"
}

settings_menu() {
    while true; do
        print_header
        print_section_header "Settings & Configuration"
        
        show_connection_status
        
        echo
        print_section_header "Settings Options"
        print_menu_option "1" "Toggle Debug Mode" "Enable/disable debug output"
        print_menu_option "2" "Toggle Verbose Mode" "Enable/disable verbose SCP output"
        print_menu_option "3" "Set Connection Timeout" "Change SSH connection timeout"
        print_menu_option "4" "Clear Saved Connections" "Remove all saved connections"
        print_menu_option "5" "Test Connection" "Test current connection and display details"
        print_menu_option "6" "Clear Session Password" "Remove stored password from current session"
        print_menu_option "7" "Back to Main Menu" "Return to main menu"
        
        echo
        local choice
        
        # Direct prompt without command substitution
        while true; do
            echo -n "❯ Select option (1-7): "
            read choice
            if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le 7 ]]; then
                break
            else
                echo "❌ Invalid choice. Please enter a number between 1 and 7"
            fi
        done
        
        case "$choice" in
            1)
                DEBUG=$([ "$DEBUG" == true ] && echo "false" || echo "true")
                print_status "INFO" "Debug mode: $([ "$DEBUG" == true ] && echo "ENABLED" || echo "DISABLED")"
                press_enter_to_continue
                ;;
            2)
                VERBOSE=$([ "$VERBOSE" == true ] && echo "false" || echo "true")
                print_status "INFO" "Verbose mode: $([ "$VERBOSE" == true ] && echo "ENABLED" || echo "DISABLED")"
                press_enter_to_continue
                ;;
            3)
                local new_timeout
                new_timeout=$(prompt_input "Enter connection timeout (seconds)" "$CONNECTION_TIMEOUT")
                if [[ "$new_timeout" =~ ^[0-9]+$ ]] && [[ "$new_timeout" -gt 0 ]]; then
                    CONNECTION_TIMEOUT="$new_timeout"
                    print_status "SUCCESS" "Connection timeout set to ${CONNECTION_TIMEOUT}s"
                else
                    print_status "ERROR" "Invalid timeout value"
                fi
                press_enter_to_continue
                ;;
            4)
                local confirm
                confirm=$(prompt_input "Clear all saved connections? (y/N)" "n")
                if [[ "$confirm" =~ ^[Yy] ]]; then
                    rm -f "$SAVED_CONNECTIONS_FILE"
                    print_status "SUCCESS" "Saved connections cleared"
                else
                    print_status "INFO" "Operation cancelled"
                fi
                press_enter_to_continue
                ;;
            5)
                # Test connection with proper authentication handling
                print_header
                print_section_header "Connection Test"
                
                if [[ -z "$REMOTE_HOST" ]]; then
                    print_status "ERROR" "No connection configured"
                    press_enter_to_continue
                    continue
                fi
                
                echo "Testing connection to $REMOTE_USER@$REMOTE_HOST:$REMOTE_PORT"
                echo
                
                local connection_successful=false
                
                if [[ -z "$SSH_KEY" ]]; then
                    # Password authentication
                    if [[ -n "$REMOTE_PASSWORD" ]]; then
                        # Use stored password from current session
                        print_progress "Testing with stored session password..."
                        if test_ssh_connection_with_password "$REMOTE_HOST" "$REMOTE_USER" "$REMOTE_PORT" "$REMOTE_PASSWORD"; then
                            connection_successful=true
                        fi
                    else
                        # Prompt for password
                        echo -n "❯ Enter password for $REMOTE_USER@$REMOTE_HOST: "
                        read -s password
                        echo  # Add newline after hidden password input
                        
                        if [[ -n "$password" ]]; then
                            print_progress "Testing with entered password..."
                            if test_ssh_connection_with_password "$REMOTE_HOST" "$REMOTE_USER" "$REMOTE_PORT" "$password"; then
                                connection_successful=true
                                # Store password for this session
                                REMOTE_PASSWORD="$password"
                                print_status "INFO" "Password stored for current session"
                            fi
                        else
                            print_status "ERROR" "Password cannot be empty"
                        fi
                    fi
                else
                    # SSH key authentication
                    print_progress "Testing with SSH key authentication..."
                    if test_ssh_connection "$REMOTE_HOST" "$REMOTE_USER" "$REMOTE_PORT" "$SSH_KEY"; then
                        connection_successful=true
                    fi
                fi
                
                # Record the validation attempt
                local auth_type_display
                if [[ -z "$SSH_KEY" ]]; then
                    auth_type_display="Password"
                else
                    auth_type_display="SSH Key"
                fi
                
                record_connection_validation "Current Connection" "$REMOTE_HOST" "$REMOTE_USER" "$REMOTE_PORT" "$auth_type_display" "$connection_successful"
                
                echo
                if [[ "$connection_successful" == true ]]; then
                    print_status "SUCCESS" "Connection test successful!"
                    echo
                    print_color "GREEN" "✅ Connection Details:"
                    print_color "GREEN" "   • Host: $REMOTE_HOST"
                    print_color "GREEN" "   • User: $REMOTE_USER"
                    print_color "GREEN" "   • Port: $REMOTE_PORT"
                    if [[ -z "$SSH_KEY" ]]; then
                        print_color "GREEN" "   • Auth: Password (stored for session)"
                    else
                        print_color "GREEN" "   • Auth: SSH Key ($SSH_KEY)"
                    fi
                    print_color "GREEN" "   • Remote Path: ${REMOTE_PATH:-'Not Set'}"
                else
                    print_status "ERROR" "Connection test failed!"
                    echo
                    print_color "YELLOW" "💡 Troubleshooting tips:"
                    print_color "YELLOW" "   • Verify the hostname/IP is correct: $REMOTE_HOST"
                    print_color "YELLOW" "   • Check if the port is accessible: $REMOTE_PORT"
                    print_color "YELLOW" "   • Confirm the username is correct: $REMOTE_USER"
                    
                    if [[ -z "$SSH_KEY" ]]; then
                        print_color "YELLOW" "   • Verify the password is correct"
                        print_color "YELLOW" "   • Check if password authentication is enabled on the server"
                    else
                        print_color "YELLOW" "   • Verify the SSH key path: $SSH_KEY"
                        print_color "YELLOW" "   • Check if the public key is authorized on the server"
                    fi
                fi
                
                press_enter_to_continue
                ;;
            6)
                # Clear session password
                if [[ -n "$REMOTE_PASSWORD" ]]; then
                    REMOTE_PASSWORD=""
                    print_status "SUCCESS" "Session password cleared"
                else
                    print_status "INFO" "No session password was stored"
                fi
                press_enter_to_continue
                ;;
            7)
                return
                ;;
        esac
    done
}

main_menu() {
    while true; do
        print_header
        show_connection_status
        
        print_section_header "Main Menu"
        print_menu_option "1" "Setup Connection" "Configure SSH connection to remote host"
        print_menu_option "2" "Manage Connections" "View, edit, and manage saved connections"
        print_menu_option "3" "Manage Saved Paths" "View, edit, and manage saved upload/download paths"
        print_menu_option "4" "Browse Remote Files" "Navigate and explore remote directories"
        print_menu_option "5" "Upload Files" "Transfer files from local to remote"
        print_menu_option "6" "Download Files" "Transfer files from remote to local"
        print_menu_option "7" "Manage Transfers" "Create, edit, and manage saved transfer configurations"
        print_menu_option "8" "Folder Navigator" "Interactive local folder navigation with multiple views"
        print_menu_option "9" "Remote Navigator" "Interactive remote folder navigation with multiple views"
        print_menu_option "10" "Quick Transfer" "Fast file transfer with current settings"
        print_menu_option "11" "Settings" "Configure application settings"
        print_menu_option "12" "Help" "Show help and usage information"
        print_menu_option "13" "Exit" "Quit the application"
        
        echo
        local choice
        
        # Direct prompt without command substitution
        while true; do
            echo -n "❯ Select option (1-13): "
            read choice
            if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le 13 ]]; then
                break
            else
                echo "❌ Invalid choice. Please enter a number between 1 and 13"
            fi
        done
        
        case "$choice" in
            1)
                if ! load_saved_connections; then
                    setup_ssh_connection
                fi
                press_enter_to_continue
                ;;
            2)
                manage_connections_menu
                ;;
            3)
                manage_saved_paths_menu
                ;;
            4)
                if select_saved_connection "browse"; then
                    browse_remote_directory "" "detailed"
                fi
                press_enter_to_continue
                ;;
            5)
                upload_files
                press_enter_to_continue
                ;;
            6)
                download_files
                press_enter_to_continue
                ;;
            7)
                manage_transfers_menu
                ;;
            8)
                folder_navigator_menu
                ;;
            9)
                remote_folder_navigator_menu
                ;;
            10)
                quick_transfer_menu
                ;;
            11)
                settings_menu
                ;;
            12)
                show_help
                ;;
            13)
                print_color "BOLD_CYAN" "👋 Thank you for using SCP Manager!"
                exit 0
                ;;
        esac
    done
}

# Transfers Management Functions
initialize_transfers_dir() {
    local transfers_dir="$HOME/.scp_manager"
    if [[ ! -d "$transfers_dir" ]]; then
        mkdir -p "$transfers_dir"
    fi
    
    local transfers_file="$transfers_dir/scp_saved_transfers.json"
    if [[ ! -f "$transfers_file" ]]; then
        echo "[]" > "$transfers_file"
        if [[ "$DEBUG" == true ]]; then
            debug_log "Created transfers file: $transfers_file"
        fi
    fi
}

manage_transfers_menu() {
    while true; do
        print_header
        print_section_header "Manage Transfers"
        
        print_menu_option "1" "New Transfer" "Create a new transfer configuration"
        print_menu_option "2" "List Transfers" "View all saved transfer configurations"
        print_menu_option "3" "Edit Transfer" "Modify an existing transfer"
        print_menu_option "4" "Run a saved SCP transfer" "Execute a saved transfer configuration"
        print_menu_option "5" "Delete Transfer" "Remove a specific transfer"
        print_menu_option "6" "Delete ALL Transfers" "Remove all saved transfers"
        print_menu_option "7" "Back to Main Menu" "Return to main menu"
        
        echo
        local choice
        
        while true; do
            echo -n "❯ Select option (1-7): "
            read choice
            if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le 7 ]]; then
                break
            else
                echo "❌ Invalid choice. Please enter a number between 1 and 7"
            fi
        done
        
        case "$choice" in
            1)
                create_new_transfer
                press_enter_to_continue
                ;;
            2)
                list_transfers
                press_enter_to_continue
                ;;
            3)
                edit_transfer
                press_enter_to_continue
                ;;
            4)
                execute_saved_transfer
                press_enter_to_continue
                ;;
            5)
                delete_transfer
                press_enter_to_continue
                ;;
            6)
                delete_all_transfers
                press_enter_to_continue
                ;;
            7)
                return
                ;;
        esac
    done
}

create_new_transfer() {
    print_header
    print_section_header "Create New Transfer"
    
    initialize_transfers_dir
    
    local transfer_name=""
    local remote_host=""
    local remote_user=""
    local auth_method=""
    local ssh_key=""
    local password=""
    local source_path=""
    local dest_path=""
    local operation=""
    
    # Get transfer name
    echo -n "❯ Transfer name: "
    read transfer_name
    if [[ -z "$transfer_name" ]]; then
        print_status "ERROR" "Transfer name cannot be empty"
        return 1
    fi
    
    # Get remote host
    echo -n "❯ Remote host (FQDN/IP): "
    read remote_host
    if [[ -z "$remote_host" ]]; then
        print_status "ERROR" "Remote host cannot be empty"
        return 1
    fi
    
    # Get remote user
    echo -n "❯ Remote user: "
    read remote_user
    if [[ -z "$remote_user" ]]; then
        print_status "ERROR" "Remote user cannot be empty"
        return 1
    fi
    
    # Choose authentication method
    echo
    print_section_header "Authentication Method"
    print_menu_option "1" "SSH Key" "Use SSH private key for authentication"
    print_menu_option "2" "Password" "Use password for authentication"
    
    echo
    while true; do
        echo -n "❯ Choose authentication method (1-2): "
        read auth_choice
        case "$auth_choice" in
            1)
                auth_method="ssh_key"
                echo -n "❯ SSH key path: "
                read ssh_key
                if [[ -n "$ssh_key" ]] && [[ ! -f "$ssh_key" ]]; then
                    print_status "WARNING" "SSH key file does not exist: $ssh_key"
                    echo -n "❯ Continue anyway? (y/N): "
                    read continue_choice
                    if [[ ! "$continue_choice" =~ ^[Yy] ]]; then
                        return 1
                    fi
                fi
                break
                ;;
            2)
                auth_method="password"
                echo -n "❯ Password: "
                read -s password
                echo
                break
                ;;
            *)
                echo "❌ Invalid choice. Please enter 1 or 2"
                ;;
        esac
    done
    
    # Test connection
    echo
    print_progress "Testing connection..."
    local test_cmd
    if [[ "$auth_method" == "ssh_key" ]]; then
        test_cmd="ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no"
        if [[ -n "$ssh_key" ]]; then
            test_cmd="$test_cmd -i '$ssh_key'"
        fi
        test_cmd="$test_cmd '$remote_user@$remote_host' 'echo Connection successful'"
    else
        # For password, we'll use a basic connectivity test
        test_cmd="ping -c 1 -W 5 '$remote_host'"
    fi
    
    if eval "$test_cmd" >/dev/null 2>&1; then
        print_status "SUCCESS" "Connection test successful"
    else
        print_status "ERROR" "Connection test failed"
        echo -n "❯ Continue anyway? (y/N): "
        read continue_choice
        if [[ ! "$continue_choice" =~ ^[Yy] ]]; then
            return 1
        fi
    fi
    
    # Get source path
    echo
    echo -n "❯ Source path (file or directory): "
    read source_path
    if [[ -z "$source_path" ]]; then
        print_status "ERROR" "Source path cannot be empty"
        return 1
    fi
    
    # Get destination path
    echo -n "❯ Destination path: "
    read dest_path
    if [[ -z "$dest_path" ]]; then
        print_status "ERROR" "Destination path cannot be empty"
        return 1
    fi
    
    # Choose operation type
    echo
    print_section_header "Transfer Operation"
    print_menu_option "1" "Download" "Download from remote to local"
    print_menu_option "2" "Upload" "Upload from local to remote"
    
    echo
    while true; do
        echo -n "❯ Choose operation (1-2): "
        read op_choice
        case "$op_choice" in
            1)
                operation="download"
                echo
                print_status "INFO" "Download operation: $remote_user@$remote_host:$source_path → $dest_path"
                break
                ;;
            2)
                operation="upload"
                echo
                print_status "INFO" "Upload operation: $source_path → $remote_user@$remote_host:$dest_path"
                break
                ;;
            *)
                echo "❌ Invalid choice. Please enter 1 or 2"
                ;;
        esac
    done
    
    # Validate paths and detect file/directory types
    echo
    print_section_header "Path Validation"
    
    print_progress "Validating source path..."
    if validate_transfer_source_path "$source_path" "$operation" "$remote_host" "$remote_user" "$auth_method" "$ssh_key"; then
        local source_type=$(cat /tmp/.scp_source_type 2>/dev/null || echo "unknown")
        print_status "SUCCESS" "Source path validated ($source_type)"
    else
        print_status "ERROR" "Source path validation failed"
        echo -n "❯ Continue anyway? (y/N): "
        read continue_choice
        if [[ ! "$continue_choice" =~ ^[Yy] ]]; then
            return 1
        fi
        echo "file" > /tmp/.scp_source_type  # Default to file if validation fails
    fi
    
    print_progress "Validating destination path..."
    if validate_transfer_dest_path "$dest_path" "$operation" "$remote_host" "$remote_user" "$auth_method" "$ssh_key"; then
        print_status "SUCCESS" "Destination path validated"
    else
        print_status "ERROR" "Destination path validation failed"
        echo -n "❯ Continue anyway? (y/N): "
        read continue_choice
        if [[ ! "$continue_choice" =~ ^[Yy] ]]; then
            return 1
        fi
    fi
    
    # Build enhanced SCP command with proper directory/file detection
    local scp_command=$(build_enhanced_scp_command "$operation" "$source_path" "$dest_path" "$remote_host" "$remote_user" "$auth_method" "$ssh_key")
    
    echo
    print_section_header "Generated SCP Command"
    local source_type=$(cat /tmp/.scp_source_type 2>/dev/null || echo "unknown")
    echo "Source Type: $source_type"
    echo "Command: $scp_command"
    
    # Save the transfer
    echo
    echo -n "❯ Save this transfer configuration? (y/N): "
    read save_choice
    if [[ "$save_choice" =~ ^[Yy] ]]; then
        save_transfer "$transfer_name" "$remote_host" "$remote_user" "$auth_method" "$ssh_key" "$password" "$source_path" "$dest_path" "$operation" "$scp_command"
        print_status "SUCCESS" "Transfer configuration saved: $transfer_name"
    else
        print_status "INFO" "Transfer configuration not saved"
    fi
}

save_transfer() {
    local name="$1"
    local host="$2" 
    local user="$3"
    local auth="$4"
    local key="$5"
    local pass="$6"
    local source="$7"
    local dest="$8"
    local op="$9"
    local cmd="${10}"
    
    local transfers_file="$HOME/.scp_manager/scp_saved_transfers.json"
    
    # Create new transfer object
    local new_transfer=$(cat << EOF
{
    "id": "${user}@${host}_$(date +%s)",
    "name": "$name",
    "remote_host": "$host",
    "remote_user": "$user",
    "auth_method": "$auth",
    "ssh_key": "$key",
    "password": "$pass",
    "source_path": "$source",
    "dest_path": "$dest",
    "operation": "$op",
    "scp_command": "$cmd",
    "created": "$(date '+%Y-%m-%d %H:%M:%S')",
    "last_used": ""
}
EOF
)
    
    # Add to transfers file
    local updated_transfers
    if [[ -s "$transfers_file" ]]; then
        updated_transfers=$(jq ". += [$new_transfer]" "$transfers_file" 2>/dev/null)
    else
        updated_transfers="[$new_transfer]"
    fi
    
    if [[ -n "$updated_transfers" ]]; then
        echo "$updated_transfers" > "$transfers_file"
        if [[ "$DEBUG" == true ]]; then
            debug_log "Saved transfer: $name"
        fi
    else
        print_status "ERROR" "Failed to save transfer configuration"
        return 1
    fi
}

list_transfers() {
    print_header
    print_section_header "Saved Transfer Configurations"
    
    initialize_transfers_dir
    local transfers_file="$HOME/.scp_manager/scp_saved_transfers.json"
    
    if [[ ! -f "$transfers_file" ]] || [[ ! -s "$transfers_file" ]]; then
        print_status "INFO" "No transfer configurations found"
        return 0
    fi
    
    local transfers_count=$(jq 'length' "$transfers_file" 2>/dev/null)
    
    if [[ "$transfers_count" -eq 0 ]]; then
        print_status "INFO" "No transfer configurations found"
        return 0
    fi
    
    echo
    # Improved column headers with better spacing
    printf "%-3s %-18s %-18s %-12s %-10s %-12s\n" "No." "Name" "Host" "User" "Operation" "Created"
    print_color "BOLD_BLUE" "$(printf '%*s' 80 | tr ' ' '=')"
    
    local counter=1
    while read -r transfer; do
        local name=$(echo "$transfer" | jq -r '.name')
        local host=$(echo "$transfer" | jq -r '.remote_host')
        local user=$(echo "$transfer" | jq -r '.remote_user')
        local operation=$(echo "$transfer" | jq -r '.operation')
        local source=$(echo "$transfer" | jq -r '.source_path')
        local dest=$(echo "$transfer" | jq -r '.dest_path')
        local created=$(echo "$transfer" | jq -r '.created' | cut -d' ' -f1)
        
        # Truncate long fields for table display
        [[ ${#name} -gt 17 ]] && name="${name:0:14}..."
        [[ ${#host} -gt 17 ]] && host="${host:0:14}..."
        [[ ${#user} -gt 11 ]] && user="${user:0:8}..."
        
        printf "%-3s %-18s %-18s %-12s %-10s %-12s\n" "$counter" "$name" "$host" "$user" "$operation" "$created"
        
        # Show full paths on separate lines with proper indentation
        echo -e "    ${COLORS[CYAN]}Source:${COLORS[RESET]} $source"
        echo -e "    ${COLORS[CYAN]}Dest:${COLORS[RESET]}   $dest"
        echo # Empty line between transfers
        
        ((counter++))
    done < <(jq -c '.[]' "$transfers_file" 2>/dev/null)
}

edit_transfer() {
    print_header
    print_section_header "Edit Transfer Configuration"
    
    initialize_transfers_dir
    local transfers_file="$HOME/.scp_manager/scp_saved_transfers.json"
    
    if [[ ! -f "$transfers_file" ]] || [[ ! -s "$transfers_file" ]]; then
        print_status "INFO" "No transfer configurations found"
        return 0
    fi
    
    # List transfers for selection
    list_transfers
    
    echo
    local transfers_count=$(jq 'length' "$transfers_file" 2>/dev/null)
    
    if [[ "$transfers_count" -eq 0 ]]; then
        return 0
    fi
    
    echo -n "❯ Select transfer to edit (1-$transfers_count) or 'c' to cancel: "
    read transfer_choice
    
    if [[ "$transfer_choice" == "c" ]] || [[ "$transfer_choice" == "C" ]]; then
        return 0
    fi
    
    if [[ ! "$transfer_choice" =~ ^[0-9]+$ ]] || [[ "$transfer_choice" -lt 1 ]] || [[ "$transfer_choice" -gt "$transfers_count" ]]; then
        print_status "ERROR" "Invalid selection"
        return 1
    fi
    
    # Get the selected transfer
    local transfer_index=$((transfer_choice - 1))
    local transfer=$(jq -c ".[$transfer_index]" "$transfers_file" 2>/dev/null)
    
    echo
    print_section_header "Edit Fields"
    print_menu_option "1" "Name" "Transfer name"
    print_menu_option "2" "Remote Host" "Remote hostname or IP"
    print_menu_option "3" "Remote User" "Remote username"
    print_menu_option "4" "SSH Key" "SSH private key path"
    print_menu_option "5" "Source Path" "Source file/directory path"
    print_menu_option "6" "Destination Path" "Destination path"
    print_menu_option "7" "Operation" "Upload or Download"
    print_menu_option "8" "Save Changes" "Save modifications"
    print_menu_option "9" "Cancel" "Cancel editing"
    
    echo
    while true; do
        echo -n "❯ Select field to edit (1-9): "
        read field_choice
        
        case "$field_choice" in
            1)
                local current_name=$(echo "$transfer" | jq -r '.name')
                echo "Current name: $current_name"
                echo -n "❯ New name: "
                read new_name
                if [[ -n "$new_name" ]]; then
                    transfer=$(echo "$transfer" | jq ".name = \"$new_name\"")
                    print_status "SUCCESS" "Name updated"
                fi
                ;;
            2)
                local current_host=$(echo "$transfer" | jq -r '.remote_host')
                echo "Current host: $current_host"
                echo -n "❯ New host: "
                read new_host
                if [[ -n "$new_host" ]]; then
                    transfer=$(echo "$transfer" | jq ".remote_host = \"$new_host\"")
                    print_status "SUCCESS" "Remote host updated"
                fi
                ;;
            3)
                local current_user=$(echo "$transfer" | jq -r '.remote_user')
                echo "Current user: $current_user"
                echo -n "❯ New user: "
                read new_user
                if [[ -n "$new_user" ]]; then
                    transfer=$(echo "$transfer" | jq ".remote_user = \"$new_user\"")
                    print_status "SUCCESS" "Remote user updated"
                fi
                ;;
            4)
                local current_key=$(echo "$transfer" | jq -r '.ssh_key')
                echo "Current SSH key: $current_key"
                echo -n "❯ New SSH key path: "
                read new_key
                transfer=$(echo "$transfer" | jq ".ssh_key = \"$new_key\"")
                print_status "SUCCESS" "SSH key updated"
                ;;
            5)
                local current_source=$(echo "$transfer" | jq -r '.source_path')
                echo "Current source: $current_source"
                echo -n "❯ New source path: "
                read new_source
                if [[ -n "$new_source" ]]; then
                    transfer=$(echo "$transfer" | jq ".source_path = \"$new_source\"")
                    print_status "SUCCESS" "Source path updated"
                fi
                ;;
            6)
                local current_dest=$(echo "$transfer" | jq -r '.dest_path')
                echo "Current destination: $current_dest"
                echo -n "❯ New destination path: "
                read new_dest
                if [[ -n "$new_dest" ]]; then
                    transfer=$(echo "$transfer" | jq ".dest_path = \"$new_dest\"")
                    print_status "SUCCESS" "Destination path updated"
                fi
                ;;
            7)
                local current_op=$(echo "$transfer" | jq -r '.operation')
                echo "Current operation: $current_op"
                echo "[1] Download  [2] Upload"
                echo -n "❯ Choose operation (1-2): "
                read op_choice
                case "$op_choice" in
                    1)
                        transfer=$(echo "$transfer" | jq '.operation = "download"')
                        print_status "SUCCESS" "Operation set to download"
                        ;;
                    2)
                        transfer=$(echo "$transfer" | jq '.operation = "upload"')
                        print_status "SUCCESS" "Operation set to upload"
                        ;;
                    *)
                        print_status "ERROR" "Invalid choice"
                        ;;
                esac
                ;;
            8)
                # Rebuild SCP command
                local new_host=$(echo "$transfer" | jq -r '.remote_host')
                local new_user=$(echo "$transfer" | jq -r '.remote_user')
                local new_key=$(echo "$transfer" | jq -r '.ssh_key')
                local new_source=$(echo "$transfer" | jq -r '.source_path')
                local new_dest=$(echo "$transfer" | jq -r '.dest_path')
                local new_op=$(echo "$transfer" | jq -r '.operation')
                
                local new_scp_command
                if [[ "$new_op" == "download" ]]; then
                    if [[ -n "$new_key" && "$new_key" != "null" ]]; then
                        new_scp_command="scp -i '$new_key' '$new_user@$new_host:$new_source' '$new_dest'"
                    else
                        new_scp_command="scp '$new_user@$new_host:$new_source' '$new_dest'"
                    fi
                else
                    if [[ -n "$new_key" && "$new_key" != "null" ]]; then
                        new_scp_command="scp -i '$new_key' '$new_source' '$new_user@$new_host:$new_dest'"
                    else
                        new_scp_command="scp '$new_source' '$new_user@$new_host:$new_dest'"
                    fi
                fi
                
                transfer=$(echo "$transfer" | jq ".scp_command = \"$new_scp_command\"")
                
                # Update the transfer in the file
                local updated_transfers=$(jq ".[$transfer_index] = $transfer" "$transfers_file")
                echo "$updated_transfers" > "$transfers_file"
                
                print_status "SUCCESS" "Transfer configuration updated"
                return 0
                ;;
            9)
                print_status "INFO" "Edit cancelled"
                return 0
                ;;
            *)
                echo "❌ Invalid choice. Please enter a number between 1 and 9"
                ;;
        esac
        echo
    done
}

execute_saved_transfer() {
    print_header
    print_section_header "Execute Saved Transfer"
    
    initialize_transfers_dir
    local transfers_file="$HOME/.scp_manager/scp_saved_transfers.json"
    
    if [[ ! -f "$transfers_file" ]] || [[ ! -s "$transfers_file" ]]; then
        print_status "INFO" "No transfer configurations found"
        return 0
    fi
    
    # List transfers for selection
    list_transfers
    
    echo
    local transfers_count=$(jq 'length' "$transfers_file" 2>/dev/null)
    
    if [[ "$transfers_count" -eq 0 ]]; then
        return 0
    fi
    
    echo -n "❯ Select transfer to execute (1-$transfers_count) or 'c' to cancel: "
    read transfer_choice
    
    if [[ "$transfer_choice" == "c" ]] || [[ "$transfer_choice" == "C" ]]; then
        return 0
    fi
    
    if [[ ! "$transfer_choice" =~ ^[0-9]+$ ]] || [[ "$transfer_choice" -lt 1 ]] || [[ "$transfer_choice" -gt "$transfers_count" ]]; then
        print_status "ERROR" "Invalid selection"
        return 1
    fi
    
    # Get the selected transfer
    local transfer_index=$((transfer_choice - 1))
    local transfer=$(jq -c ".[$transfer_index]" "$transfers_file" 2>/dev/null)
    
    local name=$(echo "$transfer" | jq -r '.name')
    local host=$(echo "$transfer" | jq -r '.remote_host')
    local user=$(echo "$transfer" | jq -r '.remote_user')
    local auth_method=$(echo "$transfer" | jq -r '.auth_method')
    local ssh_key=$(echo "$transfer" | jq -r '.ssh_key // empty')
    local source_path=$(echo "$transfer" | jq -r '.source_path')
    local dest_path=$(echo "$transfer" | jq -r '.dest_path')
    local operation=$(echo "$transfer" | jq -r '.operation')
    local scp_command=$(echo "$transfer" | jq -r '.scp_command')
    
    echo
    print_section_header "Transfer Details"
    echo -e "${COLORS[CYAN]}Name:${COLORS[RESET]}      $name"
    echo -e "${COLORS[CYAN]}Host:${COLORS[RESET]}      $host"
    echo -e "${COLORS[CYAN]}User:${COLORS[RESET]}      $user"
    echo -e "${COLORS[CYAN]}Auth:${COLORS[RESET]}      $auth_method"
    [[ -n "$ssh_key" ]] && echo -e "${COLORS[CYAN]}SSH Key:${COLORS[RESET]}   $ssh_key"
    echo -e "${COLORS[CYAN]}Operation:${COLORS[RESET]} $operation"
    echo -e "${COLORS[CYAN]}Source:${COLORS[RESET]}    $source_path"
    echo -e "${COLORS[CYAN]}Dest:${COLORS[RESET]}      $dest_path"
    echo -e "${COLORS[CYAN]}Command:${COLORS[RESET]}   $scp_command"
    
    echo
    print_section_header "Pre-Transfer Validation"
    
    # Step 1: Test connection
    print_progress "1/3: Testing SSH connection..."
    if validate_transfer_connection "$host" "$user" "$auth_method" "$ssh_key"; then
        if [[ "$auth_method" == "ssh_key" ]] && [[ -n "$ssh_key" ]]; then
            print_status "SUCCESS" "SSH connection validated (SSH key)"
        else
            print_status "SUCCESS" "SSH service reachable (password auth will be tested during transfer)"
        fi
    else
        if [[ "$auth_method" == "ssh_key" ]] && [[ -n "$ssh_key" ]]; then
            print_status "ERROR" "SSH connection failed with SSH key"
        else
            print_status "WARNING" "Cannot reach SSH service on port 22"
        fi
        echo
        echo -n "❯ Continue anyway? (y/N): "
        read continue_choice
        if [[ ! "$continue_choice" =~ ^[Yy] ]]; then
            print_status "INFO" "Transfer cancelled"
            return 0
        fi
    fi
    
    # Step 2: Validate source path
    print_progress "2/3: Validating source path..."
    if validate_transfer_source_path "$source_path" "$operation" "$host" "$user" "$auth_method" "$ssh_key"; then
        print_status "SUCCESS" "Source path validated"
    else
        print_status "ERROR" "Source path validation failed"
        echo
        echo -n "❯ Continue anyway? (y/N): "
        read continue_choice
        if [[ ! "$continue_choice" =~ ^[Yy] ]]; then
            print_status "INFO" "Transfer cancelled"
            return 0
        fi
    fi
    
    # Step 3: Validate destination path
    print_progress "3/3: Validating destination path..."
    if validate_transfer_dest_path "$dest_path" "$operation" "$host" "$user" "$auth_method" "$ssh_key"; then
        if [[ "$operation" == "upload" ]] && [[ "$auth_method" != "ssh_key" || -z "$ssh_key" ]]; then
            print_status "SUCCESS" "Destination path validation skipped (password auth - will verify during transfer)"
        else
            print_status "SUCCESS" "Destination path validated"
        fi
    else
        if [[ "$operation" == "upload" ]]; then
            print_status "ERROR" "Remote destination path validation failed"
        else
            print_status "ERROR" "Local destination path validation failed"
        fi
        echo
        echo -n "❯ Continue anyway? (y/N): "
        read continue_choice
        if [[ ! "$continue_choice" =~ ^[Yy] ]]; then
            print_status "INFO" "Transfer cancelled"
            return 0
        fi
    fi
    
    echo
    print_section_header "Ready to Execute"
    print_color "GREEN" "✅ All validations completed"
    
    # Build and show the enhanced command that will be executed
    local enhanced_scp_command=$(build_enhanced_scp_command "$operation" "$source_path" "$dest_path" "$host" "$user" "$auth_method" "$ssh_key" "true")
    
    echo
    print_color "BOLD_CYAN" "🔍 Command that will be executed:"
    format_enhanced_command_display "$enhanced_scp_command"
    
    echo
    echo -n "❯ Execute this transfer now? (y/N): "
    read execute_choice
    
    if [[ "$execute_choice" =~ ^[Yy] ]]; then
        echo
        print_section_header "Final Pre-Execution Validation"
        
        # Fast re-validation before execution
        print_progress "Re-validating connection..."
        validate_transfer_connection "$host" "$user" "$auth_method" "$ssh_key" >/dev/null 2>&1
        
        print_progress "Re-validating source path..."
        validate_transfer_source_path "$source_path" "$operation" "$host" "$user" "$auth_method" "$ssh_key" >/dev/null 2>&1
        
        print_progress "Re-validating destination path..."
        validate_transfer_dest_path "$dest_path" "$operation" "$host" "$user" "$auth_method" "$ssh_key" >/dev/null 2>&1
        
        echo
        print_section_header "Executing Transfer"
        print_progress "Starting transfer: $name"
        
        # Record transfer start time
        local start_time=$(date +%s)
        local start_time_formatted=$(date '+%Y-%m-%d %H:%M:%S')
        
        print_color "CYAN" "⏰ Transfer started at: $start_time_formatted"
        echo
        
        # Execute the enhanced transfer command with live progress display
        echo "📤 Transfer in progress..."
        echo
        
        # Create a log file to capture all output for analysis
        local transfer_log=$(mktemp)
        
        # Execute command and capture output while showing it live
        # Use script command to ensure SCP shows progress bars
        script -q -c "$enhanced_scp_command" "$transfer_log" 2>&1
        local exit_code=$?
        
        # Read the captured output for analysis
        local scp_output
        scp_output=$(cat "$transfer_log" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | sed 's/\r/\n/g')
        
        # Clean up
        rm -f "$transfer_log" 2>/dev/null
        
        # Calculate and display transfer timing
        local end_time=$(date +%s)
        local end_time_formatted=$(date '+%Y-%m-%d %H:%M:%S')
        local duration=$((end_time - start_time))
        local duration_formatted=$(printf '%02d:%02d:%02d' $((duration/3600)) $((duration%3600/60)) $((duration%60)))
        
        echo
        print_color "CYAN" "⏰ Transfer completed at: $end_time_formatted"
        print_color "CYAN" "⏱️  Total duration: $duration_formatted"
        
        # Extract transfer statistics from SCP output
        local transfer_stats=$(echo "$scp_output" | grep -E "[0-9]+%" | tail -1)
        if [[ -n "$transfer_stats" ]]; then
            local size_info=$(echo "$transfer_stats" | grep -oE '[0-9]+[KMG]?B' | head -1)
            local speed_info=$(echo "$transfer_stats" | grep -oE '[0-9]+\.[0-9]+[KMG]?B/s')
            if [[ -n "$size_info" ]] && [[ -n "$speed_info" ]]; then
                print_color "CYAN" "📊 Final stats: $size_info transferred at $speed_info"
            fi
        fi
        
        echo
        # Enhanced transfer analysis
        analyze_transfer_results "$scp_output" "$exit_code"
        
        # Update last_used timestamp if any files were transferred
        if [[ $exit_code -eq 0 ]] || [[ $(echo "$scp_output" | grep -c "100%") -gt 0 ]]; then
            local updated_transfers=$(jq ".[$transfer_index].last_used = \"$(date '+%Y-%m-%d %H:%M:%S')\"" "$transfers_file")
            echo "$updated_transfers" > "$transfers_file"
        fi
        
        echo
        print_section_header "Transfer Complete"
        echo -n "❯ Press Enter to return to transfers menu..."
        read
    else
        print_status "INFO" "Transfer cancelled"
    fi
}

# Validation helper functions for transfer execution
validate_transfer_connection() {
    local host="$1"
    local user="$2"
    local auth_method="$3"
    local ssh_key="$4"
    
    if [[ "$auth_method" == "ssh_key" ]] && [[ -n "$ssh_key" ]]; then
        # Use existing SSH key test function
        test_ssh_connection "$host" "$user" "22" "$ssh_key"
        return $?
    else
        # For password authentication, we can't validate without prompting for password
        # So we'll just check if the host is reachable and SSH service is running
        local ssh_cmd="ssh -o ConnectTimeout=10 -o BatchMode=yes -o PasswordAuthentication=no"
        ssh_cmd="$ssh_cmd $user@$host exit"
        
        # Check if SSH service is reachable (even if authentication fails, this means SSH is available)
        if eval "$ssh_cmd" >/dev/null 2>&1; then
            return 0  # SSH key worked
        else
            # Check if we can at least reach the SSH port
            if command -v nc >/dev/null 2>&1; then
                nc -z -w5 "$host" 22 >/dev/null 2>&1
                return $?
            elif command -v timeout >/dev/null 2>&1; then
                timeout 5 bash -c "</dev/tcp/$host/22" >/dev/null 2>&1
                return $?
            else
                # Fallback: assume connection is possible (we'll find out during actual transfer)
                return 0
            fi
        fi
    fi
}

validate_transfer_source_path() {
    local source_path="$1"
    local operation="$2"
    local host="$3"
    local user="$4"
    local auth_method="$5"
    local ssh_key="$6"
    
    if [[ "$operation" == "upload" ]]; then
        # For upload, source is local
        if [[ -e "$source_path" ]]; then
            # Store type information for later use
            if [[ -d "$source_path" ]]; then
                echo "directory" > /tmp/.scp_source_type
            else
                echo "file" > /tmp/.scp_source_type
            fi
            return 0
        else
            return 1
        fi
    else
        # For download, source is remote
        if [[ "$auth_method" == "ssh_key" ]] && [[ -n "$ssh_key" ]]; then
            # Use SSH key authentication
            local ssh_cmd="ssh -o ConnectTimeout=10 -o BatchMode=yes -i '$ssh_key'"
            
            # Check if source exists and determine type
            if eval "$ssh_cmd $user@$host test -e '$source_path'" >/dev/null 2>&1; then
                if eval "$ssh_cmd $user@$host test -d '$source_path'" >/dev/null 2>&1; then
                    echo "directory" > /tmp/.scp_source_type
                else
                    echo "file" > /tmp/.scp_source_type
                fi
                return 0
            else
                return 1
            fi
        else
            # For password authentication, we can't validate without prompting
            # Assume the path exists and let the actual transfer handle the error
            echo "file" > /tmp/.scp_source_type
            return 0
        fi
    fi
}

validate_transfer_dest_path() {
    local dest_path="$1"
    local operation="$2"
    local host="$3"
    local user="$4"
    local auth_method="$5"
    local ssh_key="$6"
    
    if [[ "$operation" == "upload" ]]; then
        # For upload, destination is remote
        if [[ "$auth_method" == "ssh_key" ]] && [[ -n "$ssh_key" ]]; then
            # Use SSH key authentication
            local ssh_cmd="ssh -o ConnectTimeout=10 -o BatchMode=yes -i '$ssh_key'"
            
            # Check if destination directory exists
            local dest_dir="$dest_path"
            if [[ "$dest_path" != */ ]]; then
                dest_dir=$(dirname "$dest_path")
            fi
            
            ssh_cmd="$ssh_cmd $user@$host test -d '$dest_dir'"
            
            eval "$ssh_cmd" >/dev/null 2>&1
            return $?
        else
            # For password authentication, we can't validate without prompting
            # Assume the destination exists and let the actual transfer handle the error
            return 0
        fi
    else
        # For download, destination is local
        local dest_dir="$dest_path"
        if [[ "$dest_path" != */ ]]; then
            dest_dir=$(dirname "$dest_path")
        fi
        
        [[ -d "$dest_dir" ]]
        return $?
    fi
}

# Function to select transfer type
select_transfer_type() {
    local source_path="$1"
    local operation="$2"  # "upload" or "download"
    
    echo
    print_section_header "Transfer Type Selection"
    
    if [[ "$operation" == "upload" ]]; then
        print_color "WHITE" "Local source: $source_path"
    else
        print_color "WHITE" "Remote source: $source_path"
    fi
    
    # Check if source is a directory
    local is_directory=false
    if [[ "$operation" == "upload" ]]; then
        if [[ -d "$source_path" ]]; then
            is_directory=true
        fi
    else
        # For remote, we'll assume it could be a directory and let user choose
        is_directory=true
    fi
    
    echo
    print_color "YELLOW" "How do you want to transfer?"
    echo
    
    if [[ "$is_directory" == true ]]; then
        print_menu_option "1" "Single File" "Transfer a specific file"
        print_menu_option "2" "Whole Directory" "Transfer the entire directory (including the directory itself)"
        print_menu_option "3" "Directory Contents" "Transfer only the contents inside the directory"
        print_menu_option "4" "Multiple Files" "Select multiple specific files/directories"
        echo
        echo -n "❯ Select transfer type (1-4): "
    else
        print_menu_option "1" "Single File" "Transfer this file"
        print_menu_option "2" "Multiple Files" "Select multiple files from the same directory"
        echo
        echo -n "❯ Select transfer type (1-2): "
    fi
    
    local choice
    read choice
    
    case "$choice" in
        1)
            echo "single_file" > /tmp/.scp_transfer_type
            echo "$source_path" > /tmp/.scp_final_source
            ;;
        2)
            if [[ "$is_directory" == true ]]; then
                echo "whole_directory" > /tmp/.scp_transfer_type
                echo "$source_path" > /tmp/.scp_final_source
            else
                echo "multiple_files" > /tmp/.scp_transfer_type
                select_multiple_files "$source_path" "$operation"
            fi
            ;;
        3)
            if [[ "$is_directory" == true ]]; then
                echo "directory_contents" > /tmp/.scp_transfer_type
                echo "$source_path" > /tmp/.scp_final_source
                if [[ "$operation" == "download" ]]; then
                    echo
                    print_color "YELLOW" "📝 Note: For remote directory contents, the whole directory will be downloaded."
                    print_color "YELLOW" "   You can manually extract the contents after download."
                fi
            else
                print_status "ERROR" "Invalid choice"
                return 1
            fi
            ;;
        4)
            if [[ "$is_directory" == true ]]; then
                echo "multiple_files" > /tmp/.scp_transfer_type
                select_multiple_files "$source_path" "$operation"
            else
                print_status "ERROR" "Invalid choice"
                return 1
            fi
            ;;
        *)
            print_status "ERROR" "Invalid choice"
            return 1
            ;;
    esac
    
    return 0
}

# Function to select multiple files
select_multiple_files() {
    local base_path="$1"
    local operation="$2"
    
    echo
    print_section_header "Multiple Files Selection"
    print_color "YELLOW" "Enter file/directory paths separated by spaces:"
    print_color "YELLOW" "Example: file1.txt subdir/file2.txt another_dir/"
    echo
    
    if [[ "$operation" == "upload" ]]; then
        print_color "WHITE" "Base directory: $base_path"
        echo -n "❯ Enter relative paths: "
    else
        print_color "WHITE" "Remote base directory: $base_path"
        echo -n "❯ Enter relative paths: "
    fi
    
    local files_input
    read files_input
    
    if [[ -z "$files_input" ]]; then
        print_status "ERROR" "No files specified"
        return 1
    fi
    
    # Build the final source paths
    local final_sources=""
    for file in $files_input; do
        if [[ "$operation" == "upload" ]]; then
            local full_path="$base_path/$file"
            if [[ -e "$full_path" ]]; then
                if [[ -n "$final_sources" ]]; then
                    final_sources="$final_sources '$full_path'"
                else
                    final_sources="'$full_path'"
                fi
            else
                print_color "YELLOW" "Warning: $full_path does not exist"
            fi
        else
            if [[ -n "$final_sources" ]]; then
                final_sources="$final_sources '$base_path/$file'"
            else
                final_sources="'$base_path/$file'"
            fi
        fi
    done
    
    echo "$final_sources" > /tmp/.scp_final_source
    return 0
}

# Function to detect transfer type from saved transfers
detect_transfer_type_from_saved() {
    local source_path="$1"
    local dest_path="$2"
    local operation="$3"
    
    # Check if destination path has wildcard (indicates directory contents transfer)
    if [[ "$dest_path" == *"*" ]]; then
        echo "directory_contents" > /tmp/.scp_transfer_type
        # Remove the /* from destination for proper command building
        local clean_dest="${dest_path%/*}"
        echo "$clean_dest" > /tmp/.scp_clean_dest
        # For directory contents, use the source directory
        echo "$source_path" > /tmp/.scp_final_source
        return 0
    fi
    
    # Check if source path has wildcard
    if [[ "$source_path" == *"*" ]]; then
        echo "directory_contents" > /tmp/.scp_transfer_type
        # For source wildcard, extract the base directory
        local base_dir="${source_path%/*}"
        echo "$base_dir" > /tmp/.scp_final_source
        return 0
    fi
    
    # Check if source is a directory (for upload operations)
    if [[ "$operation" == "upload" ]] && [[ -d "$source_path" ]]; then
        echo "whole_directory" > /tmp/.scp_transfer_type
        echo "$source_path" > /tmp/.scp_final_source
        return 0
    fi
    
    # Default to single file
    echo "single_file" > /tmp/.scp_transfer_type
    echo "$source_path" > /tmp/.scp_final_source
    return 0
}

# Function to format enhanced command display for readability
# Function to analyze transfer results and provide detailed feedback
analyze_transfer_results() {
    local scp_output="$1"
    local exit_code="$2"
    
    # Debug: Save output to a log file for troubleshooting
    echo "$scp_output" > "/tmp/scp_debug_$(date +%s).log"
    
    # Count successful transfers more accurately
    # Look for files that completed successfully (100% or file completion indicators)
    local success_count=0
    
    # Method 1: Count 100% indicators
    local hundred_percent_count=$(echo "$scp_output" | grep -c "100%")
    
    # Method 2: Count files that show completion without errors
    # Look for lines with file names that don't have "scp:" error prefix
    local file_completion_count=0
    while IFS= read -r line; do
        # Skip empty lines
        [[ -z "$line" ]] && continue
        
        # If line contains a file transfer pattern and no error
        if [[ "$line" =~ [[:space:]]+[0-9]+%[[:space:]]+[0-9]+ ]] && [[ ! "$line" =~ ^scp: ]]; then
            ((file_completion_count++))
        fi
        
        # Also count files that show successful completion patterns
        if [[ "$line" =~ \.log[[:space:]]+100%.*[0-9]+\.[0-9]+[KMG]?B/s ]] || 
           [[ "$line" =~ \.sh[[:space:]]+100%.*[0-9]+\.[0-9]+[KMG]?B/s ]] ||
           [[ "$line" =~ [[:alnum:]_-]+[[:space:]]+100%.*[0-9]+\.[0-9]+[KMG]?B/s ]]; then
            ((success_count++))
        fi
    done <<< "$scp_output"
    
    # Use the higher count as our success indicator
    if [[ $hundred_percent_count -gt $success_count ]]; then
        success_count=$hundred_percent_count
    fi
    
    # Count different types of errors
    local permission_errors=$(echo "$scp_output" | grep -c "Permission denied")
    local no_such_file_errors=$(echo "$scp_output" | grep -c "No such file or directory")
    local connection_errors=$(echo "$scp_output" | grep -c "Connection refused\|Connection timed out\|Host key verification failed")
    local space_errors=$(echo "$scp_output" | grep -c "No space left on device")
    local other_errors=$(echo "$scp_output" | grep -E -c "scp:.*failed|scp:.*error" | grep -v -c "Permission denied\|No such file\|Connection\|No space")
    
    local total_errors=$((permission_errors + no_such_file_errors + connection_errors + space_errors + other_errors))
    
    # Add debug information
    echo "🐛 DEBUG: success_count=$success_count, hundred_percent=$hundred_percent_count, total_errors=$total_errors, exit_code=$exit_code" > "/tmp/scp_debug_analysis_$(date +%s).log"
    
    # Determine transfer status
    if [[ $exit_code -eq 0 ]]; then
        print_status "SUCCESS" "Transfer completed successfully"
        if [[ $success_count -gt 0 ]]; then
            print_color "GREEN" "✅ Successfully transferred: $success_count files"
        fi
    elif [[ $success_count -gt 0 ]]; then
        # Partial transfer - some files succeeded (YELLOW status)
        print_color "YELLOW" "⚠️  Partial transfer completed (Exit code: $exit_code)"
        echo
        print_color "GREEN" "✅ Successfully transferred: $success_count files"
        
        if [[ $total_errors -gt 0 ]]; then
            print_color "RED" "❌ Failed transfers: $total_errors files"
            echo
            print_color "YELLOW" "📋 Failure breakdown:"
            
            if [[ $permission_errors -gt 0 ]]; then
                print_color "YELLOW" "   • Permission denied: $permission_errors files"
                echo "$scp_output" | grep "Permission denied" | sed 's/^/     /' | head -3
                if [[ $permission_errors -gt 3 ]]; then
                    print_color "YELLOW" "     (... and $((permission_errors - 3)) more permission errors)"
                fi
            fi
            
            if [[ $no_such_file_errors -gt 0 ]]; then
                print_color "YELLOW" "   • File not found: $no_such_file_errors files"
                echo "$scp_output" | grep "No such file" | sed 's/^/     /' | head -2
            fi
            
            if [[ $connection_errors -gt 0 ]]; then
                print_color "YELLOW" "   • Connection issues: $connection_errors errors"
            fi
            
            if [[ $space_errors -gt 0 ]]; then
                print_color "YELLOW" "   • Disk space issues: $space_errors errors"
            fi
            
            if [[ $other_errors -gt 0 ]]; then
                print_color "YELLOW" "   • Other errors: $other_errors"
            fi
            
            echo
            print_color "YELLOW" "💡 Recommendations:"
            if [[ $permission_errors -gt 0 ]]; then
                print_color "YELLOW" "   • Check file/directory permissions on destination"
                print_color "YELLOW" "   • Ensure user has write access to destination directory"
            fi
            if [[ $no_such_file_errors -gt 0 ]]; then
                print_color "YELLOW" "   • Verify source files still exist"
            fi
            if [[ $connection_errors -gt 0 ]]; then
                print_color "YELLOW" "   • Check network connectivity and SSH configuration"
            fi
        fi
    else
        # Complete failure - no files transferred
        print_status "ERROR" "Transfer failed completely (Exit code: $exit_code)"
        echo
        if [[ $total_errors -gt 0 ]]; then
            print_color "RED" "❌ No files were transferred"
            print_color "YELLOW" "💡 Error details:"
            
            if [[ $permission_errors -gt 0 ]]; then
                print_color "YELLOW" "   • Permission denied errors detected"
            fi
            if [[ $connection_errors -gt 0 ]]; then
                print_color "YELLOW" "   • Connection/authentication issues detected"
            fi
            if [[ $no_such_file_errors -gt 0 ]]; then
                print_color "YELLOW" "   • Source files not found"
            fi
            
            # Show first few error lines for debugging
            echo
            print_color "YELLOW" "📋 Error output:"
            echo "$scp_output" | grep -E "Permission denied|No such file|Connection|failed|error" | head -3 | sed 's/^/     /'
        else
            print_color "YELLOW" "💡 Check the command and paths for any issues"
        fi
    fi
}

format_enhanced_command_display() {
    local command="$1"
    
    echo "  📋 Command Preview:"
    echo "  ─────────────────────────────────────────"
    
    # Parse the command more carefully
    # Extract SCP base command with all its options (everything before the first file path)
    local scp_base=""
    local remaining_command="$command"
    
    # Handle the case where command starts with "scp"
    if [[ "$command" =~ ^scp[[:space:]]+ ]]; then
        # Extract everything up to the first quoted file path
        scp_base=$(echo "$command" | sed -E "s/^(scp[^']*)'.*$/\1/")
        # Remove trailing space
        scp_base="${scp_base% }"
        
        echo "  💻 Command: $scp_base"
        echo
        
        # Extract all quoted paths
        local paths=()
        while IFS= read -r path; do
            if [[ -n "$path" ]]; then
                paths+=("$path")
            fi
        done < <(echo "$command" | grep -oE "'[^']+'" | sed "s/'//g")
        
        # Find the destination (last path that contains @: or analyze based on operation)
        local dest_index=-1
        local sources=()
        
        # Look for destination pattern (contains @:)
        for i in "${!paths[@]}"; do
            if [[ "${paths[i]}" == *"@:"* ]]; then
                dest_index=$i
                break
            fi
        done
        
        # If no @: pattern found, assume last path is destination
        if [[ $dest_index -eq -1 ]] && [[ ${#paths[@]} -gt 1 ]]; then
            dest_index=$((${#paths[@]} - 1))
        fi
        
        # Separate sources and destination
        if [[ $dest_index -ne -1 ]]; then
            for i in "${!paths[@]}"; do
                if [[ $i -eq $dest_index ]]; then
                    destination="${paths[i]}"
                else
                    sources+=("${paths[i]}")
                fi
            done
        else
            # If we can't determine destination, treat all as sources
            sources=("${paths[@]}")
        fi
        
        # Display sources
        if [[ ${#sources[@]} -gt 0 ]]; then
            echo "  📁 Sources:"
            for source in "${sources[@]}"; do
                local filename=$(basename "$source")
                local dirname=$(dirname "$source")
                if [[ ${#sources[@]} -eq 1 ]]; then
                    echo "    • $source"
                else
                    echo "    • $filename"
                fi
            done
            
            if [[ ${#sources[@]} -gt 1 ]]; then
                echo "    📊 Total files: ${#sources[@]}"
            fi
            echo
        fi
        
        # Display destination
        if [[ -n "$destination" ]]; then
            echo "  🎯 Destination: $destination"
        fi
    else
        # Fallback: display the raw command if parsing fails
        echo "  $command"
    fi
}

build_enhanced_scp_command() {
    local operation="$1"
    local source_path="$2"
    local dest_path="$3"
    local host="$4"
    local user="$5"
    local auth_method="$6"
    local ssh_key="$7"
    local is_saved_transfer="$8"  # Optional flag for saved transfers
    
    # For saved transfers, detect transfer type from paths
    if [[ "$is_saved_transfer" == "true" ]]; then
        detect_transfer_type_from_saved "$source_path" "$dest_path" "$operation"
        # Use clean destination if available (without wildcards)
        local clean_dest=$(cat /tmp/.scp_clean_dest 2>/dev/null)
        if [[ -n "$clean_dest" ]]; then
            dest_path="$clean_dest"
        fi
    fi
    
    # Get transfer type and final source from selection or detection
    local transfer_type=$(cat /tmp/.scp_transfer_type 2>/dev/null || echo "single_file")
    local final_source=$(cat /tmp/.scp_final_source 2>/dev/null || echo "$source_path")
    
    # Build base SCP command
    local scp_cmd="scp"
    
    # Add SSH key if specified
    if [[ "$auth_method" == "ssh_key" ]] && [[ -n "$ssh_key" ]]; then
        scp_cmd="$scp_cmd -i '$ssh_key'"
    fi
    
    # Add flags based on transfer type
    case "$transfer_type" in
        "whole_directory")
            scp_cmd="$scp_cmd -r"
            ;;
        "directory_contents")
            # For directory contents, we use bash to expand the wildcard
            if [[ "$operation" == "upload" ]]; then
                # Get all files/directories in the source directory
                local expanded_sources=""
                for item in "$source_path"/*; do
                    if [[ -e "$item" ]]; then
                        if [[ -n "$expanded_sources" ]]; then
                            expanded_sources="$expanded_sources '$item'"
                        else
                            expanded_sources="'$item'"
                        fi
                    fi
                done
                final_source="$expanded_sources"
                scp_cmd="$scp_cmd -r"  # Need recursive for potential subdirectories
            else
                # For remote directory contents, we'll use a different approach
                # We'll transfer the whole directory and handle contents extraction differently
                scp_cmd="$scp_cmd -r"
                final_source="$source_path"
            fi
            ;;
        "multiple_files")
            # Multiple files might include directories, so add -r for safety
            scp_cmd="$scp_cmd -r"
            ;;
        *)
            # Single file - check if it's actually a directory
            if [[ "$operation" == "upload" ]] && [[ -d "$source_path" ]]; then
                scp_cmd="$scp_cmd -r"
            fi
            ;;
    esac
    
    # Build the full command based on operation
    if [[ "$operation" == "upload" ]]; then
        if [[ "$transfer_type" == "directory_contents" ]]; then
            # For directory contents, final_source is already expanded and quoted
            scp_cmd="$scp_cmd $final_source '$user@$host:$dest_path'"
        elif [[ "$transfer_type" == "multiple_files" ]]; then
            # Multiple files - don't quote the final_source as it's already quoted
            scp_cmd="$scp_cmd $final_source '$user@$host:$dest_path'"
        else
            scp_cmd="$scp_cmd '$final_source' '$user@$host:$dest_path'"
        fi
    else
        if [[ "$transfer_type" == "directory_contents" ]]; then
            # For remote directory contents, we'll download the whole directory
            # and provide instructions to the user
            scp_cmd="$scp_cmd '$user@$host:$final_source' '$dest_path'"
            echo "# NOTE: Downloading whole directory. You can extract contents manually after download."
        elif [[ "$transfer_type" == "multiple_files" ]]; then
            scp_cmd="$scp_cmd $final_source '$dest_path'"
        else
            scp_cmd="$scp_cmd '$user@$host:$final_source' '$dest_path'"
        fi
    fi
    
    echo "$scp_cmd"
}

delete_transfer() {
    print_header
    print_section_header "Delete Transfer Configuration"
    
    initialize_transfers_dir
    local transfers_file="$HOME/.scp_manager/scp_saved_transfers.json"
    
    if [[ ! -f "$transfers_file" ]] || [[ ! -s "$transfers_file" ]]; then
        print_status "INFO" "No transfer configurations found"
        return 0
    fi
    
    # List transfers for selection
    list_transfers
    
    echo
    local transfers_count=$(jq 'length' "$transfers_file" 2>/dev/null)
    
    if [[ "$transfers_count" -eq 0 ]]; then
        return 0
    fi
    
    echo -n "❯ Select transfer to delete (1-$transfers_count) or 'c' to cancel: "
    read transfer_choice
    
    if [[ "$transfer_choice" == "c" ]] || [[ "$transfer_choice" == "C" ]]; then
        return 0
    fi
    
    if [[ ! "$transfer_choice" =~ ^[0-9]+$ ]] || [[ "$transfer_choice" -lt 1 ]] || [[ "$transfer_choice" -gt "$transfers_count" ]]; then
        print_status "ERROR" "Invalid selection"
        return 1
    fi
    
    # Get the selected transfer name for confirmation
    local transfer_index=$((transfer_choice - 1))
    local transfer_name=$(jq -r ".[$transfer_index].name" "$transfers_file" 2>/dev/null)
    
    echo
    print_color "YELLOW" "⚠️  WARNING: You are about to delete transfer: $transfer_name"
    echo -n "❯ Are you sure? (y/N): "
    read confirm_choice
    
    if [[ "$confirm_choice" =~ ^[Yy] ]]; then
        # Remove the transfer from the array
        local updated_transfers=$(jq "del(.[$transfer_index])" "$transfers_file")
        echo "$updated_transfers" > "$transfers_file"
        
        print_status "SUCCESS" "Transfer '$transfer_name' deleted"
        
        # Show updated list
        echo
        list_transfers
    else
        print_status "INFO" "Deletion cancelled"
    fi
}

delete_all_transfers() {
    print_header
    print_section_header "Delete ALL Transfer Configurations"
    
    initialize_transfers_dir
    local transfers_file="$HOME/.scp_manager/scp_saved_transfers.json"
    
    if [[ ! -f "$transfers_file" ]] || [[ ! -s "$transfers_file" ]]; then
        print_status "INFO" "No transfer configurations found"
        return 0
    fi
    
    local transfers_count=$(jq 'length' "$transfers_file" 2>/dev/null)
    
    if [[ "$transfers_count" -eq 0 ]]; then
        print_status "INFO" "No transfer configurations found"
        return 0
    fi
    
    echo
    print_color "RED" "⚠️  WARNING: You are about to delete ALL $transfers_count transfer configurations!"
    print_color "RED" "This action cannot be undone."
    
    echo
    echo -n "❯ Type 'DELETE ALL' to confirm: "
    read confirm_input
    
    if [[ "$confirm_input" == "DELETE ALL" ]]; then
        # Clear the transfers file
        echo "[]" > "$transfers_file"
        
        print_status "SUCCESS" "All transfer configurations deleted"
        
        # Validate deletion by showing empty list
        echo
        print_section_header "Verification - Transfer List After Deletion"
        list_transfers
    else
        print_status "INFO" "Deletion cancelled - no transfers were deleted"
    fi
}

# Folder Navigator Functions
folder_navigator_menu() {
    local current_dir="$PWD"
    
    while true; do
        print_header
        print_section_header "Folder Navigator"
        
        echo "Current Directory: $current_dir"
        echo
        
        # List current directory contents
        list_local_directory "$current_dir" "detailed"
        
        echo
        print_section_header "Navigation Options"
        print_menu_option "1" "Navigate Down" "Enter a subdirectory"
        print_menu_option "2" "Navigate Up" "Go to parent directory"
        print_menu_option "3" "Change View" "Switch between detailed, copy, and simple views"
        print_menu_option "4" "Go to Path" "Navigate to a specific path"
        print_menu_option "5" "Back to Main Menu" "Return to main menu"
        
        echo
        local choice
        
        while true; do
            echo -n "❯ Select option (1-5): "
            read choice
            if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le 5 ]]; then
                break
            else
                echo "❌ Invalid choice. Please enter a number between 1 and 5"
            fi
        done
        
        case "$choice" in
            1)
                navigate_down_interactive "$current_dir"
                new_dir=$(cat /tmp/.scp_nav_result 2>/dev/null || echo "$current_dir")
                current_dir="$new_dir"
                ;;
            2)
                navigate_up_interactive "$current_dir"
                new_dir=$(cat /tmp/.scp_nav_result 2>/dev/null || echo "$current_dir")
                current_dir="$new_dir"
                ;;
            3)
                change_view_mode "$current_dir"
                ;;
            4)
                goto_path_interactive "$current_dir"
                new_dir=$(cat /tmp/.scp_nav_result 2>/dev/null || echo "$current_dir")
                current_dir="$new_dir"
                ;;
            5)
                return
                ;;
        esac
    done
}

list_local_directory() {
    local path="$1"
    local view_mode="${2:-detailed}"
    
    if [[ ! -d "$path" ]]; then
        print_status "ERROR" "Directory does not exist: $path"
        return 1
    fi
    
    case "$view_mode" in
        "detailed")
            display_local_detailed_view "$path"
            ;;
        "copy")
            display_local_copy_view "$path"
            ;;
        "simple")
            display_local_simple_view "$path"
            ;;
        *)
            display_local_detailed_view "$path"
            ;;
    esac
}

display_local_detailed_view() {
    local path="$1"
    
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo "📁 Local Directory: $path"
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo
    
    # Use ls with color support if available
    if ls --color=auto "$path" >/dev/null 2>&1; then
        ls -la --color=auto "$path" 2>/dev/null | while IFS= read -r line; do
            if [[ -n "$line" ]] && [[ ! "$line" =~ ^total ]]; then
                local permissions=$(echo "$line" | awk '{print $1}')
                local icon="📄"
                
                if [[ "$permissions" =~ ^d ]]; then
                    icon="📁"
                elif [[ "$permissions" =~ ^l ]]; then
                    icon="🔗"
                elif [[ "$permissions" =~ x ]]; then
                    icon="⚙️"
                fi
                
                echo "$icon $line"
            fi
        done
    else
        ls -la "$path" 2>/dev/null | while IFS= read -r line; do
            if [[ -n "$line" ]] && [[ ! "$line" =~ ^total ]]; then
                local permissions=$(echo "$line" | awk '{print $1}')
                local icon="📄"
                
                if [[ "$permissions" =~ ^d ]]; then
                    icon="📁"
                elif [[ "$permissions" =~ ^l ]]; then
                    icon="🔗"
                elif [[ "$permissions" =~ x ]]; then
                    icon="⚙️"
                fi
                
                echo "$icon $line"
            fi
        done
    fi
}

display_local_copy_view() {
    local path="$1"
    
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo "📁 Local Directory: $path"
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo
    
    # Show detailed listing first
    display_local_detailed_view "$path"
    
    echo
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo "📋 Copying view format:"
    echo "════════════════════════════════════════════════════════════════════════════════"
    
    # Show full paths for easy copying
    find "$path" -maxdepth 1 -type f -o -type d | grep -v "^$path$" | sort | while read -r item; do
        if [[ "$(basename "$item")" != "." && "$(basename "$item")" != ".." ]]; then
            echo "$item"
        fi
    done
}

display_local_simple_view() {
    local path="$1"
    
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo "📁 Local Directory: $path"
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo
    
    # Show only filenames
    ls -1 "$path" 2>/dev/null | while read -r item; do
        if [[ -n "$item" ]]; then
            if [[ -d "$path/$item" ]]; then
                echo "$item/"
            else
                echo "$item"
            fi
        fi
    done
}

# Interactive navigation functions that use temp files instead of command substitution
navigate_down_interactive() {
    local current_path="$1"
    
    echo
    print_section_header "Navigate Down - Select Folder"
    
    # Get list of directories only
    local dirs=()
    while IFS= read -r item; do
        if [[ -n "$item" && "$item" != "." && "$item" != ".." ]]; then
            dirs+=("$item")
        fi
    done < <(find "$current_path" -maxdepth 1 -type d 2>/dev/null | grep -v "^$current_path$" | xargs -I {} basename {} 2>/dev/null)
    
    if [[ ${#dirs[@]} -eq 0 ]]; then
        print_status "INFO" "No subdirectories found"
        echo
        press_enter_to_continue
        echo "$current_path" > /tmp/.scp_nav_result
        return
    fi
    
    echo "Available folders:"
    local counter=1
    for dir in "${dirs[@]}"; do
        local dir_info=$(ls -ld "$current_path/$dir" 2>/dev/null | awk '{print $1, $3, $4, $5, $6, $7, $8}')
        print_menu_option "$counter" "$dir" "$dir_info"
        ((counter++))
    done
    
    echo
    echo "[c] Cancel - stay in current directory"
    
    echo
    while true; do
        echo -n "❯ Select folder (1-${#dirs[@]}) or 'c' to cancel: "
        read folder_choice
        
        if [[ "$folder_choice" == "c" ]] || [[ "$folder_choice" == "C" ]]; then
            echo "$current_path" > /tmp/.scp_nav_result
            return
        elif [[ "$folder_choice" =~ ^[0-9]+$ ]] && [[ "$folder_choice" -ge 1 ]] && [[ "$folder_choice" -le "${#dirs[@]}" ]]; then
            local selected_dir="${dirs[$((folder_choice-1))]}"
            local new_path="$current_path/$selected_dir"
            
            if [[ -d "$new_path" ]]; then
                print_status "SUCCESS" "Navigated to: $new_path"
                echo
                press_enter_to_continue
                echo "$new_path" > /tmp/.scp_nav_result
                return
            else
                print_status "ERROR" "Directory does not exist: $new_path"
                echo
                press_enter_to_continue
                echo "$current_path" > /tmp/.scp_nav_result
                return
            fi
        else
            echo "❌ Invalid choice. Please enter a number between 1 and ${#dirs[@]}, or 'c' to cancel"
        fi
    done
}

navigate_up_interactive() {
    local current_path="$1"
    
    # Check if we're already at root
    if [[ "$current_path" == "/" ]]; then
        print_status "INFO" "Already at root directory"
        echo
        press_enter_to_continue
        echo "$current_path" > /tmp/.scp_nav_result
        return
    fi
    
    local parent_path=$(dirname "$current_path")
    
    echo
    print_section_header "Navigate Up"
    print_status "INFO" "Moving from: $current_path"
    print_status "INFO" "Moving to: $parent_path"
    
    if [[ -d "$parent_path" ]]; then
        print_status "SUCCESS" "Successfully navigated up to: $parent_path"
        echo
        press_enter_to_continue
        echo "$parent_path" > /tmp/.scp_nav_result
    else
        print_status "ERROR" "Cannot access parent directory: $parent_path"
        echo
        press_enter_to_continue
        echo "$current_path" > /tmp/.scp_nav_result
    fi
}

goto_path_interactive() {
    local current_path="$1"
    
    echo
    print_section_header "Go to Specific Path"
    echo "Current directory: $current_path"
    echo
    echo -n "❯ Enter path to navigate to: "
    read target_path
    
    if [[ -z "$target_path" ]]; then
        print_status "INFO" "No path entered, staying in current directory"
        echo
        press_enter_to_continue
        echo "$current_path" > /tmp/.scp_nav_result
        return
    fi
    
    # Expand tilde and resolve path
    target_path="${target_path/#\~/$HOME}"
    target_path=$(readlink -f "$target_path" 2>/dev/null)
    
    if [[ -d "$target_path" ]]; then
        print_status "SUCCESS" "Navigated to: $target_path"
        echo
        press_enter_to_continue
        echo "$target_path" > /tmp/.scp_nav_result
    else
        print_status "ERROR" "Directory does not exist: $target_path"
        echo
        echo -n "❯ Would you like to browse the parent directory? (y/N): "
        read browse_parent
        if [[ "$browse_parent" =~ ^[Yy] ]]; then
            local parent_dir=$(dirname "$target_path")
            if [[ -d "$parent_dir" ]]; then
                print_status "INFO" "Showing parent directory: $parent_dir"
                echo
                list_local_directory "$parent_dir" "simple"
                echo
                press_enter_to_continue
                echo "$current_path" > /tmp/.scp_nav_result
                return
            fi
        fi
        echo
        press_enter_to_continue
        echo "$current_path" > /tmp/.scp_nav_result
    fi
}

navigate_down() {
    local current_path="$1"
    
    echo
    print_section_header "Navigate Down - Select Folder"
    
    # Get list of directories only
    local dirs=()
    while IFS= read -r item; do
        if [[ -n "$item" && "$item" != "." && "$item" != ".." ]]; then
            dirs+=("$item")
        fi
    done < <(find "$current_path" -maxdepth 1 -type d | grep -v "^$current_path$" | xargs -I {} basename {})
    
    if [[ ${#dirs[@]} -eq 0 ]]; then
        print_status "INFO" "No subdirectories found"
        echo
        press_enter_to_continue
        echo "$current_path"
        return
    fi
    
    echo "Available folders:"
    local counter=1
    for dir in "${dirs[@]}"; do
        print_menu_option "$counter" "$dir" "$(ls -ld "$current_path/$dir" 2>/dev/null | awk '{print $1, $3, $4, $5, $6, $7, $8}')"
        ((counter++))
    done
    
    echo
    echo "[c] Cancel - stay in current directory"
    
    echo
    while true; do
        echo -n "❯ Select folder (1-${#dirs[@]}) or 'c' to cancel: "
        read folder_choice
        
        if [[ "$folder_choice" == "c" ]] || [[ "$folder_choice" == "C" ]]; then
            echo "$current_path"
            return
        elif [[ "$folder_choice" =~ ^[0-9]+$ ]] && [[ "$folder_choice" -ge 1 ]] && [[ "$folder_choice" -le "${#dirs[@]}" ]]; then
            local selected_dir="${dirs[$((folder_choice-1))]}"
            local new_path="$current_path/$selected_dir"
            
            if [[ -d "$new_path" ]]; then
                print_status "SUCCESS" "Navigated to: $new_path"
                echo
                press_enter_to_continue
                echo "$new_path"
                return
            else
                print_status "ERROR" "Directory does not exist: $new_path"
                echo
                press_enter_to_continue
                echo "$current_path"
                return
            fi
        else
            echo "❌ Invalid choice. Please enter a number between 1 and ${#dirs[@]}, or 'c' to cancel"
        fi
    done
}

navigate_up() {
    local current_path="$1"
    
    # Check if we're already at root
    if [[ "$current_path" == "/" ]]; then
        print_status "INFO" "Already at root directory"
        echo
        press_enter_to_continue
        echo "$current_path"
        return
    fi
    
    local parent_path=$(dirname "$current_path")
    
    echo
    print_section_header "Navigate Up"
    print_status "INFO" "Moving from: $current_path"
    print_status "INFO" "Moving to: $parent_path"
    
    if [[ -d "$parent_path" ]]; then
        print_status "SUCCESS" "Successfully navigated up to: $parent_path"
        echo
        press_enter_to_continue
        echo "$parent_path"
    else
        print_status "ERROR" "Cannot access parent directory: $parent_path"
        echo
        press_enter_to_continue
        echo "$current_path"
    fi
}

change_view_mode() {
    local current_path="$1"
    
    echo
    print_section_header "Change View Mode"
    print_menu_option "1" "Detailed View" "Show full file details with icons and colors"
    print_menu_option "2" "Copy View" "Show details + full paths for easy copying"
    print_menu_option "3" "Simple View" "Show filenames only"
    
    echo
    while true; do
        echo -n "❯ Select view mode (1-3): "
        read view_choice
        
        case "$view_choice" in
            1)
                echo
                list_local_directory "$current_path" "detailed"
                break
                ;;
            2)
                echo
                list_local_directory "$current_path" "copy"
                break
                ;;
            3)
                echo
                list_local_directory "$current_path" "simple"
                break
                ;;
            *)
                echo "❌ Invalid choice. Please enter a number between 1 and 3"
                ;;
        esac
    done
    
    echo
    press_enter_to_continue
}

goto_path() {
    local current_path="$1"
    
    echo
    print_section_header "Go to Specific Path"
    echo "Current directory: $current_path"
    echo
    echo -n "❯ Enter path to navigate to: "
    read target_path
    
    if [[ -z "$target_path" ]]; then
        print_status "INFO" "No path entered, staying in current directory"
        echo
        press_enter_to_continue
        echo "$current_path"
        return
    fi
    
    # Expand tilde and resolve path
    target_path="${target_path/#\~/$HOME}"
    target_path=$(readlink -f "$target_path" 2>/dev/null)
    
    if [[ -d "$target_path" ]]; then
        print_status "SUCCESS" "Navigated to: $target_path"
        echo
        press_enter_to_continue
        echo "$target_path"
    else
        print_status "ERROR" "Directory does not exist: $target_path"
        echo
        echo -n "❯ Would you like to browse the parent directory? (y/N): "
        read browse_parent
        if [[ "$browse_parent" =~ ^[Yy] ]]; then
            local parent_dir=$(dirname "$target_path")
            if [[ -d "$parent_dir" ]]; then
                print_status "INFO" "Showing parent directory: $parent_dir"
                echo
                list_local_directory "$parent_dir" "simple"
                echo
                press_enter_to_continue
                echo "$current_path"
                return
            fi
        fi
        echo
        press_enter_to_continue
        echo "$current_path"
    fi
}

# Remote Folder Navigator Functions
remote_folder_navigator_menu() {
    print_header
    print_section_header "Remote Folder Navigator"
    
    # Offer connection options
    print_menu_option "1" "Use New Connection" "Setup a new SSH connection for navigation"
    print_menu_option "2" "Use Saved Connection" "Select from existing saved connections"
    print_menu_option "3" "Back to Main Menu" "Return to main menu"
    
    echo
    local connection_choice
    
    while true; do
        echo -n "❯ Select connection option (1-3): "
        read connection_choice
        if [[ "$connection_choice" =~ ^[0-9]+$ ]] && [[ "$connection_choice" -ge 1 ]] && [[ "$connection_choice" -le 3 ]]; then
            break
        else
            echo "❌ Invalid choice. Please enter a number between 1 and 3"
        fi
    done
    
    case "$connection_choice" in
        1)
            # Setup new connection for navigation
            print_header
            print_section_header "Setup New Connection for Navigation"
            
            # Temporarily store current connection
            local temp_host="$REMOTE_HOST"
            local temp_user="$REMOTE_USER"
            local temp_key="$SSH_KEY"
            local temp_port="$REMOTE_PORT"
            
            # Setup new connection
            setup_ssh_connection
            
            # Check if connection was setup successfully
            if [[ -z "$REMOTE_HOST" ]] || [[ -z "$REMOTE_USER" ]]; then
                print_status "ERROR" "Failed to setup connection"
                # Restore previous connection
                REMOTE_HOST="$temp_host"
                REMOTE_USER="$temp_user"
                SSH_KEY="$temp_key"
                REMOTE_PORT="$temp_port"
                press_enter_to_continue
                return
            fi
            
            start_remote_navigation
            
            # Restore previous connection
            REMOTE_HOST="$temp_host"
            REMOTE_USER="$temp_user"
            SSH_KEY="$temp_key"
            REMOTE_PORT="$temp_port"
            ;;
        2)
            # Use saved connection
            if select_saved_connection "navigate"; then
                start_remote_navigation
            else
                print_status "INFO" "No connection selected"
                press_enter_to_continue
            fi
            ;;
        3)
            return
            ;;
    esac
}

start_remote_navigation() {
    # Test connection before starting navigation
    print_header
    print_section_header "Remote Folder Navigator"
    
    
    print_progress "Testing remote connection to $REMOTE_USER@$REMOTE_HOST..."
    
    if ! test_ssh_connection "$REMOTE_HOST" "$REMOTE_USER" "$REMOTE_PORT" "$SSH_KEY"; then
        print_status "ERROR" "Cannot connect to remote host"
        echo
        print_color "YELLOW" "💡 Debug info:"
        print_color "YELLOW" "   • Check if SSH key path is correct: $SSH_KEY"
        print_color "YELLOW" "   • Verify host is reachable: $REMOTE_HOST"
        print_color "YELLOW" "   • Confirm username is correct: $REMOTE_USER"
        print_color "YELLOW" "   • Check port accessibility: $REMOTE_PORT"
        echo
        echo -n "❯ Try manual SSH test? (y/N): "
        read test_choice
        if [[ "$test_choice" =~ ^[Yy] ]]; then
            echo "Manual test command:"
            local manual_cmd="ssh"
            if [[ -n "$SSH_KEY" ]]; then
                manual_cmd="$manual_cmd -i $SSH_KEY"
            fi
            manual_cmd="$manual_cmd -p $REMOTE_PORT $REMOTE_USER@$REMOTE_HOST"
            echo "$manual_cmd"
        fi
        echo
        press_enter_to_continue
        return
    fi
    
    print_status "SUCCESS" "Connected to $REMOTE_USER@$REMOTE_HOST"
    
    # Start with remote home directory
    local current_dir="/home/$REMOTE_USER"
    
    # Try to get actual remote home directory
    local actual_home=$(execute_remote_command "echo \$HOME" 2>/dev/null)
    if [[ -n "$actual_home" ]] && [[ "$actual_home" != "null" ]]; then
        current_dir="$actual_home"
    fi
    
    while true; do
        print_header
        print_section_header "Remote Folder Navigator"
        
        echo "Remote Host: $REMOTE_USER@$REMOTE_HOST"
        echo "Current Directory: $current_dir"
        echo
        
        # List current directory contents
        list_remote_directory "$current_dir" "detailed"
        
        echo
        print_section_header "Navigation Options"
        print_menu_option "1" "Navigate Down" "Enter a subdirectory"
        print_menu_option "2" "Navigate Up" "Go to parent directory"
        print_menu_option "3" "Change View" "Switch between detailed, copy, and simple views"
        print_menu_option "4" "Go to Path" "Navigate to a specific path"
        print_menu_option "5" "Back to Main Menu" "Return to main menu"
        
        echo
        local choice
        
        while true; do
            echo -n "❯ Select option (1-5): "
            read choice
            if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le 5 ]]; then
                break
            else
                echo "❌ Invalid choice. Please enter a number between 1 and 5"
            fi
        done
        
        case "$choice" in
            1)
                remote_navigate_down_interactive "$current_dir"
                new_dir=$(cat /tmp/.scp_remote_nav_result 2>/dev/null || echo "$current_dir")
                current_dir="$new_dir"
                ;;
            2)
                remote_navigate_up_interactive "$current_dir"
                new_dir=$(cat /tmp/.scp_remote_nav_result 2>/dev/null || echo "$current_dir")
                current_dir="$new_dir"
                ;;
            3)
                remote_change_view_mode "$current_dir"
                ;;
            4)
                remote_goto_path_interactive "$current_dir"
                new_dir=$(cat /tmp/.scp_remote_nav_result 2>/dev/null || echo "$current_dir")
                current_dir="$new_dir"
                ;;
            5)
                return
                ;;
        esac
    done
}

list_remote_directory() {
    local path="$1"
    local view_mode="${2:-detailed}"
    
    # Test if remote directory exists
    if ! execute_remote_command "test -d '$path'"; then
        print_status "ERROR" "Remote directory does not exist: $path"
        return 1
    fi
    
    case "$view_mode" in
        "detailed")
            display_remote_detailed_view "$path"
            ;;
        "copy")
            display_remote_copy_view "$path"
            ;;
        "simple")
            display_remote_simple_view "$path"
            ;;
        *)
            display_remote_detailed_view "$path"
            ;;
    esac
}

display_remote_detailed_view() {
    local path="$1"
    
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo "🌐 Remote Directory: $path"
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo
    
    local ls_output=$(execute_remote_command "ls -la '$path' 2>/dev/null" | grep -v "^total")
    
    if [[ -z "$ls_output" ]]; then
        print_status "INFO" "Directory is empty or cannot be read"
        return
    fi
    
    echo "$ls_output" | while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            local permissions=$(echo "$line" | awk '{print $1}')
            local icon="📄"
            
            if [[ "$permissions" =~ ^d ]]; then
                icon="📁"
            elif [[ "$permissions" =~ ^l ]]; then
                icon="🔗"
            elif [[ "$permissions" =~ x ]]; then
                icon="⚙️"
            fi
            
            echo -e "$icon $line"
        fi
    done
}

display_remote_copy_view() {
    local path="$1"
    
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo "🌐 Remote Directory (Copy-Friendly): $path"
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo
    
    execute_remote_command "find '$path' -maxdepth 1 -type f -exec echo '📄 {}' \;"
    execute_remote_command "find '$path' -maxdepth 1 -type d -exec echo '📁 {}' \;" | grep -v "📁 $path$"
}

display_remote_simple_view() {
    local path="$1"
    
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo "🌐 Remote Directory (Simple): $path"
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo
    
    local items=$(execute_remote_command "ls -1 '$path' 2>/dev/null")
    
    if [[ -z "$items" ]]; then
        print_status "INFO" "Directory is empty or cannot be read"
        return
    fi
    
    echo "$items" | while IFS= read -r item; do
        if [[ -n "$item" ]]; then
            echo "  $item"
        fi
    done
}

# Interactive remote navigation functions that use temp files instead of command substitution
remote_navigate_down_interactive() {
    local current_path="$1"
    
    echo
    print_section_header "Navigate Down - Select Remote Folder"
    
    # Get list of directories only
    local dirs_output=$(execute_remote_command "find '$current_path' -maxdepth 1 -type d 2>/dev/null | grep -v '^$current_path$' | sed 's|.*/||' | sort")
    
    if [[ -z "$dirs_output" ]]; then
        print_status "INFO" "No subdirectories found"
        echo
        press_enter_to_continue
        echo "$current_path" > /tmp/.scp_remote_nav_result
        return
    fi
    
    local dirs=()
    while IFS= read -r item; do
        if [[ -n "$item" && "$item" != "." && "$item" != ".." ]]; then
            dirs+=("$item")
        fi
    done <<< "$dirs_output"
    
    if [[ ${#dirs[@]} -eq 0 ]]; then
        print_status "INFO" "No subdirectories found"
        echo
        press_enter_to_continue
        echo "$current_path" > /tmp/.scp_remote_nav_result
        return
    fi
    
    echo "Available remote folders:"
    local counter=1
    for dir in "${dirs[@]}"; do
        local dir_info=$(execute_remote_command "ls -ld '$current_path/$dir' 2>/dev/null | awk '{print \$1, \$3, \$4, \$5, \$6, \$7, \$8}'")
        print_menu_option "$counter" "$dir" "$dir_info"
        ((counter++))
    done
    
    echo
    echo "[c] Cancel - stay in current directory"
    
    echo
    while true; do
        echo -n "❯ Select folder (1-${#dirs[@]}) or 'c' to cancel: "
        read folder_choice
        
        if [[ "$folder_choice" == "c" ]] || [[ "$folder_choice" == "C" ]]; then
            echo "$current_path" > /tmp/.scp_remote_nav_result
            return
        elif [[ "$folder_choice" =~ ^[0-9]+$ ]] && [[ "$folder_choice" -ge 1 ]] && [[ "$folder_choice" -le "${#dirs[@]}" ]]; then
            local selected_dir="${dirs[$((folder_choice-1))]}"
            local new_path="$current_path/$selected_dir"
            
            if execute_remote_command "test -d '$new_path'"; then
                print_status "SUCCESS" "Navigated to: $new_path"
                echo
                press_enter_to_continue
                echo "$new_path" > /tmp/.scp_remote_nav_result
                return
            else
                print_status "ERROR" "Remote directory does not exist: $new_path"
                echo
                press_enter_to_continue
                echo "$current_path" > /tmp/.scp_remote_nav_result
                return
            fi
        else
            echo "❌ Invalid choice. Please enter a number between 1 and ${#dirs[@]}, or 'c' to cancel"
        fi
    done
}

remote_navigate_up_interactive() {
    local current_path="$1"
    
    # Check if we're already at root
    if [[ "$current_path" == "/" ]]; then
        print_status "INFO" "Already at root directory"
        echo
        press_enter_to_continue
        echo "$current_path" > /tmp/.scp_remote_nav_result
        return
    fi
    
    local parent_path=$(dirname "$current_path")
    
    echo
    print_section_header "Navigate Up (Remote)"
    print_status "INFO" "Moving from: $current_path"
    print_status "INFO" "Moving to: $parent_path"
    
    if execute_remote_command "test -d '$parent_path'"; then
        print_status "SUCCESS" "Successfully navigated up to: $parent_path"
        echo
        press_enter_to_continue
        echo "$parent_path" > /tmp/.scp_remote_nav_result
    else
        print_status "ERROR" "Cannot access remote parent directory: $parent_path"
        echo
        press_enter_to_continue
        echo "$current_path" > /tmp/.scp_remote_nav_result
    fi
}

remote_goto_path_interactive() {
    local current_path="$1"
    
    echo
    print_section_header "Go to Specific Remote Path"
    echo "Current remote directory: $current_path"
    echo
    echo -n "❯ Enter remote path to navigate to: "
    read target_path
    
    if [[ -z "$target_path" ]]; then
        print_status "INFO" "No path entered, staying in current directory"
        echo
        press_enter_to_continue
        echo "$current_path" > /tmp/.scp_remote_nav_result
        return
    fi
    
    # Expand tilde for remote home directory
    if [[ "$target_path" =~ ^\~ ]]; then
        local remote_home=$(execute_remote_command "echo \$HOME" 2>/dev/null)
        if [[ -n "$remote_home" ]]; then
            target_path="${target_path/#\~/$remote_home}"
        fi
    fi
    
    if execute_remote_command "test -d '$target_path'"; then
        print_status "SUCCESS" "Navigated to: $target_path"
        echo
        press_enter_to_continue
        echo "$target_path" > /tmp/.scp_remote_nav_result
    else
        print_status "ERROR" "Remote directory does not exist: $target_path"
        echo
        echo -n "❯ Would you like to browse the parent directory? (y/N): "
        read browse_parent
        if [[ "$browse_parent" =~ ^[Yy] ]]; then
            local parent_dir=$(dirname "$target_path")
            if execute_remote_command "test -d '$parent_dir'"; then
                print_status "INFO" "Showing parent directory: $parent_dir"
                echo
                list_remote_directory "$parent_dir" "simple"
                echo
                press_enter_to_continue
                echo "$current_path" > /tmp/.scp_remote_nav_result
                return
            fi
        fi
        echo
        press_enter_to_continue
        echo "$current_path" > /tmp/.scp_remote_nav_result
    fi
}

remote_navigate_down() {
    local current_path="$1"
    
    echo
    print_section_header "Navigate Down - Select Remote Folder"
    
    # Get list of directories only
    local dirs_output=$(execute_remote_command "find '$current_path' -maxdepth 1 -type d 2>/dev/null | grep -v '^$current_path$' | sed 's|.*/||' | sort")
    
    if [[ -z "$dirs_output" ]]; then
        print_status "INFO" "No subdirectories found"
        echo
        press_enter_to_continue
        echo "$current_path"
        return
    fi
    
    local dirs=()
    while IFS= read -r item; do
        if [[ -n "$item" && "$item" != "." && "$item" != ".." ]]; then
            dirs+=("$item")
        fi
    done <<< "$dirs_output"
    
    if [[ ${#dirs[@]} -eq 0 ]]; then
        print_status "INFO" "No subdirectories found"
        echo
        press_enter_to_continue
        echo "$current_path"
        return
    fi
    
    echo "Available remote folders:"
    local counter=1
    for dir in "${dirs[@]}"; do
        local dir_info=$(execute_remote_command "ls -ld '$current_path/$dir' 2>/dev/null | awk '{print \$1, \$3, \$4, \$5, \$6, \$7, \$8}'")
        print_menu_option "$counter" "$dir" "$dir_info"
        ((counter++))
    done
    
    echo
    echo "[c] Cancel - stay in current directory"
    
    echo
    while true; do
        echo -n "❯ Select folder (1-${#dirs[@]}) or 'c' to cancel: "
        read folder_choice
        
        if [[ "$folder_choice" == "c" ]] || [[ "$folder_choice" == "C" ]]; then
            echo "$current_path"
            return
        elif [[ "$folder_choice" =~ ^[0-9]+$ ]] && [[ "$folder_choice" -ge 1 ]] && [[ "$folder_choice" -le "${#dirs[@]}" ]]; then
            local selected_dir="${dirs[$((folder_choice-1))]}"
            local new_path="$current_path/$selected_dir"
            
            if execute_remote_command "test -d '$new_path'"; then
                print_status "SUCCESS" "Navigated to: $new_path"
                echo
                press_enter_to_continue
                echo "$new_path"
                return
            else
                print_status "ERROR" "Remote directory does not exist: $new_path"
                echo
                press_enter_to_continue
                echo "$current_path"
                return
            fi
        else
            echo "❌ Invalid choice. Please enter a number between 1 and ${#dirs[@]}, or 'c' to cancel"
        fi
    done
}

remote_navigate_up() {
    local current_path="$1"
    
    # Check if we're already at root
    if [[ "$current_path" == "/" ]]; then
        print_status "INFO" "Already at root directory"
        echo
        press_enter_to_continue
        echo "$current_path"
        return
    fi
    
    local parent_path=$(dirname "$current_path")
    
    echo
    print_section_header "Navigate Up (Remote)"
    print_status "INFO" "Moving from: $current_path"
    print_status "INFO" "Moving to: $parent_path"
    
    if execute_remote_command "test -d '$parent_path'"; then
        print_status "SUCCESS" "Successfully navigated up to: $parent_path"
        echo
        press_enter_to_continue
        echo "$parent_path"
    else
        print_status "ERROR" "Cannot access remote parent directory: $parent_path"
        echo
        press_enter_to_continue
        echo "$current_path"
    fi
}

remote_change_view_mode() {
    local current_path="$1"
    
    echo
    print_section_header "Change Remote View Mode"
    print_menu_option "1" "Detailed View" "Show full file details with icons and colors"
    print_menu_option "2" "Copy View" "Show details + full paths for easy copying"
    print_menu_option "3" "Simple View" "Show filenames only"
    
    echo
    while true; do
        echo -n "❯ Select view mode (1-3): "
        read view_choice
        
        case "$view_choice" in
            1)
                echo
                list_remote_directory "$current_path" "detailed"
                break
                ;;
            2)
                echo
                list_remote_directory "$current_path" "copy"
                break
                ;;
            3)
                echo
                list_remote_directory "$current_path" "simple"
                break
                ;;
            *)
                echo "❌ Invalid choice. Please enter a number between 1 and 3"
                ;;
        esac
    done
    
    echo
    press_enter_to_continue
}

remote_goto_path() {
    local current_path="$1"
    
    echo
    print_section_header "Go to Specific Remote Path"
    echo "Current remote directory: $current_path"
    echo
    echo -n "❯ Enter remote path to navigate to: "
    read target_path
    
    if [[ -z "$target_path" ]]; then
        print_status "INFO" "No path entered, staying in current directory"
        echo
        press_enter_to_continue
        echo "$current_path"
        return
    fi
    
    # Expand tilde for remote home directory
    if [[ "$target_path" =~ ^\~ ]]; then
        local remote_home=$(execute_remote_command "echo \$HOME" 2>/dev/null)
        if [[ -n "$remote_home" ]]; then
            target_path="${target_path/#\~/$remote_home}"
        fi
    fi
    
    if execute_remote_command "test -d '$target_path'"; then
        print_status "SUCCESS" "Navigated to: $target_path"
        echo
        press_enter_to_continue
        echo "$target_path"
    else
        print_status "ERROR" "Remote directory does not exist: $target_path"
        echo
        echo -n "❯ Would you like to browse the parent directory? (y/N): "
        read browse_parent
        if [[ "$browse_parent" =~ ^[Yy] ]]; then
            local parent_dir=$(dirname "$target_path")
            if execute_remote_command "test -d '$parent_dir'"; then
                print_status "INFO" "Showing parent directory: $parent_dir"
                echo
                list_remote_directory "$parent_dir" "simple"
                echo
                press_enter_to_continue
                echo "$current_path"
                return
            fi
        fi
        echo
        press_enter_to_continue
        echo "$current_path"
    fi
}

quick_transfer_menu() {
    print_header
    print_section_header "Quick Transfer"
    
    if [[ "$DEBUG" == true ]]; then
        debug_log "Starting quick_transfer_menu"
    fi
    
    print_color "YELLOW" "ℹ️  Quick Transfer allows you to enter connection details manually each time."
    print_color "YELLOW" "   For saved connections, use Options 4 or 5 (Upload/Download Files)."
    
    echo
    print_menu_option "1" "Quick Upload" "Upload with manual connection details"
    print_menu_option "2" "Quick Download" "Download with manual connection details"
    print_menu_option "3" "Back to Main Menu" "Return to main menu"
    
    echo
    local choice
    
    # Direct prompt without command substitution
    while true; do
        echo -n "❯ Select option (1-3): "
        read choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le 3 ]]; then
            break
        else
            echo "❌ Invalid choice. Please enter a number between 1 and 3"
        fi
    done
    
    case "$choice" in
        1)
            quick_upload_manual
            ;;
        2)
            quick_download_manual
            ;;
        3)
            return
            ;;
    esac
}

quick_upload_manual() {
    print_section_header "Quick Upload - Manual Connection"
    
    # Get connection details
    echo
    echo -n "❯ Remote hostname or IP: "
    read temp_host
    if [[ -z "$temp_host" ]]; then
        print_status "ERROR" "Host cannot be empty"
        press_enter_to_continue
        return
    fi
    
    echo -n "❯ Remote username [default: ubuntu]: "
    read temp_user
    temp_user="${temp_user:-ubuntu}"
    
    echo -n "❯ SSH port [default: 22]: "
    read temp_port
    temp_port="${temp_port:-22}"
    
    echo -n "❯ SSH key path (leave empty for password auth): "
    read temp_ssh_key
    
    # Get transfer details
    echo
    echo -n "❯ Local source path [default: $PWD]: "
    read local_source
    local_source="${local_source:-$PWD}"
    
    if [[ ! -e "$local_source" ]]; then
        print_status "ERROR" "Source path does not exist: $local_source"
        press_enter_to_continue
        return
    fi
    
    # Select transfer type
    if ! select_transfer_type "$local_source" "upload"; then
        print_status "ERROR" "Transfer type selection failed"
        press_enter_to_continue
        return
    fi
    
    echo -n "❯ Remote destination path [default: ~]: "
    read remote_dest
    remote_dest="${remote_dest:-~}"
    
    # Show transfer summary
    echo
    print_color "BOLD_YELLOW" "📤 QUICK UPLOAD SUMMARY"
    print_color "BOLD_BLUE" "$(printf '%*s' 50 | tr ' ' '=')"
    print_color "WHITE" "Source:      $local_source"
    print_color "WHITE" "Destination: $temp_user@$temp_host:$remote_dest"
    print_color "WHITE" "SSH Key:     ${temp_ssh_key:-'Password Authentication'}"
    
    # Build and show the command that will be executed
    local auth_method="ssh_key"
    if [[ -z "$temp_ssh_key" ]]; then
        auth_method="password"
    fi
    
    local preview_scp_command=$(build_enhanced_scp_command "upload" "$local_source" "$remote_dest" "$temp_host" "$temp_user" "$auth_method" "$temp_ssh_key")
    # Add additional options for quick transfer
    preview_scp_command="${preview_scp_command/scp/scp -P $temp_port -o ConnectTimeout=$CONNECTION_TIMEOUT -o StrictHostKeyChecking=no}"
    
    echo
    print_color "BOLD_CYAN" "🔍 Command that will be executed:"
    format_enhanced_command_display "$preview_scp_command"
    
    echo
    echo -n "❯ Proceed with upload? (y/N) [default: n]: "
    read confirm
    confirm="${confirm:-n}"
    
    if [[ "$confirm" =~ ^[Yy] ]]; then
        # Build enhanced SCP command with transfer type support
        local auth_method="ssh_key"
        if [[ -z "$temp_ssh_key" ]]; then
            auth_method="password"
        fi
        
        local scp_command=$(build_enhanced_scp_command "upload" "$local_source" "$remote_dest" "$temp_host" "$temp_user" "$auth_method" "$temp_ssh_key")
        
        # Add additional options for quick transfer
        scp_command="${scp_command/scp/scp -P $temp_port -o ConnectTimeout=$CONNECTION_TIMEOUT -o StrictHostKeyChecking=no}"
        
        # Add verbose flag if DEBUG or VERBOSE is enabled
        if [[ "$VERBOSE" == true ]] || [[ "$DEBUG" == true ]]; then
            scp_command="${scp_command/scp/scp -v}"
            debug_log "Verbose mode enabled for quick upload"
        fi
        
        # Record transfer start time
        local start_time=$(date +%s)
        local start_time_formatted=$(date '+%Y-%m-%d %H:%M:%S')
        
        print_progress "Executing quick upload..."
        print_color "CYAN" "⏰ Transfer started at: $start_time_formatted"
        
        if [[ "$DEBUG" == true ]]; then
            print_color "PURPLE" "🐛 DEBUG: Executing command"
            format_enhanced_command_display "$scp_command"
            echo
        fi
        
        # Execute with live progress display
        echo "📤 Upload in progress..."
        echo
        
        # Create a log file to capture all output for analysis
        local transfer_log=$(mktemp)
        
        # Execute command and capture output while showing it live
        script -q -c "$scp_command" "$transfer_log" 2>&1
        local exit_code=$?
        
        # Read the captured output for analysis
        local scp_output
        scp_output=$(cat "$transfer_log" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | sed 's/\r/\n/g')
        
        # Clean up
        rm -f "$transfer_log" 2>/dev/null
        
        # Calculate and display transfer timing
        local end_time=$(date +%s)
        local end_time_formatted=$(date '+%Y-%m-%d %H:%M:%S')
        local duration=$((end_time - start_time))
        local duration_formatted=$(printf '%02d:%02d:%02d' $((duration/3600)) $((duration%3600/60)) $((duration%60)))
        
        echo
        print_color "CYAN" "⏰ Transfer completed at: $end_time_formatted"
        print_color "CYAN" "⏱️  Total duration: $duration_formatted"
        
        # Extract transfer statistics from SCP output
        local transfer_stats=$(echo "$scp_output" | grep -E "[0-9]+%" | tail -1)
        if [[ -n "$transfer_stats" ]]; then
            local size_info=$(echo "$transfer_stats" | grep -oE '[0-9]+[KMG]?B' | head -1)
            local speed_info=$(echo "$transfer_stats" | grep -oE '[0-9]+\.[0-9]+[KMG]?B/s')
            if [[ -n "$size_info" ]] && [[ -n "$speed_info" ]]; then
                print_color "CYAN" "📊 Final stats: $size_info transferred at $speed_info"
            fi
        fi
        
        echo
        # Enhanced transfer analysis
        analyze_transfer_results "$scp_output" "$exit_code"
    else
        print_status "INFO" "Upload cancelled"
    fi
    
    press_enter_to_continue
}

quick_download_manual() {
    print_section_header "Quick Download - Manual Connection"
    
    # Get connection details
    echo
    echo -n "❯ Remote hostname or IP: "
    read temp_host
    if [[ -z "$temp_host" ]]; then
        print_status "ERROR" "Host cannot be empty"
        press_enter_to_continue
        return
    fi
    
    echo -n "❯ Remote username [default: ubuntu]: "
    read temp_user
    temp_user="${temp_user:-ubuntu}"
    
    echo -n "❯ SSH port [default: 22]: "
    read temp_port
    temp_port="${temp_port:-22}"
    
    echo -n "❯ SSH key path (leave empty for password auth): "
    read temp_ssh_key
    
    # Get transfer details
    echo
    echo -n "❯ Remote source path [default: ~]: "
    read remote_source
    remote_source="${remote_source:-~}"
    
    # Select transfer type
    if ! select_transfer_type "$remote_source" "download"; then
        print_status "ERROR" "Transfer type selection failed"
        press_enter_to_continue
        return
    fi
    
    echo -n "❯ Local destination path [default: $PWD]: "
    read local_dest
    local_dest="${local_dest:-$PWD}"
    
    # Create local destination if it doesn't exist
    if [[ ! -d "$local_dest" ]]; then
        mkdir -p "$local_dest" 2>/dev/null || {
            print_status "ERROR" "Cannot create local destination: $local_dest"
            press_enter_to_continue
            return
        }
    fi
    
    # Show transfer summary
    echo
    print_color "BOLD_YELLOW" "📥 QUICK DOWNLOAD SUMMARY"
    print_color "BOLD_BLUE" "$(printf '%*s' 50 | tr ' ' '=')"
    print_color "WHITE" "Source:      $temp_user@$temp_host:$remote_source"
    print_color "WHITE" "Destination: $local_dest"
    print_color "WHITE" "SSH Key:     ${temp_ssh_key:-'Password Authentication'}"
    echo
    
    # Check for existing files/directories that might conflict
    local filename=$(basename "$remote_source")
    local full_dest_path="$local_dest/$filename"
    
    if [[ -e "$full_dest_path" ]]; then
        echo
        print_color "YELLOW" "⚠️  WARNING: Destination already exists!"
        if [[ -d "$full_dest_path" ]]; then
            print_color "YELLOW" "   Directory: $full_dest_path"
        else
            print_color "YELLOW" "   File: $full_dest_path"
            local file_size=$(du -h "$full_dest_path" 2>/dev/null | cut -f1)
            print_color "YELLOW" "   Size: ${file_size:-unknown}"
        fi
        echo
        echo -n "❯ This will overwrite the existing file/directory. Continue? (y/N) [default: n]: "
        read overwrite_confirm
        overwrite_confirm="${overwrite_confirm:-n}"
        
        if [[ ! "$overwrite_confirm" =~ ^[Yy] ]]; then
            print_status "INFO" "Quick download cancelled to prevent overwrite"
            press_enter_to_continue
            return
        fi
        
        if [[ -d "$full_dest_path" ]]; then
            echo
            print_color "RED" "⚠️  WARNING: You're about to overwrite a directory!"
            echo -n "❯ Are you absolutely sure? Type 'YES' to confirm: "
            read final_confirm
            if [[ "$final_confirm" != "YES" ]]; then
                print_status "INFO" "Quick download cancelled"
                press_enter_to_continue
                return
            fi
        fi
    fi
    
    # Build and show the command that will be executed
    local auth_method="ssh_key"
    if [[ -z "$temp_ssh_key" ]]; then
        auth_method="password"
    fi
    
    local preview_scp_command=$(build_enhanced_scp_command "download" "$remote_source" "$local_dest" "$temp_host" "$temp_user" "$auth_method" "$temp_ssh_key")
    # Add additional options for quick transfer
    preview_scp_command="${preview_scp_command/scp/scp -P $temp_port -o ConnectTimeout=$CONNECTION_TIMEOUT -o StrictHostKeyChecking=no}"
    
    echo
    print_color "BOLD_CYAN" "🔍 Command that will be executed:"
    format_enhanced_command_display "$preview_scp_command"
    
    echo
    echo -n "❯ Proceed with download? (y/N) [default: n]: "
    read confirm
    confirm="${confirm:-n}"
    
    if [[ "$confirm" =~ ^[Yy] ]]; then
        # Build enhanced SCP command with transfer type support
        local auth_method="ssh_key"
        if [[ -z "$temp_ssh_key" ]]; then
            auth_method="password"
        fi
        
        local scp_command=$(build_enhanced_scp_command "download" "$remote_source" "$local_dest" "$temp_host" "$temp_user" "$auth_method" "$temp_ssh_key")
        
        # Add additional options for quick transfer
        scp_command="${scp_command/scp/scp -P $temp_port -o ConnectTimeout=$CONNECTION_TIMEOUT -o StrictHostKeyChecking=no}"
        
        # Add verbose flag if DEBUG or VERBOSE is enabled
        if [[ "$VERBOSE" == true ]] || [[ "$DEBUG" == true ]]; then
            scp_command="${scp_command/scp/scp -v}"
            debug_log "Verbose mode enabled for quick download"
        fi
        
        # Record transfer start time
        local start_time=$(date +%s)
        local start_time_formatted=$(date '+%Y-%m-%d %H:%M:%S')
        
        print_progress "Executing quick download..."
        print_color "CYAN" "⏰ Transfer started at: $start_time_formatted"
        
        if [[ "$DEBUG" == true ]]; then
            print_color "PURPLE" "🐛 DEBUG: Executing command"
            format_enhanced_command_display "$scp_command"
            echo
        fi
        
        # Execute with live progress display
        echo "📥 Download in progress..."
        echo
        
        # Create a log file to capture all output for analysis
        local transfer_log=$(mktemp)
        
        # Execute command and capture output while showing it live
        script -q -c "$scp_command" "$transfer_log" 2>&1
        local exit_code=$?
        
        # Read the captured output for analysis
        local scp_output
        scp_output=$(cat "$transfer_log" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | sed 's/\r/\n/g')
        
        # Clean up
        rm -f "$transfer_log" 2>/dev/null
        
        # Calculate and display transfer timing
        local end_time=$(date +%s)
        local end_time_formatted=$(date '+%Y-%m-%d %H:%M:%S')
        local duration=$((end_time - start_time))
        local duration_formatted=$(printf '%02d:%02d:%02d' $((duration/3600)) $((duration%3600/60)) $((duration%60)))
        
        echo
        print_color "CYAN" "⏰ Transfer completed at: $end_time_formatted"
        print_color "CYAN" "⏱️  Total duration: $duration_formatted"
        
        # Extract transfer statistics from SCP output
        local transfer_stats=$(echo "$scp_output" | grep -E "[0-9]+%" | tail -1)
        if [[ -n "$transfer_stats" ]]; then
            local size_info=$(echo "$transfer_stats" | grep -oE '[0-9]+[KMG]?B' | head -1)
            local speed_info=$(echo "$transfer_stats" | grep -oE '[0-9]+\.[0-9]+[KMG]?B/s')
            if [[ -n "$size_info" ]] && [[ -n "$speed_info" ]]; then
                print_color "CYAN" "📊 Final stats: $size_info transferred at $speed_info"
            fi
        fi
        
        echo
        # Enhanced transfer analysis
        analyze_transfer_results "$scp_output" "$exit_code"
    else
        print_status "INFO" "Download cancelled"
    fi
    
    press_enter_to_continue
}

manage_connections_menu() {
    while true; do
        print_header
        print_section_header "Connection Management"
        
        if list_saved_connections; then
            echo
        fi
        
        print_section_header "Management Options"
        print_menu_option "1" "View All Connections" "Display detailed connection information"
        print_menu_option "2" "Edit Connection" "Modify an existing connection"
        print_menu_option "3" "Delete Connection" "Remove a saved connection"
        print_menu_option "4" "Test Connection" "Test connectivity to a saved connection"
        print_menu_option "5" "Export Connections" "Export connections to file"
        print_menu_option "6" "Import Connections" "Import connections from file"
        print_menu_option "7" "Back to Main Menu" "Return to main menu"
        
        echo
        local choice
        
        # Direct prompt without command substitution
        while true; do
            echo -n "❯ Select option (1-7): "
            read choice
            if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le 7 ]]; then
                break
            else
                echo "❌ Invalid choice. Please enter a number between 1 and 7"
            fi
        done
        
        case "$choice" in
            1)
                view_connection_details
                ;;
            2)
                edit_connection_menu
                ;;
            3)
                delete_connection_menu
                ;;
            4)
                test_connection_menu
                ;;
            5)
                export_connections
                ;;
            6)
                import_connections
                ;;
            7)
                return
                ;;
        esac
    done
}

view_connection_details() {
    print_header
    print_section_header "Connection Details"
    
    initialize_connections_dir
    
    if [[ ! -f "$SAVED_CONNECTIONS_FILE" ]] || [[ ! -s "$SAVED_CONNECTIONS_FILE" ]]; then
        print_status "INFO" "No saved connections found"
        press_enter_to_continue
        return
    fi
    
    local connections_count=$(cat "$SAVED_CONNECTIONS_FILE" | jq 'length')
    
    if [[ "$connections_count" -eq 0 ]]; then
        print_status "INFO" "No saved connections found"
        press_enter_to_continue
        return
    fi
    
    echo
    cat "$SAVED_CONNECTIONS_FILE" | jq -r '.[] | "
Connection: \(.name)
ID: \(.id)
Host: \(.host)
User: \(.user)
Port: \(.port)
SSH Key: \(.ssh_key // "Password Authentication")
Remote Path: \(.remote_path)
Protocol: \(.protocol)
Created: \(.created)
Last Used: \(.last_used)
" + ("=" * 60)'
    
    press_enter_to_continue
}

edit_connection_menu() {
    print_header
    print_section_header "Edit Connection"
    
    initialize_connections_dir
    
    if [[ ! -f "$SAVED_CONNECTIONS_FILE" ]] || [[ ! -s "$SAVED_CONNECTIONS_FILE" ]]; then
        print_status "INFO" "No saved connections found"
        press_enter_to_continue
        return
    fi
    
    local connections_count=$(cat "$SAVED_CONNECTIONS_FILE" | jq 'length')
    
    if [[ "$connections_count" -eq 0 ]]; then
        print_status "INFO" "No saved connections found"
        press_enter_to_continue
        return
    fi
    
    echo
    echo "Select connection to edit:"
    
    local connection_ids=()
    readarray -t connection_ids < <(cat "$SAVED_CONNECTIONS_FILE" | jq -r '.[].id')
    
    # Display connections without using subshell
    local counter=1
    while read -r line; do
        IFS='|' read -r name host user <<< "$line"
        print_menu_option "$counter" "$name" "$user@$host"
        ((counter++))
    done < <(cat "$SAVED_CONNECTIONS_FILE" | jq -r '.[] | "\(.name)|\(.host)|\(.user)"')
    
    echo
    echo "[c] Cancel - Return to connection management"
    
    echo
    local choice
    
    # Direct prompt without command substitution
    while true; do
        echo -n "❯ Select connection to edit (1-$connections_count) or 'c' to cancel: "
        read choice
        if [[ "$choice" == "c" ]] || [[ "$choice" == "C" ]]; then
            return  # Cancel
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "$connections_count" ]]; then
            break
        else
            echo "❌ Invalid choice. Please enter a number between 1 and $connections_count, or 'c' to cancel"
        fi
    done
    
    local selected_id="${connection_ids[$((choice-1))]}"
    edit_connection_fields "$selected_id"
}

edit_connection_fields() {
    local connection_id="$1"
    
    # Load current connection data
    local connection_data=$(cat "$SAVED_CONNECTIONS_FILE" | jq -r ".[] | select(.id == \"$connection_id\")")
    
    if [[ -z "$connection_data" ]]; then
        print_status "ERROR" "Connection not found"
        press_enter_to_continue
        return
    fi
    
    # Extract current values
    local current_name=$(echo "$connection_data" | jq -r '.name')
    local current_host=$(echo "$connection_data" | jq -r '.host')
    local current_user=$(echo "$connection_data" | jq -r '.user')
    local current_port=$(echo "$connection_data" | jq -r '.port')
    local current_ssh_key=$(echo "$connection_data" | jq -r '.ssh_key // ""')
    local current_remote_path=$(echo "$connection_data" | jq -r '.remote_path')
    
    print_header
    print_section_header "Edit Connection: $current_name"
    
    echo
    print_color "YELLOW" "Current values shown in brackets. Press Enter to keep current value."
    echo
    
    # Get new values
    echo -n "❯ Connection name [$current_name]: "
    read new_name
    new_name="${new_name:-$current_name}"
    
    echo -n "❯ Remote hostname or IP [$current_host]: "
    read new_host
    new_host="${new_host:-$current_host}"
    
    echo -n "❯ Remote username [$current_user]: "
    read new_user
    new_user="${new_user:-$current_user}"
    
    echo -n "❯ SSH port [$current_port]: "
    read new_port
    new_port="${new_port:-$current_port}"
    
    echo -n "❯ SSH key path [$current_ssh_key]: "
    read new_ssh_key
    new_ssh_key="${new_ssh_key:-$current_ssh_key}"
    
    echo -n "❯ Default remote path [$current_remote_path]: "
    read new_remote_path
    new_remote_path="${new_remote_path:-$current_remote_path}"
    
    # Show summary
    echo
    print_color "BOLD_YELLOW" "Updated Connection Summary:"
    echo "Name: $new_name"
    echo "Host: $new_host"
    echo "User: $new_user"
    echo "Port: $new_port"
    echo "SSH Key: ${new_ssh_key:-'Password Authentication'}"
    echo "Remote Path: $new_remote_path"
    
    echo
    echo -n "❯ Save changes? (y/N) [default: n]: "
    read confirm
    confirm="${confirm:-n}"
    
    if [[ "$confirm" =~ ^[Yy] ]]; then
        # Delete old connection and save new one
        delete_connection "$connection_id"
        save_connection_data "$new_name" "$new_host" "$new_user" "$new_port" "$new_ssh_key" "$new_remote_path"
        print_status "SUCCESS" "Connection updated successfully!"
    else
        print_status "INFO" "Changes cancelled"
    fi
    
    press_enter_to_continue
}

delete_connection_menu() {
    print_header
    print_section_header "Delete Connection"
    
    initialize_connections_dir
    
    if [[ ! -f "$SAVED_CONNECTIONS_FILE" ]] || [[ ! -s "$SAVED_CONNECTIONS_FILE" ]]; then
        print_status "INFO" "No saved connections found"
        press_enter_to_continue
        return
    fi
    
    local connections_count=$(cat "$SAVED_CONNECTIONS_FILE" | jq 'length')
    
    if [[ "$connections_count" -eq 0 ]]; then
        print_status "INFO" "No saved connections found"
        press_enter_to_continue
        return
    fi
    
    echo
    echo "Select connection to delete:"
    
    local connection_ids=()
    readarray -t connection_ids < <(cat "$SAVED_CONNECTIONS_FILE" | jq -r '.[].id')
    
    # Display connections without using subshell
    local counter=1
    while read -r line; do
        IFS='|' read -r name host user <<< "$line"
        print_menu_option "$counter" "$name" "$user@$host"
        ((counter++))
    done < <(cat "$SAVED_CONNECTIONS_FILE" | jq -r '.[] | "\(.name)|\(.host)|\(.user)"')
    
    echo
    echo "[c] Cancel - Return to connection management"
    
    echo
    local choice
    
    # Direct prompt without command substitution
    while true; do
        echo -n "❯ Select connection to delete (1-$connections_count) or 'c' to cancel: "
        read choice
        if [[ "$choice" == "c" ]] || [[ "$choice" == "C" ]]; then
            return  # Cancel
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "$connections_count" ]]; then
            break
        else
            echo "❌ Invalid choice. Please enter a number between 1 and $connections_count, or 'c' to cancel"
        fi
    done
    
    local selected_id="${connection_ids[$((choice-1))]}"
    local connection_name=$(cat "$SAVED_CONNECTIONS_FILE" | jq -r ".[] | select(.id == \"$selected_id\") | .name")
    
    echo
    echo -n "❯ Are you sure you want to delete '$connection_name'? (y/N) [default: n]: "
    read confirm
    confirm="${confirm:-n}"
    
    if [[ "$confirm" =~ ^[Yy] ]]; then
        delete_connection "$selected_id"
        print_status "SUCCESS" "Connection '$connection_name' deleted successfully!"
    else
        print_status "INFO" "Deletion cancelled"
    fi
    
    press_enter_to_continue
}

test_connection_menu() {
    print_header
    print_section_header "Test Connection"
    
    initialize_connections_dir
    
    if [[ ! -f "$SAVED_CONNECTIONS_FILE" ]] || [[ ! -s "$SAVED_CONNECTIONS_FILE" ]]; then
        print_status "INFO" "No saved connections found"
        press_enter_to_continue
        return
    fi
    
    local connections_count=$(cat "$SAVED_CONNECTIONS_FILE" | jq 'length')
    
    if [[ "$connections_count" -eq 0 ]]; then
        print_status "INFO" "No saved connections found"
        press_enter_to_continue
        return
    fi
    
    echo
    echo "Select connection to test:"
    
    local connection_ids=()
    readarray -t connection_ids < <(cat "$SAVED_CONNECTIONS_FILE" | jq -r '.[].id')
    
    # Display connections without using subshell
    local counter=1
    while read -r line; do
        IFS='|' read -r name host user <<< "$line"
        print_menu_option "$counter" "$name" "$user@$host"
        ((counter++))
    done < <(cat "$SAVED_CONNECTIONS_FILE" | jq -r '.[] | "\(.name)|\(.host)|\(.user)"')
    
    echo
    echo "[c] Cancel - Return to connection management"
    
    echo
    local choice
    
    # Direct prompt without command substitution
    while true; do
        echo -n "❯ Select connection to test (1-$connections_count) or 'c' to cancel: "
        read choice
        if [[ "$choice" == "c" ]] || [[ "$choice" == "C" ]]; then
            return  # Cancel
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "$connections_count" ]]; then
            break
        else
            echo "❌ Invalid choice. Please enter a number between 1 and $connections_count, or 'c' to cancel"
        fi
    done
    
    local selected_id="${connection_ids[$((choice-1))]}"
    local connection_data=$(cat "$SAVED_CONNECTIONS_FILE" | jq -r ".[] | select(.id == \"$selected_id\")")
    
    if [[ -n "$connection_data" ]]; then
        local test_host=$(echo "$connection_data" | jq -r '.host')
        local test_user=$(echo "$connection_data" | jq -r '.user')
        local test_port=$(echo "$connection_data" | jq -r '.port')
        local test_ssh_key=$(echo "$connection_data" | jq -r '.ssh_key // ""')
        local test_name=$(echo "$connection_data" | jq -r '.name')
        
        print_progress "Testing connection to $test_name..."
        
        # Check if this connection uses password authentication
        local connection_successful=false
        
        if [[ -z "$test_ssh_key" ]]; then
            # Password authentication - prompt for password
            echo
            echo -n "❯ Enter password for $test_user@$test_host: "
            read -s password
            echo  # Add newline after hidden password input
            
            if [[ -z "$password" ]]; then
                print_status "ERROR" "Password cannot be empty"
            else
                print_progress "Testing with password authentication..."
                if test_ssh_connection_with_password "$test_host" "$test_user" "$test_port" "$password"; then
                    connection_successful=true
                fi
            fi
        else
            # SSH key authentication
            print_progress "Testing with SSH key authentication..."
            if test_ssh_connection "$test_host" "$test_user" "$test_port" "$test_ssh_key"; then
                connection_successful=true
            fi
        fi
        
        # Record the validation attempt
        local auth_type_display
        if [[ -z "$test_ssh_key" ]]; then
            auth_type_display="Password"
        else
            auth_type_display="SSH Key"
        fi
        
        record_connection_validation "$test_name" "$test_host" "$test_user" "$test_port" "$auth_type_display" "$connection_successful"
        
        echo
        if [[ "$connection_successful" == true ]]; then
            print_status "SUCCESS" "Connection test successful for '$test_name'!"
        else
            print_status "ERROR" "Connection test failed for '$test_name'"
            echo
            print_color "YELLOW" "💡 Troubleshooting tips:"
            print_color "YELLOW" "   • Verify the hostname/IP is correct: $test_host"
            print_color "YELLOW" "   • Check if the port is accessible: $test_port"
            print_color "YELLOW" "   • Confirm the username is correct: $test_user"
            
            if [[ -z "$test_ssh_key" ]]; then
                print_color "YELLOW" "   • Verify the password is correct"
                print_color "YELLOW" "   • Check if password authentication is enabled on the server"
            else
                print_color "YELLOW" "   • Verify the SSH key path: $test_ssh_key"
                print_color "YELLOW" "   • Check if the public key is authorized on the server"
                print_color "YELLOW" "   • Ensure the SSH key file permissions are correct (600)"
            fi
        fi
    else
        print_status "ERROR" "Connection data not found"
    fi
    
    press_enter_to_continue
}

export_connections() {
    print_header
    print_section_header "Export Connections"
    
    initialize_connections_dir
    
    if [[ ! -f "$SAVED_CONNECTIONS_FILE" ]] || [[ ! -s "$SAVED_CONNECTIONS_FILE" ]]; then
        print_status "INFO" "No saved connections found"
        press_enter_to_continue
        return
    fi
    
    echo -n "❯ Export file path [default: $PWD/scp_connections_export.json]: "
    read export_path
    export_path="${export_path:-$PWD/scp_connections_export.json}"
    
    if cp "$SAVED_CONNECTIONS_FILE" "$export_path"; then
        print_status "SUCCESS" "Connections exported to: $export_path"
    else
        print_status "ERROR" "Failed to export connections"
    fi
    
    press_enter_to_continue
}

import_connections() {
    print_header
    print_section_header "Import Connections"
    
    echo -n "❯ Import file path: "
    read import_path
    
    if [[ ! -f "$import_path" ]]; then
        print_status "ERROR" "Import file not found: $import_path"
        press_enter_to_continue
        return
    fi
    
    # Validate JSON format
    if ! jq empty "$import_path" 2>/dev/null; then
        print_status "ERROR" "Invalid JSON format in import file"
        press_enter_to_continue
        return
    fi
    
    initialize_connections_dir
    
    # Merge with existing connections
    local existing_connections="[]"
    if [[ -f "$SAVED_CONNECTIONS_FILE" ]] && [[ -s "$SAVED_CONNECTIONS_FILE" ]]; then
        existing_connections=$(cat "$SAVED_CONNECTIONS_FILE")
    fi
    
    local imported_connections=$(cat "$import_path")
    local merged_connections=$(echo "$existing_connections $imported_connections" | jq -s 'add | unique_by(.id)')
    
    echo "$merged_connections" > "$SAVED_CONNECTIONS_FILE"
    
    local imported_count=$(echo "$imported_connections" | jq 'length')
    print_status "SUCCESS" "Imported $imported_count connections"
    
    press_enter_to_continue
}

show_help() {
    print_header
    print_section_header "Help & Usage Information"
    
    cat << 'EOF'
🚀 SCP MANAGER - HELP GUIDE

OVERVIEW:
  SCP Manager is an interactive file transfer utility that provides a user-friendly
  interface for secure file transfers between local and remote systems using SCP.

KEY FEATURES:
  • Interactive SSH connection management
  • Remote directory browsing and navigation
  • Bidirectional file transfers (upload/download)
  • SSH key and password authentication support
  • Saved connection profiles
  • Debug and verbose modes
  • Colorized output and progress indicators

AUTHENTICATION METHODS:
  1. SSH Private Key Files (recommended)
  2. Password Authentication
  3. Default SSH key (~/.ssh/id_rsa)

NAVIGATION:
  • Use numbered menu options to navigate
  • Browse remote directories interactively
  • Select directories for transfer operations
  • View detailed file listings with permissions

TRANSFER MODES:
  • Upload: Local → Remote
  • Download: Remote → Local
  • Quick Transfer: Minimal prompts for fast operations

DEBUGGING:
  • Enable debug mode to see SSH/SCP commands
  • Verbose mode shows detailed transfer progress
  • Connection testing and validation

SAVED CONNECTIONS:
  • Automatically saves successful connections
  • Quick reconnection to previously used hosts
  • Stored in ~/.scp_manager_connections

TIPS:
  • Test connections before file transfers
  • Use absolute paths for reliable transfers
  • Enable debug mode to troubleshoot issues
  • Save connection profiles for frequent hosts

EOF
    
    press_enter_to_continue
}

# Command line argument parsing
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--debug)
                DEBUG=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -t|--timeout)
                CONNECTION_TIMEOUT="$2"
                shift 2
                ;;
            --version)
                echo "SCP Manager v$VERSION"
                exit 0
                ;;
            *)
                print_status "ERROR" "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

# Main execution
main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    # Load last validation data from previous sessions
    load_last_validation
    
    # Check dependencies
    if ! command -v ssh &> /dev/null; then
        print_status "ERROR" "SSH client not found. Please install OpenSSH client."
        exit 1
    fi
    
    if ! command -v scp &> /dev/null; then
        print_status "ERROR" "SCP client not found. Please install OpenSSH client."
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        print_status "ERROR" "jq not found. Please install jq for JSON processing: sudo apt install jq"
        exit 1
    fi
    
    # Initialize and start main menu
    debug_log "Starting SCP Manager v$VERSION"
    main_menu
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
