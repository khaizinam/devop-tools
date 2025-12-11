#!/bin/bash

# Script metadata
NAME="RSync File Sync"
DESC="Sync files between local and remote SSH servers using rsync"

# Source UI components
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../src/ui/ui_common.sh"
source "$SCRIPT_DIR/../src/ui/scroll_menu.sh"

# Configuration directory
CONFIG_DIR="./storage/ssh_config"
mkdir -p "$CONFIG_DIR"

# Check and install rsync and sshpass if not available
if ! command -v rsync &> /dev/null; then
    echo -e "${YELLOW}⚙️ rsync not found, installing...${RESET}"
    apt-get update && apt-get install -y rsync
fi

if ! command -v sshpass &> /dev/null; then
    echo -e "${YELLOW}⚙️ sshpass not found, installing...${RESET}"
    apt-get update && apt-get install -y sshpass
fi

# Global variables
SOURCE_TYPE=""  # "local" or "remote"
DEST_TYPE=""    # "local" or "remote"
SOURCE_CONFIG=""
DEST_CONFIG=""
SOURCE_PATH=""
DEST_PATH=""

# Global arrays
declare -a CONFIG_FILES
declare -a MENU_ITEMS

# Save terminal settings and setup Ctrl+C handling
TERM_SETTINGS=$(stty -g)

cleanup_terminal() {
    stty $TERM_SETTINGS 2>/dev/null || true
    echo -ne "\033[?25h"  # Show cursor
    echo ""
}

cleanup_and_exit() {
    cleanup_terminal
    echo ""
    echo -e "${BOLD}${YELLOW}⚠️  Interrupted by user${RESET}"
    exit 130
}

trap cleanup_terminal EXIT
trap cleanup_and_exit INT TERM

# Function to load config from file
load_config_from_file() {
    local config_file="$1"
    local -n USER_REF=$2
    local -n HOST_REF=$3
    local -n PORT_REF=$4
    local -n PASS_REF=$5
    
    USER_REF=""
    HOST_REF=""
    PORT_REF=""
    PASS_REF=""
    
    if [ -f "$config_file" ]; then
        while IFS='=' read -r key value; do
            [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)
            case "$key" in
                USER) USER_REF="$value" ;;
                HOST) HOST_REF="$value" ;;
                PORT) PORT_REF="$value" ;;
                PASS) PASS_REF="$value" ;;
            esac
        done < "$config_file"
    fi
}

# Function to build menu items with "This Local" option
load_ssh_configs_menu() {
    # Load configurations
    mapfile -t CONFIG_FILES < <(ls "$CONFIG_DIR"/*.conf 2>/dev/null)
    
    # Clear arrays
    MENU_ITEMS=()
    
    # Add "This Local" as first option
    MENU_ITEMS+=("This Local (Current Machine)")
    
    # Add SSH configs
    for file in "${CONFIG_FILES[@]}"; do
        fname=$(basename "$file" .conf)
        MENU_ITEMS+=("$fname")
    done
    
    # Add "Back" option
    MENU_ITEMS+=("Back")
}

# Function to select source/destination (A or B)
select_source_or_dest() {
    local title="$1"
    local selection_type="$2"  # "source" or "dest"
    
    load_ssh_configs_menu
    
    while true; do
        # Use scroll_menu to display and select
        scroll_menu_init "${MENU_ITEMS[@]}"
        scroll_menu_run "Select $title (${selection_type^^})"
        
        # Restore terminal after scroll_menu
        stty echo
        echo -ne "\033[?25h"
        clear
        
        # Check if cancelled
        if [ "$SCROLL_MENU_CANCELLED" -eq 1 ] || [ "$SCROLL_MENU_RESULT" -lt 0 ]; then
            return 1  # Cancelled
        fi
        
        # Get selected item from SCROLL_MENU_ITEMS (which was populated by scroll_menu_init)
        local selected_index=$SCROLL_MENU_RESULT
        if [ $selected_index -ge 0 ] && [ $selected_index -lt $SCROLL_MENU_TOTAL ]; then
            local selected_item="${SCROLL_MENU_ITEMS[$selected_index]}"
        else
            echo -e "${RED}❌ Invalid selection index: $selected_index${RESET}"
            read -p "Press Enter to continue..."
            continue
        fi
        
        # Check if Back was selected (last item)
        if [ "$selected_item" = "Back" ]; then
            return 1  # Cancelled
        fi
        
        if [ "$selected_item" = "This Local (Current Machine)" ]; then
            # This is local
            if [ "$selection_type" = "source" ]; then
                SOURCE_TYPE="local"
                SOURCE_CONFIG=""
            else
                DEST_TYPE="local"
                DEST_CONFIG=""
            fi
            echo -e "${BOLD}${CYAN}========================================${RESET}"
            echo -e "${BOLD}${CYAN}    Selection Confirmed    ${RESET}"
            echo -e "${BOLD}${CYAN}========================================${RESET}"
            echo ""
            echo -e "${GREEN}✅ Selected: This Local${RESET}"
            echo ""
            read -p "Press Enter to continue..."
            return 0
        else
            # Find matching config file
            local config_file=""
            for file in "${CONFIG_FILES[@]}"; do
                if [ "$(basename "$file" .conf)" = "$selected_item" ]; then
                    config_file="$file"
                    break
                fi
            done
            
            if [ -n "$config_file" ] && [ -f "$config_file" ]; then
                # This is remote
                if [ "$selection_type" = "source" ]; then
                    SOURCE_TYPE="remote"
                    SOURCE_CONFIG="$config_file"
                else
                    DEST_TYPE="remote"
                    DEST_CONFIG="$config_file"
                fi
                echo -e "${BOLD}${CYAN}========================================${RESET}"
                echo -e "${BOLD}${CYAN}    Selection Confirmed    ${RESET}"
                echo -e "${BOLD}${CYAN}========================================${RESET}"
                echo ""
                echo -e "${GREEN}✅ Selected: $selected_item${RESET}"
                echo ""
                read -p "Press Enter to continue..."
                return 0
            else
                echo -e "${BOLD}${RED}========================================${RESET}"
                echo -e "${BOLD}${RED}    Error    ${RESET}"
                echo -e "${BOLD}${RED}========================================${RESET}"
                echo ""
                echo -e "${RED}❌ Error: Configuration not found${RESET}"
                echo ""
                read -p "Press Enter to continue..."
                continue
            fi
        fi
    done
}

# Function to get folder path
# All display output goes to stderr, only the path is printed to stdout
get_folder_path() {
    local prompt_text="$1"
    local default_path="$2"
    local path=""
    
    while true; do
        clear >&2
        echo -e "${BOLD}${CYAN}========================================${RESET}" >&2
        echo -e "${BOLD}${CYAN}    Enter Folder Path    ${RESET}" >&2
        echo -e "${BOLD}${CYAN}========================================${RESET}" >&2
        echo "" >&2
        echo -e "${YELLOW}$prompt_text${RESET}" >&2
        if [ -n "$default_path" ]; then
            echo -e "${CYAN}Default: $default_path${RESET}" >&2
        fi
        echo "" >&2
        
        # Use read without -e to avoid issues with terminal control
        stty echo
        printf "Path: " >&2
        read path
        
        # Clean path from any control characters
        path=$(echo "$path" | tr -d '\r\n' | sed 's/\x1b\[[0-9;]*m//g' | sed 's/\x1b\[[0-9;]*[HJ]//g' | xargs)
        
        if [ -z "$path" ] && [ -n "$default_path" ]; then
            path="$default_path"
        fi
        
        if [ -n "$path" ]; then
            # Only print the path to stdout (for capture)
            echo "$path"
            return 0
        else
            echo -e "${RED}❌ Path cannot be empty${RESET}" >&2
            printf "Press Enter to continue..." >&2
            read >&2
        fi
    done
}

# Global variables for rsync execution
RSYNC_SSH_USER=""
RSYNC_SSH_HOST=""
RSYNC_SSH_PORT=""
RSYNC_SSH_PASS=""
RSYNC_FINAL_SOURCE=""
RSYNC_FINAL_DEST=""

# Function to build rsync command parts
prepare_rsync_components() {
    local source_path="$1"
    local dest_path="$2"
    
    # rsync doesn't support remote-to-remote directly
    # Validate: at least one must be local
    if [ "$SOURCE_TYPE" = "remote" ] && [ "$DEST_TYPE" = "remote" ]; then
        echo -e "${RED}❌ Error: Cannot sync directly between two remote servers${RESET}" >&2
        echo -e "${YELLOW}Please use local machine as intermediate${RESET}" >&2
        return 1
    fi
    
    # Reset variables
    RSYNC_SSH_USER=""
    RSYNC_SSH_HOST=""
    RSYNC_SSH_PORT=""
    RSYNC_SSH_PASS=""
    
    # Build source path
    if [ "$SOURCE_TYPE" = "remote" ] && [ -n "$SOURCE_CONFIG" ]; then
        # Remote source: pull from remote
        local USER="" HOST="" PORT="" PASS=""
        load_config_from_file "$SOURCE_CONFIG" USER HOST PORT PASS
        PORT=${PORT:-22}
        
        RSYNC_SSH_USER="$USER"
        RSYNC_SSH_HOST="$HOST"
        RSYNC_SSH_PORT="$PORT"
        RSYNC_SSH_PASS="$PASS"
        RSYNC_FINAL_SOURCE="$USER@$HOST:$source_path"
    else
        # Local source
        RSYNC_FINAL_SOURCE="$source_path"
        # Add trailing slash if local directory (rsync convention)
        if [ -d "$RSYNC_FINAL_SOURCE" ] && [[ "$RSYNC_FINAL_SOURCE" != */ ]]; then
            RSYNC_FINAL_SOURCE="$RSYNC_FINAL_SOURCE/"
        fi
    fi
    
    # Build destination path
    if [ "$DEST_TYPE" = "remote" ] && [ -n "$DEST_CONFIG" ]; then
        # Remote destination: push to remote
        if [ -z "$RSYNC_SSH_USER" ]; then
            # Only set SSH params if not already set (for source)
            local USER="" HOST="" PORT="" PASS=""
            load_config_from_file "$DEST_CONFIG" USER HOST PORT PASS
            PORT=${PORT:-22}
            
            RSYNC_SSH_USER="$USER"
            RSYNC_SSH_HOST="$HOST"
            RSYNC_SSH_PORT="$PORT"
            RSYNC_SSH_PASS="$PASS"
        fi
        # Use RSYNC_SSH_USER and RSYNC_SSH_HOST (may be set above or from source)
        RSYNC_FINAL_DEST="$RSYNC_SSH_USER@$RSYNC_SSH_HOST:$dest_path"
    else
        # Local destination
        RSYNC_FINAL_DEST="$dest_path"
    fi
    
    return 0
}

# Function to build display command (for showing to user)
build_display_command() {
    local cmd="rsync -avzP"
    
    if [ -n "$RSYNC_SSH_USER" ]; then
        cmd="$cmd -e \"sshpass -p '***' ssh -o StrictHostKeyChecking=no -p $RSYNC_SSH_PORT\""
    fi
    
    cmd="$cmd \"$RSYNC_FINAL_SOURCE\" \"$RSYNC_FINAL_DEST\""
    echo "$cmd"
}

# Function to display sync summary
display_sync_summary() {
    clear
    echo -e "${BOLD}${CYAN}========================================${RESET}"
    echo -e "${BOLD}${CYAN}    RSync Synchronization Summary    ${RESET}"
    echo -e "${BOLD}${CYAN}========================================${RESET}"
    echo ""
    echo -e "${BOLD}${WHITE}Source (A):${RESET}"
    if [ "$SOURCE_TYPE" = "local" ]; then
        echo -e "  ${GREEN}Type:${RESET} This Local"
        echo -e "  ${GREEN}Path:${RESET} ${CYAN}$SOURCE_PATH${RESET}"
    else
        local USER="" HOST="" PORT="" PASS=""
        load_config_from_file "$SOURCE_CONFIG" USER HOST PORT PASS
        echo -e "  ${GREEN}Type:${RESET} SSH Remote"
        echo -e "  ${GREEN}Config:${RESET} ${CYAN}$(basename "$SOURCE_CONFIG" .conf)${RESET}"
        echo -e "  ${GREEN}User:${RESET} ${CYAN}$USER@$HOST${RESET}"
        echo -e "  ${GREEN}Path:${RESET} ${CYAN}$SOURCE_PATH${RESET}"
    fi
    echo ""
    echo -e "${BOLD}${WHITE}Destination (B):${RESET}"
    if [ "$DEST_TYPE" = "local" ]; then
        echo -e "  ${GREEN}Type:${RESET} This Local"
        echo -e "  ${GREEN}Path:${RESET} ${CYAN}$DEST_PATH${RESET}"
    else
        local USER="" HOST="" PORT="" PASS=""
        load_config_from_file "$DEST_CONFIG" USER HOST PORT PASS
        echo -e "  ${GREEN}Type:${RESET} SSH Remote"
        echo -e "  ${GREEN}Config:${RESET} ${CYAN}$(basename "$DEST_CONFIG" .conf)${RESET}"
        echo -e "  ${GREEN}User:${RESET} ${CYAN}$USER@$HOST${RESET}"
        echo -e "  ${GREEN}Path:${RESET} ${CYAN}$DEST_PATH${RESET}"
    fi
    echo ""
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    read -p "Confirm and start sync? (Y/N): " confirm
    echo ""
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to execute rsync
execute_rsync() {
    local source_path="$1"
    local dest_path="$2"
    
    # Clean paths (remove any ANSI escape codes that might have leaked)
    source_path=$(echo "$source_path" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/\x1b\[[0-9;]*[HJ]//g' | xargs)
    dest_path=$(echo "$dest_path" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/\x1b\[[0-9;]*[HJ]//g' | xargs)
    
    # Prepare rsync components
    if ! prepare_rsync_components "$source_path" "$dest_path"; then
        echo -e "${BOLD}${RED}❌ Failed to prepare rsync command${RESET}"
        echo ""
        read -p "Press Enter to continue..."
        return 1
    fi
    
    clear
    echo -e "${BOLD}${CYAN}========================================${RESET}"
    echo -e "${BOLD}${CYAN}    RSync Synchronization Progress    ${RESET}"
    echo -e "${BOLD}${CYAN}========================================${RESET}"
    echo ""
    
    # Display command (with masked password)
    local display_cmd=$(build_display_command)
    echo -e "${BOLD}${WHITE}Command:${RESET} ${CYAN}$display_cmd${RESET}"
    echo ""
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    
    # Execute rsync using environment variable for password (more secure)
    if [ -n "$RSYNC_SSH_USER" ]; then
        # Remote sync - use sshpass with environment variable
        export SSHPASS="$RSYNC_SSH_PASS"
        rsync -avzP -e "sshpass -e ssh -o StrictHostKeyChecking=no -p $RSYNC_SSH_PORT" "$RSYNC_FINAL_SOURCE" "$RSYNC_FINAL_DEST"
        local exit_code=$?
        unset SSHPASS
    else
        # Local sync
        rsync -avzP "$RSYNC_FINAL_SOURCE" "$RSYNC_FINAL_DEST"
        local exit_code=$?
    fi
    
    echo ""
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${BOLD}${GREEN}✅ Synchronization completed successfully!${RESET}"
    else
        echo -e "${BOLD}${RED}❌ Synchronization failed (Exit code: $exit_code)${RESET}"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Main function
main() {
    while true; do
        # Reset selections
        SOURCE_TYPE=""
        DEST_TYPE=""
        SOURCE_CONFIG=""
        DEST_CONFIG=""
        SOURCE_PATH=""
        DEST_PATH=""
        
        # Step 1: Select Source (A)
        clear
        echo -e "${BOLD}${CYAN}========================================${RESET}"
        echo -e "${BOLD}${CYAN}    RSync File Synchronization    ${RESET}"
        echo -e "${BOLD}${CYAN}========================================${RESET}"
        echo ""
        echo -e "${YELLOW}Step 1: Select Source (A)${RESET}"
        echo ""
        
        if ! select_source_or_dest "Source" "source"; then
            # User cancelled or selected Back
            cleanup_terminal
            exit 0
        fi
        
        # Step 2: Select Destination (B)
        clear
        echo -e "${BOLD}${CYAN}========================================${RESET}"
        echo -e "${BOLD}${CYAN}    RSync File Synchronization    ${RESET}"
        echo -e "${BOLD}${CYAN}========================================${RESET}"
        echo ""
        echo -e "${GREEN}✅ Source (A): $([ "$SOURCE_TYPE" = "local" ] && echo "This Local" || echo "$(basename "$SOURCE_CONFIG" .conf)")${RESET}"
        echo ""
        echo -e "${YELLOW}Step 2: Select Destination (B)${RESET}"
        if [ "$SOURCE_TYPE" = "remote" ]; then
            echo -e "${YELLOW}Note: Source is remote, destination must be local${RESET}"
        fi
        echo ""
        
        if ! select_source_or_dest "Destination" "dest"; then
            # User cancelled or selected Back - go back to step 1
            continue
        fi
        
        # Validate: cannot sync remote to remote
        if [ "$SOURCE_TYPE" = "remote" ] && [ "$DEST_TYPE" = "remote" ]; then
            clear
            echo -e "${BOLD}${RED}========================================${RESET}"
            echo -e "${BOLD}${RED}    Error: Invalid Configuration    ${RESET}"
            echo -e "${BOLD}${RED}========================================${RESET}"
            echo ""
            echo -e "${YELLOW}❌ Cannot sync directly between two remote servers${RESET}"
            echo -e "${YELLOW}At least one endpoint must be 'This Local'${RESET}"
            echo ""
            read -p "Press Enter to continue..."
            continue
        fi
        
        # Step 3: Get source path
        SOURCE_PATH=$(get_folder_path "Enter source folder path (A):")
        if [ -z "$SOURCE_PATH" ]; then
            continue
        fi
        
        # Step 4: Get destination path
        DEST_PATH=$(get_folder_path "Enter destination folder path (B):")
        if [ -z "$DEST_PATH" ]; then
            continue
        fi
        
        # Step 5: Display summary and confirm
        if display_sync_summary; then
            # Step 6: Execute rsync
            execute_rsync "$SOURCE_PATH" "$DEST_PATH"
        fi
        
        # After sync, ask if user wants to do another sync
        clear
        echo -e "${BOLD}${CYAN}========================================${RESET}"
        echo -e "${BOLD}${CYAN}    RSync Synchronization Complete    ${RESET}"
        echo -e "${BOLD}${CYAN}========================================${RESET}"
        echo ""
        read -p "Do you want to sync again? (Y/N): " sync_again
        if [[ ! "$sync_again" =~ ^[Yy]$ ]]; then
            cleanup_terminal
            exit 0
        fi
    done
}

# Run main function
main

