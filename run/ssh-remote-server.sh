#!/bin/bash

# Script metadata
NAME="SSH Remote Connection"
DESC="Connect to remote server via SSH with saved configurations"

# Source UI components
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../src/ui/ui_common.sh"
source "$SCRIPT_DIR/../src/ui/page_menu.sh"

# Thư mục cấu hình SSH
CONFIG_DIR="./storage/ssh_config"
mkdir -p "$CONFIG_DIR"

# Function to display action menu for selected config
display_config_action_menu() {
  local config_file="$1"
  local selected_action=0  # 0=Connect, 1=Edit, 2=Delete, 3=Back
  
  # Load config
  local USER=""
  local HOST=""
  local PORT=""
  local PASS=""
  
  if [ -f "$config_file" ]; then
  while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)
    case "$key" in
      USER) USER="$value" ;;
      HOST) HOST="$value" ;;
      PORT) PORT="$value" ;;
      PASS) PASS="$value" ;;
    esac
    done < "$config_file"
  fi
  
  local config_name=$(basename "$config_file" .conf)
  
  # Action menu loop
  while true; do
    clear
    echo -e "${BOLD}${CYAN}========================================${RESET}"
    echo -e "${BOLD}${CYAN}    Configuration: ${GREEN}$config_name${CYAN}    ${RESET}"
    echo -e "${BOLD}${CYAN}========================================${RESET}"
    echo ""
    echo -e "${BOLD}${WHITE}Connection Details:${RESET}"
    echo -e "  ${YELLOW}Username:${RESET} ${GREEN}$USER${RESET}"
    echo -e "  ${YELLOW}Host:${RESET}     ${GREEN}$HOST${RESET}"
    echo -e "  ${YELLOW}Port:${RESET}     ${GREEN}${PORT:-22}${RESET}"
    echo -e "  ${YELLOW}Password:${RESET} ${GREEN}$(echo "$PASS" | sed 's/./*/g' | head -c ${#PASS})${RESET} (${#PASS} characters)"
    echo ""
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e "${BOLD}${WHITE}Select an action:${RESET}"
    echo ""
    
    # Display options with highlighting
    if [ $selected_action -eq 0 ]; then
      echo -e "${BOLD}${BG_GREEN}${WHITE}▶ [1] Connect${RESET}"
    else
      echo -e "${GREEN}  [1] Connect${RESET}"
    fi
    
    if [ $selected_action -eq 1 ]; then
      echo -e "${BOLD}${BG_YELLOW}${BLUE}▶ [2] Edit${RESET}"
    else
      echo -e "${YELLOW}  [2] Edit${RESET}"
    fi
    
    if [ $selected_action -eq 2 ]; then
      echo -e "${BOLD}${BG_RED}${WHITE}▶ [3] Delete${RESET}"
    else
      echo -e "${RED}  [3] Delete${RESET}"
    fi
    
    if [ $selected_action -eq 3 ]; then
      echo -e "${BOLD}${BG_BLUE}${WHITE}▶ [4] Back to Menu${RESET}"
    else
      echo -e "${BLUE}  [4] Back to Menu${RESET}"
    fi
    
    echo ""
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}${WHITE}Controls: ${CYAN}↑↓${WHITE} Navigate | ${CYAN}Enter${WHITE} Select | ${CYAN}1-4${WHITE} Quick Select | ${CYAN}ESC${WHITE} Back${RESET}"
    
    # Wait for user input
    key=$(read_key)
    case "$key" in
      "UP")
        if [ $selected_action -gt 0 ]; then
          ((selected_action--))
        else
          selected_action=3
        fi
        ;;
      "DOWN")
        if [ $selected_action -lt 3 ]; then
          ((selected_action++))
        else
          selected_action=0
        fi
        ;;
      "ENTER")
        case $selected_action in
          0) return 0 ;;  # Connect
          1) return 1 ;;  # Edit
          2) return 2 ;;  # Delete
          3) return 3 ;;  # Back
        esac
        ;;
      "1")
        return 0  # Connect
        ;;
      "2")
        return 1  # Edit
        ;;
      "3")
        return 2  # Delete
        ;;
      "4")
        return 3  # Back
        ;;
      "ESC"|"BACKSPACE")
        return 3  # Back
        ;;
      *)
        ;;
    esac
  done
}

# Function to edit config file
edit_config_file() {
  local config_file="$1"
  
  # Check if editor is available (prefer nano, fallback to vi)
  local editor=""
  if command -v nano &> /dev/null; then
    editor="nano"
  elif command -v vi &> /dev/null; then
    editor="vi"
  else
    echo -e "${BOLD}${RED}❌ No text editor found (nano or vi)${RESET}"
    read -p "Press Enter to continue..."
    return 1
  fi
  
  clear
  echo -e "${BOLD}${CYAN}Editing configuration file...${RESET}"
  echo -e "${YELLOW}Using editor: $editor${RESET}"
  echo ""
  echo -e "${BOLD}${WHITE}Press ${CYAN}Ctrl+X${WHITE} then ${CYAN}Y${WHITE} and ${CYAN}Enter${WHITE} to save in nano${RESET}"
  echo -e "${BOLD}${WHITE}Press ${CYAN}:wq${WHITE} and ${CYAN}Enter${WHITE} to save in vi${RESET}"
  echo ""
  read -p "Press Enter to open editor..."
  
  # Open editor
  $editor "$config_file"
  local edit_exit=$?
  
  if [ $edit_exit -eq 0 ]; then
    echo ""
    echo -e "${BOLD}${GREEN}✅ Configuration saved successfully!${RESET}"
    read -p "Press Enter to continue..."
    return 0
  else
    echo ""
    echo -e "${BOLD}${YELLOW}⚠️  Configuration was not saved${RESET}"
    read -p "Press Enter to continue..."
    return 1
  fi
}

# Function to delete config file
delete_config_file() {
  local config_file="$1"
  local config_name=$(basename "$config_file" .conf)
  
  clear
  echo -e "${BOLD}${RED}========================================${RESET}"
  echo -e "${BOLD}${RED}    Delete Configuration    ${RESET}"
  echo -e "${BOLD}${RED}========================================${RESET}"
  echo ""
  echo -e "${BOLD}${YELLOW}⚠️  WARNING: This action cannot be undone!${RESET}"
  echo ""
  echo -e "${BOLD}${WHITE}Configuration to delete: ${RED}$config_name${RESET}"
  echo -e "${BOLD}${WHITE}File: ${CYAN}$config_file${RESET}"
  echo ""
  echo -e "${BOLD}${WHITE}Are you sure you want to delete this configuration?${RESET}"
  echo ""
  echo -e "${BOLD}${GREEN}[Y]${RESET} Yes, delete it"
  echo -e "${BOLD}${RED}[N]${RESET} No, cancel"
  echo ""
  
  while true; do
    key=$(read_key)
    case "$key" in
      "y"|"Y")
        if rm -f "$config_file"; then
          echo ""
          echo -e "${BOLD}${GREEN}✅ Configuration deleted successfully!${RESET}"
          read -p "Press Enter to continue..."
          return 0
        else
          echo ""
          echo -e "${BOLD}${RED}❌ Failed to delete configuration!${RESET}"
          read -p "Press Enter to continue..."
          return 1
        fi
        ;;
      "n"|"N"|"ESC"|"BACKSPACE")
        echo ""
        echo -e "${BOLD}${CYAN}Deletion cancelled.${RESET}"
        read -p "Press Enter to continue..."
        return 1
        ;;
      *)
        ;;
    esac
  done
}

# Đảm bảo sshpass đã được cài
if ! command -v sshpass &> /dev/null; then
  echo -e "${YELLOW}⚙️ sshpass not found, installing...${RESET}"
  apt-get update && apt-get install -y sshpass
fi

# Global arrays for menu items
declare -a CONFIG_FILES
declare -a CONFIG_NAMES
declare -a MENU_ITEMS
declare -a MENU_DESCS

# Function to load and build menu items (with desc placeholders)
load_menu_items() {
  # Load configurations
  mapfile -t CONFIG_FILES < <(ls "$CONFIG_DIR"/*.conf 2>/dev/null)
  
  # Clear arrays before building
  CONFIG_NAMES=()
  MENU_ITEMS=()
  MENU_DESCS=()
  
  # Add Back to Menu as first item (index 0)
  MENU_ITEMS+=("Back to Menu")
  MENU_DESCS+=("")
  
  # Build menu items array (configs start from index 1)
  for file in "${CONFIG_FILES[@]}"; do
    fname=$(basename "$file")
    CONFIG_NAMES+=("${fname%.conf}")
    MENU_ITEMS+=("${fname%.conf}")
    MENU_DESCS+=("")  # description placeholder
  done
  
  # Add special options
  MENU_ITEMS+=("New Configuration")
  MENU_DESCS+=("")
}

# Function to handle quit action
handle_quit() {
  clear
  echo -e "${BOLD}${GREEN}👋 Returning to main menu...${RESET}"
  exit 0
}

# Function to create new configuration
handle_new_configuration() {
  clear
  echo -e "${BOLD}${CYAN}Creating new configuration...${RESET}"
  echo ""
  read -p "User: " USER
  read -p "Host (IP or domain): " HOST
  read -p "Port [22]: " PORT
  PORT=${PORT:-22}
  read -sp "Password: " PASS
  echo ""
  
  read -p "Config filename (without .conf, default: ${USER}-${HOST}): " CONFIG_NAME
  CONFIG_NAME=${CONFIG_NAME:-"${USER}-${HOST}"}
  
  CONFIG_FILE="$CONFIG_DIR/${CONFIG_NAME}.conf"
  cat > "$CONFIG_FILE" <<EOF
USER=$USER
HOST=$HOST
PORT=$PORT
PASS=$PASS
EOF
  echo -e "${BOLD}${GREEN}✅ Saved new config to $(basename "$CONFIG_FILE")${RESET}"
  echo ""
  read -p "Press Enter to continue..."
}

# Function to load config from file
load_config_from_file() {
  local config_file="$1"
  USER=""
  HOST=""
  PORT=""
  PASS=""
  
  while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)
    case "$key" in
      USER) USER="$value" ;;
      HOST) HOST="$value" ;;
      PORT) PORT="$value" ;;
      PASS) PASS="$value" ;;
    esac
  done < "$config_file"
}

# Function to handle SSH connection
handle_connect() {
  local config_file="$1"
  
  # Load config
  load_config_from_file "$config_file"
  
  # Clear screen before connecting
  clear
  
  echo ""
  echo -e "${BOLD}${CYAN}🔌 Connecting to ${GREEN}$USER@$HOST${CYAN} on port ${GREEN}${PORT:-22}${CYAN}...${RESET}"
  echo ""
  
  # Connect
  sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -p "${PORT:-22}" "$USER@$HOST"
  
  # After disconnection
  echo ""
  echo -e "${BOLD}${YELLOW}Connection closed.${RESET}"
  read -p "Press Enter to return to menu..."
}

# Function to handle configuration action menu
handle_config_action() {
  local selected_file="$1"
  
  # Validate that file exists
  if [ ! -f "$selected_file" ]; then
    echo -e "${BOLD}${RED}❌ Error: Configuration file not found!${RESET}"
    read -p "Press Enter to continue..."
    return 1
  fi
  
  # Show action menu
  display_config_action_menu "$selected_file"
  local action=$?
  
  case $action in
    0)
      # Connect selected
      handle_connect "$selected_file"
      ;;
    1)
      # Edit selected
      if edit_config_file "$selected_file"; then
        # Config was edited successfully
        return 0
      fi
      ;;
    2)
      # Delete selected
      if delete_config_file "$selected_file"; then
        # Config was deleted
        return 0
      fi
      ;;
    3)
      # Back selected - do nothing, just return to reload menu
      return 0
      ;;
  esac
  
  return 0
}

# Function to handle configuration selection
handle_config_selection() {
  local selected=$1
  local config_count=$2
  
  # configs start at index 1
  if [ $selected -ge 1 ] && [ $selected -le $config_count ]; then
    local idx=$((selected-1))
    local selected_file="${CONFIG_FILES[$idx]}"
    handle_config_action "$selected_file"
    return 0
  else
    # Invalid selection
    echo -e "${BOLD}${RED}❌ Invalid selection: $selected${RESET}"
    echo -e "${YELLOW}Please try again.${RESET}"
    read -p "Press Enter to continue..."
    return 1
  fi
}

# Function to run main menu
run_main_menu() {
  # Load and build menu items
  load_menu_items
  
  # Run paginated menu (page size 10)
  page_menu_set_page_size 10
  page_menu_set_data MENU_ITEMS MENU_DESCS
  page_menu_run "SSH Remote Connection Manager"
  local selected=$PAGE_MENU_RESULT
  
  # Check if user cancelled
  if [ "${PAGE_MENU_CANCELLED:-0}" -eq 1 ] || [ $selected -lt 0 ]; then
    handle_quit
  fi
  
  # Calculate indices
  local config_count=${#CONFIG_NAMES[@]}
  local back_idx=0
  local new_idx=$((config_count + 1))
  
  # Handle selection
  if [ $selected -eq $back_idx ]; then
    handle_quit
  elif [ $selected -eq $new_idx ]; then
    # New configuration selected
    handle_new_configuration
  else
    # Configuration selected
    handle_config_selection $selected $config_count
  fi
}

# Main menu loop
while true; do
  run_main_menu
done
