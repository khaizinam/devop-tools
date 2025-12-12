#!/bin/bash
# Scroll Menu Component - Menu with scroll support (max 50 visible items)

# Source common UI functions
if [ -z "$UI_COMMON_LOADED" ]; then
  source "$(dirname "${BASH_SOURCE[0]}")/ui_common.sh"
  UI_COMMON_LOADED=1
fi

# Scroll Menu Configuration
MAX_VISIBLE_ITEMS=50
MENU_START_ROW=6
MENU_ITEM_HEIGHT=1

# Global variables for scroll menu
declare -a SCROLL_MENU_ITEMS
declare -a SCROLL_MENU_DESCRIPTIONS
SCROLL_MENU_SELECTED=0
SCROLL_MENU_OFFSET=0
SCROLL_MENU_TOTAL=0
SCROLL_MENU_VISIBLE_COUNT=0
SCROLL_MENU_RESULT=-1
SCROLL_MENU_CANCELLED=0
SCROLL_MENU_INPUT_BUFFER=""

# Function to initialize scroll menu
scroll_menu_init() {
  local items=("$@")
  # Clear existing arrays and reset state
  SCROLL_MENU_ITEMS=()
  SCROLL_MENU_DESCRIPTIONS=()
  SCROLL_MENU_ITEMS=("${items[@]}")
  SCROLL_MENU_TOTAL=${#SCROLL_MENU_ITEMS[@]}
  SCROLL_MENU_SELECTED=0
  SCROLL_MENU_OFFSET=0
  SCROLL_MENU_RESULT=-1
  SCROLL_MENU_CANCELLED=0
  SCROLL_MENU_INPUT_BUFFER=""
  
  # Calculate visible count (max 50 items, but not more than total)
  if [ $SCROLL_MENU_TOTAL -lt $MAX_VISIBLE_ITEMS ]; then
    SCROLL_MENU_VISIBLE_COUNT=$SCROLL_MENU_TOTAL
  else
    SCROLL_MENU_VISIBLE_COUNT=$MAX_VISIBLE_ITEMS
  fi
  
  # Ensure visible count doesn't exceed total
  if [ $SCROLL_MENU_VISIBLE_COUNT -gt $SCROLL_MENU_TOTAL ]; then
    SCROLL_MENU_VISIBLE_COUNT=$SCROLL_MENU_TOTAL
  fi
}

# Function to calculate scroll offset
calculate_scroll_offset() {
  local selected=$1
  local visible=$2
  
  # If selected item is above visible area, scroll up
  if [ $selected -lt $SCROLL_MENU_OFFSET ]; then
    SCROLL_MENU_OFFSET=$selected
  fi
  
  # If selected item is below visible area, scroll down
  local last_visible=$(($SCROLL_MENU_OFFSET + $visible - 1))
  if [ $selected -gt $last_visible ]; then
    SCROLL_MENU_OFFSET=$(($selected - $visible + 1))
  fi
  
  # Ensure offset doesn't go negative or beyond total
  if [ $SCROLL_MENU_OFFSET -lt 0 ]; then
    SCROLL_MENU_OFFSET=0
  fi
  
  local max_offset=$(($SCROLL_MENU_TOTAL - $visible))
  if [ $max_offset -lt 0 ]; then
    max_offset=0
  fi
  if [ $SCROLL_MENU_OFFSET -gt $max_offset ]; then
    SCROLL_MENU_OFFSET=$max_offset
  fi
}

# Function to render a single menu item
render_scroll_item() {
  local idx=$1
  local name=$2
  local is_selected=$3
  local display_idx=$4
  local is_even=$5
  
  # Always clear the line first, then render
  echo -ne "${CLEAR_LINE}"
  
  if [ $is_selected -eq 1 ]; then
    if [ $is_even -eq 1 ]; then
      echo -e "${BOLD}${BG_GREEN}${WHITE}▶ [$idx] $name${RESET}"
    else
      echo -e "${BOLD}${BG_YELLOW}${BLUE}▶ [$idx] $name${RESET}"
    fi
  else
    if [ $is_even -eq 1 ]; then
      echo -e "${GREEN}  [$idx] $name${RESET}"
    else
      echo -e "${YELLOW}  [$idx] $name${RESET}"
    fi
  fi
}

# Function to render scroll menu (full render)
scroll_menu_render() {
  local selected=$1
  local header_text="${2:-Menu}"
  
  clear
  echo -ne "${HIDE_CURSOR}"
  echo -e "${BOLD}${CYAN}========================================${RESET}"
  echo -e "${BOLD}${CYAN}    $header_text    ${RESET}"
  echo -e "${BOLD}${CYAN}========================================${RESET}"
  echo ""
  
  # Calculate scroll offset
  calculate_scroll_offset $selected $SCROLL_MENU_VISIBLE_COUNT
  
  # Display scroll indicator if needed
  if [ $SCROLL_MENU_TOTAL -gt $SCROLL_MENU_VISIBLE_COUNT ]; then
    local scroll_percent=$((($SCROLL_MENU_OFFSET * 100) / ($SCROLL_MENU_TOTAL - $SCROLL_MENU_VISIBLE_COUNT + 1)))
    echo -e "${BOLD}${BLUE}📜 Showing ${CYAN}$(($SCROLL_MENU_OFFSET + 1))${BLUE}-${CYAN}$(($SCROLL_MENU_OFFSET + $SCROLL_MENU_VISIBLE_COUNT))${BLUE} of ${CYAN}$SCROLL_MENU_TOTAL${BLUE} items${RESET}"
  else
    echo -e "${BOLD}${BLUE}📋 ${CYAN}$SCROLL_MENU_TOTAL${BLUE} items${RESET}"
  fi
  echo ""
  
  MENU_START_ROW=6
  
  # Render visible items (ensure we don't render more than total items)
  local items_to_render=$SCROLL_MENU_VISIBLE_COUNT
  if [ $items_to_render -gt $SCROLL_MENU_TOTAL ]; then
    items_to_render=$SCROLL_MENU_TOTAL
  fi
  
  # Render visible items (clear is already done by 'clear' command above)
  for ((i=0; i<$items_to_render; i++)); do
    local actual_idx=$(($SCROLL_MENU_OFFSET + $i))
    
    # Only render if within bounds
    if [ $actual_idx -ge 0 ] && [ $actual_idx -lt $SCROLL_MENU_TOTAL ]; then
      local is_selected=0
      if [ $actual_idx -eq $selected ]; then
        is_selected=1
      fi
      
      local is_even=$((actual_idx % 2 == 0 ? 1 : 0))
      local row=$(($MENU_START_ROW + $i))
      move_cursor $row 1
      render_scroll_item $actual_idx "${SCROLL_MENU_ITEMS[$actual_idx]}" $is_selected $i $is_even
    fi
  done
  
  echo ""
  echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  
  # Show scroll instructions if needed
  if [ $SCROLL_MENU_TOTAL -gt $SCROLL_MENU_VISIBLE_COUNT ]; then
    echo -e "${BOLD}${WHITE}Controls: ${CYAN}↑↓${WHITE} Navigate | ${CYAN}Enter${WHITE} Select | ${CYAN}Type number${WHITE} Jump | ${CYAN}q${WHITE} Quit${RESET}"
  else
    echo -e "${BOLD}${WHITE}Controls: ${CYAN}↑↓${WHITE} Navigate | ${CYAN}Enter${WHITE} Select | ${CYAN}Type number${WHITE} Jump | ${CYAN}q${WHITE} Quit${RESET}"
  fi
  
  # Show input buffer if typing number
  if [ -n "$SCROLL_MENU_INPUT_BUFFER" ]; then
    echo -e "${BOLD}${CYAN}Input: ${GREEN}$SCROLL_MENU_INPUT_BUFFER${RESET}"
  fi
}

# Function to update scroll menu (optimized - only redraw visible area)
scroll_menu_update() {
  local prev_selected=$1
  local new_selected=$2
  
  # Save old offset
  local old_offset=$SCROLL_MENU_OFFSET
  
  # Calculate new scroll offset
  calculate_scroll_offset $new_selected $SCROLL_MENU_VISIBLE_COUNT
  
  if [ $old_offset -ne $SCROLL_MENU_OFFSET ]; then
    # Scroll changed - redraw entire visible area
    local items_to_render=$SCROLL_MENU_VISIBLE_COUNT
    if [ $items_to_render -gt $SCROLL_MENU_TOTAL ]; then
      items_to_render=$SCROLL_MENU_TOTAL
    fi
    
    # Calculate how many rows we need to clear (max of old and new visible ranges)
    local old_last_row=$(($MENU_START_ROW + $items_to_render - 1))
    local new_last_row=$(($MENU_START_ROW + $items_to_render - 1))
    local max_row=$((old_last_row > new_last_row ? old_last_row : new_last_row))
    
    # Clear all potentially affected menu lines
    for ((row=$MENU_START_ROW; row<=$max_row; row++)); do
      move_cursor $row 1
      clear_line
    done
    
    # Redraw all visible items with new offset
    for ((i=0; i<$items_to_render; i++)); do
      local actual_idx=$(($SCROLL_MENU_OFFSET + $i))
      
      if [ $actual_idx -ge 0 ] && [ $actual_idx -lt $SCROLL_MENU_TOTAL ]; then
        local is_selected=0
        if [ $actual_idx -eq $new_selected ]; then
          is_selected=1
        fi
        local is_even=$((actual_idx % 2 == 0 ? 1 : 0))
        move_cursor $(($MENU_START_ROW + $i)) 1
        render_scroll_item $actual_idx "${SCROLL_MENU_ITEMS[$actual_idx]}" $is_selected $i $is_even
      else
        # Clear if we've exceeded bounds
        move_cursor $(($MENU_START_ROW + $i)) 1
        clear_line
      fi
    done
  else
    # No scroll change - just update selected items
    # First, find display indices based on CURRENT offset
    local prev_display_idx=-1
    local new_display_idx=-1
    
    # Calculate using the current offset (after calculate_scroll_offset)
    for ((i=0; i<$SCROLL_MENU_VISIBLE_COUNT; i++)); do
      local actual_idx=$(($SCROLL_MENU_OFFSET + $i))
      # Only check items that are actually visible
      if [ $actual_idx -ge 0 ] && [ $actual_idx -lt $SCROLL_MENU_TOTAL ]; then
        if [ $actual_idx -eq $prev_selected ]; then
          prev_display_idx=$i
        fi
        if [ $actual_idx -eq $new_selected ]; then
          new_display_idx=$i
        fi
      fi
    done
    
    # Update previous selection (only if it was visible)
    if [ $prev_display_idx -ge 0 ] && [ $prev_selected -ge 0 ] && [ $prev_selected -lt $SCROLL_MENU_TOTAL ]; then
      local row=$(($MENU_START_ROW + $prev_display_idx))
      move_cursor $row 1
      local is_even=$(($prev_selected % 2 == 0 ? 1 : 0))
      render_scroll_item $prev_selected "${SCROLL_MENU_ITEMS[$prev_selected]}" 0 $prev_display_idx $is_even
    fi
    
    # Update new selection (only if it's visible)
    if [ $new_display_idx -ge 0 ] && [ $new_selected -ge 0 ] && [ $new_selected -lt $SCROLL_MENU_TOTAL ]; then
      local row=$(($MENU_START_ROW + $new_display_idx))
      move_cursor $row 1
      local is_even=$(($new_selected % 2 == 0 ? 1 : 0))
      render_scroll_item $new_selected "${SCROLL_MENU_ITEMS[$new_selected]}" 1 $new_display_idx $is_even
    fi
  fi
  
  # Update scroll indicator if needed
  if [ $SCROLL_MENU_TOTAL -gt $SCROLL_MENU_VISIBLE_COUNT ]; then
    move_cursor 4 1
    clear_line
    local scroll_percent=$((($SCROLL_MENU_OFFSET * 100) / ($SCROLL_MENU_TOTAL - $SCROLL_MENU_VISIBLE_COUNT + 1)))
    echo -e "${BOLD}${BLUE}📜 Showing ${CYAN}$(($SCROLL_MENU_OFFSET + 1))${BLUE}-${CYAN}$(($SCROLL_MENU_OFFSET + $SCROLL_MENU_VISIBLE_COUNT))${BLUE} of ${CYAN}$SCROLL_MENU_TOTAL${BLUE} items${RESET}"
  fi
  
  # Update input buffer display if exists
  local last_row=$(($MENU_START_ROW + $SCROLL_MENU_VISIBLE_COUNT + 3))
  move_cursor $last_row 1
  clear_line
  if [ -n "$SCROLL_MENU_INPUT_BUFFER" ]; then
    echo -e "${BOLD}${CYAN}Input: ${GREEN}$SCROLL_MENU_INPUT_BUFFER${RESET}"
  fi
  
  # Move cursor to bottom
  move_cursor $(($(tput lines))) 1
}

# Function to run scroll menu and return selected index via global variable
scroll_menu_run() {
  local header_text="${1:-Select an option}"
  local selected=0
  
  # Clear input buffer
  SCROLL_MENU_INPUT_BUFFER=""
  
  # Initial render
  scroll_menu_render $selected "$header_text"
  
  # Input loop
  while true; do
    key=$(read_key)
    prev_selected=$selected
    
    case "$key" in
      "UP")
        if [ $selected -gt 0 ]; then
          ((selected--))
        else
          selected=$(($SCROLL_MENU_TOTAL - 1))
        fi
        SCROLL_MENU_INPUT_BUFFER=""  # Clear input buffer on arrow key
        scroll_menu_update $prev_selected $selected
        # Update input buffer display
        if [ -n "$SCROLL_MENU_INPUT_BUFFER" ]; then
          local last_row=$(($MENU_START_ROW + $SCROLL_MENU_VISIBLE_COUNT + 3))
          move_cursor $last_row 1
          echo -e "${BOLD}${CYAN}Input: ${GREEN}$SCROLL_MENU_INPUT_BUFFER${RESET}"
        fi
        ;;
      "DOWN")
        if [ $selected -lt $(($SCROLL_MENU_TOTAL - 1)) ]; then
          ((selected++))
        else
          selected=0
        fi
        SCROLL_MENU_INPUT_BUFFER=""  # Clear input buffer on arrow key
        scroll_menu_update $prev_selected $selected
        # Update input buffer display
        if [ -n "$SCROLL_MENU_INPUT_BUFFER" ]; then
          local last_row=$(($MENU_START_ROW + $SCROLL_MENU_VISIBLE_COUNT + 3))
          move_cursor $last_row 1
          echo -e "${BOLD}${CYAN}Input: ${GREEN}$SCROLL_MENU_INPUT_BUFFER${RESET}"
        fi
        ;;
      "ENTER")
        echo -ne "${SHOW_CURSOR}"
        SCROLL_MENU_RESULT=$selected
        SCROLL_MENU_CANCELLED=0
        SCROLL_MENU_INPUT_BUFFER=""
        return 0
        ;;
      "BACKSPACE")
        if [ -n "$SCROLL_MENU_INPUT_BUFFER" ]; then
          SCROLL_MENU_INPUT_BUFFER="${SCROLL_MENU_INPUT_BUFFER%?}"
          # Update selection based on remaining input
          if [[ "$SCROLL_MENU_INPUT_BUFFER" =~ ^[0-9]+$ ]]; then
            local num_input=$((10#$SCROLL_MENU_INPUT_BUFFER))
            if [ $num_input -ge 0 ] && [ $num_input -lt $SCROLL_MENU_TOTAL ]; then
              selected=$num_input
              scroll_menu_update $prev_selected $selected
            fi
          else
            # If buffer is empty, just update display
            scroll_menu_update $prev_selected $selected
          fi
          # Update input buffer display
          local last_row=$(($MENU_START_ROW + $SCROLL_MENU_VISIBLE_COUNT + 3))
          move_cursor $last_row 1
          clear_line
          if [ -n "$SCROLL_MENU_INPUT_BUFFER" ]; then
            echo -e "${BOLD}${CYAN}Input: ${GREEN}$SCROLL_MENU_INPUT_BUFFER${RESET}"
          fi
          move_cursor $(($(tput lines))) 1
        fi
        ;;
      [0-9])
        SCROLL_MENU_INPUT_BUFFER+="$key"
        # Update selection based on input
        if [[ "$SCROLL_MENU_INPUT_BUFFER" =~ ^[0-9]+$ ]]; then
          local num_input=$((10#$SCROLL_MENU_INPUT_BUFFER))
          if [ $num_input -ge 0 ] && [ $num_input -lt $SCROLL_MENU_TOTAL ]; then
            selected=$num_input
            scroll_menu_update $prev_selected $selected
          fi
        fi
        # Update input buffer display
        local last_row=$(($MENU_START_ROW + $SCROLL_MENU_VISIBLE_COUNT + 3))
        move_cursor $last_row 1
        clear_line
        echo -e "${BOLD}${CYAN}Input: ${GREEN}$SCROLL_MENU_INPUT_BUFFER${RESET}"
        move_cursor $(($(tput lines))) 1
        ;;
      "q"|"Q")
        echo -ne "${SHOW_CURSOR}"
        SCROLL_MENU_RESULT=-1
        SCROLL_MENU_CANCELLED=1
        SCROLL_MENU_INPUT_BUFFER=""
        return 0
        ;;
      *)
        ;;
    esac
  done
}

