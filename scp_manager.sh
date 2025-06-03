#!/bin/bash

# ============================================================================
# SCP File Transfer Manager - Interactive Bash Utility
# A robust, colorful, and feature-rich SCP file transfer tool
# ============================================================================

VERSION="1.0.0"
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
LOCAL_PATH=""
REMOTE_PATH=""
CONNECTION_TIMEOUT="10"
CONNECTIONS_DIR="$HOME/.scp_manager"
SAVED_CONNECTIONS_FILE="$CONNECTIONS_DIR/connections.json"

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
}

generate_connection_id() {
    local host="$1"
    local user="$2"
    local port="$3"
    echo "${user}@${host}:${port}"
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
    "id": "$(generate_connection_id "$host" "$user" "$port")",
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
    
    # Check if connection already exists and update or add
    local connection_id=$(generate_connection_id "$host" "$user" "$port")
    local updated_connections
    
    if echo "$existing_connections" | grep -q "\"id\": \"$connection_id\""; then
        # Update existing connection
        updated_connections=$(echo "$existing_connections" | jq --argjson conn "$connection_json" \
            'map(if .id == $conn.id then $conn else . end)')
        debug_log "Updated existing connection: $connection_id"
    else
        # Add new connection
        updated_connections=$(echo "$existing_connections" | jq --argjson conn "$connection_json" \
            '. + [$conn]')
        debug_log "Added new connection: $connection_id"
    fi
    
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
    printf "%-3s %-20s %-15s %-10s %-20s %-15s\n" "No." "Name" "Host" "User" "SSH Key" "Last Used"
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
            ;;
        3)
            SSH_KEY="$HOME/.ssh/id_rsa"
            if [[ ! -f "$SSH_KEY" ]]; then
                print_status "WARNING" "Default SSH key not found, will use password authentication"
                SSH_KEY=""
            fi
            ;;
    esac
    
    print_progress "Testing SSH connection..."
    
    if test_ssh_connection "$REMOTE_HOST" "$REMOTE_USER" "$REMOTE_PORT" "$SSH_KEY"; then
        print_status "SUCCESS" "SSH connection established successfully!"
        
        # Save connection with all details
        save_connection_data "$CONNECTION_NAME" "$REMOTE_HOST" "$REMOTE_USER" "$REMOTE_PORT" "$SSH_KEY" "$REMOTE_PATH"
        return 0
    else
        print_status "ERROR" "Failed to establish SSH connection"
        print_status "INFO" "Please check your credentials and network connectivity"
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
        return 0
    else
        print_status "ERROR" "Failed to load connection data"
        return 1
    fi
}

# Remote file operations
execute_remote_command() {
    local command="$1"
    local ssh_opts="-o ConnectTimeout=$CONNECTION_TIMEOUT -o StrictHostKeyChecking=no"
    
    if [[ -n "$SSH_KEY" ]]; then
        ssh_opts="$ssh_opts -i $SSH_KEY"
    fi
    
    debug_log "Executing remote command: $command"
    
    ssh $ssh_opts -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "$command" 2>/dev/null
}

list_remote_directory() {
    local path="$1"
    local show_hidden="$2"
    
    print_progress "Listing remote directory: $path"
    
    local ls_command="ls -la"
    if [[ "$show_hidden" != "true" ]]; then
        ls_command="ls -l"
    fi
    
    local result
    result=$(execute_remote_command "cd '$path' && $ls_command" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        echo
        print_color "BOLD_GREEN" "📁 Remote Directory: $path"
        print_color "BOLD_BLUE" "$(printf '%*s' 80 | tr ' ' '=')"
        echo
        
        # Parse and colorize output
        echo "$result" | while read -r line; do
            if [[ "$line" =~ ^d ]]; then
                # Directory
                print_color "BOLD_BLUE" "📁 $line"
            elif [[ "$line" =~ ^l ]]; then
                # Symlink
                print_color "CYAN" "🔗 $line"
            elif [[ "$line" =~ ^- ]] && [[ "$line" =~ rwx ]]; then
                # Executable file
                print_color "BOLD_GREEN" "⚡ $line"
            elif [[ "$line" =~ ^- ]]; then
                # Regular file
                print_color "WHITE" "📄 $line"
            else
                echo "$line"
            fi
        done
        return 0
    else
        print_status "ERROR" "Failed to list directory: $path"
        print_status "ERROR" "$result"
        return 1
    fi
}

browse_remote_directory() {
    local current_path="$1"
    [[ -z "$current_path" ]] && current_path="~"
    
    while true; do
        print_header
        print_section_header "Remote Directory Browser"
        
        # Get current actual path
        local actual_path
        actual_path=$(execute_remote_command "cd '$current_path' && pwd")
        
        if [[ -z "$actual_path" ]]; then
            print_status "ERROR" "Cannot access directory: $current_path"
            current_path="~"
            continue
        fi
        
        current_path="$actual_path"
        
        # List directory contents
        list_remote_directory "$current_path"
        
        echo
        print_section_header "Directory Navigation"
        print_menu_option "1" "Change Directory" "Navigate to a different directory"
        print_menu_option "2" "Parent Directory" "Go up one level (..)"
        print_menu_option "3" "Home Directory" "Go to home directory (~)"
        print_menu_option "4" "Refresh" "Refresh current directory"
        print_menu_option "5" "Select Current Dir" "Use this directory for file operations"
        print_menu_option "6" "Back to Main Menu" "Return to main menu"
        
        echo
        local choice
        
        # Direct prompt without command substitution
        while true; do
            echo -n "❯ Select option (1-6): "
            read choice
            if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le 6 ]]; then
                break
            else
                echo "❌ Invalid choice. Please enter a number between 1 and 6"
            fi
        done
        
        case "$choice" in
            1)
                local new_path
                echo -n "❯ Enter directory path: "
                read new_path
                if [[ -n "$new_path" ]]; then
                    current_path="$new_path"
                fi
                ;;
            2)
                current_path="$current_path/.."
                ;;
            3)
                current_path="~"
                ;;
            4)
                # Refresh - just continue the loop
                ;;
            5)
                REMOTE_PATH="$current_path"
                print_status "SUCCESS" "Selected remote directory: $REMOTE_PATH"
                press_enter_to_continue
                return 0
                ;;
            6)
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
    
    # Get local source
    echo -n "❯ Local file/directory path to upload [default: $PWD]: "
    read local_source
    local_source="${local_source:-$PWD}"
    
    if [[ ! -e "$local_source" ]]; then
        print_status "ERROR" "Local path does not exist: $local_source"
        return 1
    fi
    
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
    
    # Get remote source
    echo -n "❯ Remote file/directory path to download [default: ${REMOTE_PATH:-~}]: "
    read remote_source
    remote_source="${remote_source:-${REMOTE_PATH:-~}}"
    
    # Get local destination
    echo -n "❯ Local destination path [default: $PWD]: "
    read local_dest
    local_dest="${local_dest:-$PWD}"
    
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

# Main menu functions
show_connection_status() {
    echo
    print_color "BOLD_CYAN" "🔗 CONNECTION STATUS"
    print_color "BOLD_BLUE" "$(printf '%*s' 50 | tr ' ' '=')"
    
    if [[ -n "$REMOTE_HOST" ]]; then
        print_color "GREEN" "✅ Host:        $REMOTE_HOST"
        print_color "GREEN" "✅ User:        $REMOTE_USER"
        print_color "GREEN" "✅ Port:        $REMOTE_PORT"
        print_color "GREEN" "✅ SSH Key:     ${SSH_KEY:-'Password Auth'}"
        print_color "GREEN" "✅ Remote Path: ${REMOTE_PATH:-'Not Set'}"
    else
        print_color "RED" "❌ No connection configured"
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
        print_menu_option "5" "Show Connection Info" "Display current connection details"
        print_menu_option "6" "Back to Main Menu" "Return to main menu"
        
        echo
        local choice
        
        # Direct prompt without command substitution
        while true; do
            echo -n "❯ Select option (1-6): "
            read choice
            if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le 6 ]]; then
                break
            else
                echo "❌ Invalid choice. Please enter a number between 1 and 6"
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
                if test_ssh_connection "$REMOTE_HOST" "$REMOTE_USER" "$REMOTE_PORT" "$SSH_KEY"; then
                    print_status "SUCCESS" "Connection test successful"
                else
                    print_status "ERROR" "Connection test failed"
                fi
                press_enter_to_continue
                ;;
            6)
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
        print_menu_option "3" "Browse Remote Files" "Navigate and explore remote directories"
        print_menu_option "4" "Upload Files" "Transfer files from local to remote"
        print_menu_option "5" "Download Files" "Transfer files from remote to local"
        print_menu_option "6" "Quick Transfer" "Fast file transfer with current settings"
        print_menu_option "7" "Settings" "Configure application settings"
        print_menu_option "8" "Help" "Show help and usage information"
        print_menu_option "9" "Exit" "Quit the application"
        
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
                if ! load_saved_connections; then
                    setup_ssh_connection
                fi
                press_enter_to_continue
                ;;
            2)
                manage_connections_menu
                ;;
            3)
                if select_saved_connection "browse"; then
                    browse_remote_directory
                fi
                press_enter_to_continue
                ;;
            4)
                upload_files
                press_enter_to_continue
                ;;
            5)
                download_files
                press_enter_to_continue
                ;;
            6)
                quick_transfer_menu
                ;;
            7)
                settings_menu
                ;;
            8)
                show_help
                ;;
            9)
                print_color "BOLD_CYAN" "👋 Thank you for using SCP Manager!"
                exit 0
                ;;
        esac
    done
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
    echo
    
    echo -n "❯ Proceed with upload? (y/N) [default: n]: "
    read confirm
    confirm="${confirm:-n}"
    
    if [[ "$confirm" =~ ^[Yy] ]]; then
        # Build and execute SCP command
        local scp_opts="-r -P $temp_port -o ConnectTimeout=$CONNECTION_TIMEOUT -o StrictHostKeyChecking=no"
        
        if [[ -n "$temp_ssh_key" ]]; then
            scp_opts="$scp_opts -i $temp_ssh_key"
        fi
        
        # Add verbose flag if DEBUG or VERBOSE is enabled
        if [[ "$VERBOSE" == true ]] || [[ "$DEBUG" == true ]]; then
            scp_opts="$scp_opts -v"
            debug_log "Verbose mode enabled for quick upload"
        fi
        
        local scp_command="scp $scp_opts '$local_source' '$temp_user@$temp_host:$remote_dest'"
        
        print_progress "Executing quick upload..."
        if [[ "$DEBUG" == true ]]; then
            print_color "PURPLE" "🐛 DEBUG: Executing command"
            print_color "CYAN" "$scp_command"
            echo
        fi
        
        eval "$scp_command"
        local exit_code=$?
        
        echo
        if [[ $exit_code -eq 0 ]]; then
            print_status "SUCCESS" "Quick upload completed successfully!"
            if [[ "$DEBUG" == true ]]; then
                debug_log "Quick upload successful with exit code: $exit_code"
            fi
        else
            print_status "ERROR" "Quick upload failed with exit code: $exit_code"
            if [[ "$DEBUG" == true ]]; then
                debug_log "Quick upload failed with exit code: $exit_code"
            fi
        fi
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
    
    echo -n "❯ Proceed with download? (y/N) [default: n]: "
    read confirm
    confirm="${confirm:-n}"
    
    if [[ "$confirm" =~ ^[Yy] ]]; then
        # Build and execute SCP command
        local scp_opts="-r -P $temp_port -o ConnectTimeout=$CONNECTION_TIMEOUT -o StrictHostKeyChecking=no"
        
        if [[ -n "$temp_ssh_key" ]]; then
            scp_opts="$scp_opts -i $temp_ssh_key"
        fi
        
        # Add verbose flag if DEBUG or VERBOSE is enabled
        if [[ "$VERBOSE" == true ]] || [[ "$DEBUG" == true ]]; then
            scp_opts="$scp_opts -v"
            debug_log "Verbose mode enabled for quick download"
        fi
        
        local scp_command="scp $scp_opts '$temp_user@$temp_host:$remote_source' '$local_dest'"
        
        print_progress "Executing quick download..."
        if [[ "$DEBUG" == true ]]; then
            print_color "PURPLE" "🐛 DEBUG: Executing command"
            print_color "CYAN" "$scp_command"
            echo
        fi
        
        eval "$scp_command"
        local exit_code=$?
        
        echo
        if [[ $exit_code -eq 0 ]]; then
            print_status "SUCCESS" "Quick download completed successfully!"
            if [[ "$DEBUG" == true ]]; then
                debug_log "Quick download successful with exit code: $exit_code"
            fi
        else
            print_status "ERROR" "Quick download failed with exit code: $exit_code"
            if [[ "$DEBUG" == true ]]; then
                debug_log "Quick download failed with exit code: $exit_code"
            fi
        fi
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
        
        if test_ssh_connection "$test_host" "$test_user" "$test_port" "$test_ssh_key"; then
            print_status "SUCCESS" "Connection test successful for '$test_name'!"
        else
            print_status "ERROR" "Connection test failed for '$test_name'"
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
