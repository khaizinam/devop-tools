#!/bin/bash

# Source UI core (read_key, cleanup, colors) and page menu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/src/ui/ui_common.sh"
source "$SCRIPT_DIR/src/ui/page_menu.sh"

# Pagination page size
PAGE_SIZE=8

# Welcome banner
clear
echo -e "${BOLD}${CYAN}========================================${RESET}"
echo -e "${BOLD}${CYAN}    Welcome to Khaizinam's Script Manager    ${RESET}"
echo -e "${BOLD}${CYAN}========================================${RESET}"
echo ""

# Kiểm tra quyền root/sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}❌ This script requires root privileges. Please run with sudo:${RESET}"
  echo -e "${YELLOW}   sudo bash app_ui.sh${RESET}"
  exit 1
fi

# Check and install nano if not available
if ! command -v nano &> /dev/null; then
  echo -e "${BOLD}${YELLOW}⚠️  nano not found, installing...${RESET}"
  if command -v apt-get &> /dev/null; then
    apt-get update -qq && apt-get install -y nano
  elif command -v yum &> /dev/null; then
    yum install -y nano
  elif command -v dnf &> /dev/null; then
    dnf install -y nano
  elif command -v pacman &> /dev/null; then
    pacman -S --noconfirm nano
  else
    echo -e "${RED}❌ Cannot install nano: package manager not found${RESET}"
    echo -e "${YELLOW}⚠️  Some scripts may require nano editor${RESET}"
  fi
  echo ""
fi

echo -e "${BOLD}${GREEN}🚀 Efficient system administration made easy!${RESET}"
echo -e "${BOLD}${YELLOW}📋 Choose from the available scripts below:${RESET}"
echo ""

# Traps already defined in ui_common.sh (cleanup_terminal, cleanup_and_exit)

# Function to read NAME and DESC variables from script file
read_script_metadata() {
  local script_file="$1"
  local metadata_type="$2"  # "NAME" or "DESC"
  
  if [ ! -f "$script_file" ]; then
    return 1
  fi
  
  # Extract variable value using grep and sed
  # Looks for: NAME="value" or NAME='value' or NAME=value
  local value=$(grep -m 1 "^${metadata_type}=" "$script_file" 2>/dev/null | sed "s/^${metadata_type}=//" | sed 's/^["'\'']//' | sed 's/["'\'']$//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
  
  if [ -n "$value" ]; then
    echo "$value"
  else
    return 1
  fi
}

# Function to get script display name
get_script_name() {
  local script_file="$1"
  local name=$(read_script_metadata "$script_file" "NAME")
  
  if [ -n "$name" ]; then
    echo "$name"
  else
    # Fallback to filename without extension
    basename "$script_file" .sh
  fi
}

# Function to get script description
get_script_description() {
  local script_file="$1"
  local desc=$(read_script_metadata "$script_file" "DESC")
  
  if [ -n "$desc" ]; then
    # Return full description without truncation
    echo "$desc"
  else
    # Return empty if no DESC variable found
    echo ""
  fi
}

# Main loop function
main_loop() {
  FILES_PATH=$(ls run/*.sh 2>/dev/null)
  if [ -z "$FILES_PATH" ]; then
    echo -e "${RED}❌ No scripts found in run/ directory!${RESET}"
    exit 1
  fi
  
  INDEX=0
  declare -a FILES
  declare -a SCRIPT_NAMES
  declare -a SCRIPT_DESCS
  declare -a MENU_ITEMS
  
  # Populate FILES array and cache metadata (only once)
  for EACH_FILE in $FILES_PATH; do
    FILES+=("$EACH_FILE")
    SCRIPT_NAMES+=("$(get_script_name "$EACH_FILE")")
    SCRIPT_DESCS+=("$(get_script_description "$EACH_FILE")")
    ((INDEX++))
  done
  
  # Build menu items + descs: index 0 = Exit, then scripts
  MENU_ITEMS=()
  MENU_DESCS=()
  MENU_ITEMS+=("Exit")
  MENU_DESCS+=("Quit the manager")
  for ((i=0; i<${#SCRIPT_NAMES[@]}; i++)); do
    label="${SCRIPT_NAMES[$i]}"
    desc="${SCRIPT_DESCS[$i]}"
    MENU_ITEMS+=("$label")
    MENU_DESCS+=("$desc")
  done

  # Run paginated menu
  page_menu_set_page_size "$PAGE_SIZE"
  page_menu_set_data MENU_ITEMS MENU_DESCS
  page_menu_run "Script Manager"

  # Handle cancel/exit
  if [ "$PAGE_MENU_CANCELLED" -eq 1 ] || [ "$PAGE_MENU_RESULT" -lt 0 ]; then
    echo -e "${BOLD}${GREEN}👋 Thank you for using Khaizinam's Script Manager!${RESET}"
    exit 0
  fi

  selected=$PAGE_MENU_RESULT

  # Exit option index 0
  if [ $selected -eq 0 ]; then
    echo -e "${BOLD}${GREEN}👋 Thank you for using Khaizinam's Script Manager!${RESET}"
    echo -e "${CYAN}Goodbye! 👋${RESET}"
    exit 0
  fi

  # Get selected file (offset by 1 due to Exit)
  SELECTED_FILE=${FILES[$((selected-1))]}
  SELECTED_NAME=$(basename "$SELECTED_FILE")
  
  echo ""
  echo -e "${BOLD}${CYAN}========================================${RESET}"
  echo -e "${BOLD}${GREEN}🚀 Executing: $SELECTED_NAME${RESET}"
  echo -e "${BOLD}${CYAN}========================================${RESET}"
  echo ""
  
  # Run the selected script
  bash "$SELECTED_FILE"
  
  # Clear screen and restart the loop
  clear
  echo -e "${BOLD}${CYAN}========================================${RESET}"
  echo -e "${BOLD}${CYAN}    Welcome back to Script Manager    ${RESET}"
  echo -e "${BOLD}${CYAN}========================================${RESET}"
  echo ""
}

# Start the main loop
while true; do
  main_loop
done
