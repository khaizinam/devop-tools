#!/bin/bash
# Simple paginated menu (no scroll cache)
# Depends on ui_common.sh for colors, read_key, cleanup

if [ -z "$UI_COMMON_LOADED" ]; then
  source "$(dirname "$0")/ui_common.sh"
  UI_COMMON_LOADED=1
fi

# State
declare -a PAGE_MENU_ITEMS
declare -a PAGE_MENU_DESCS
PAGE_MENU_TOTAL=0
PAGE_MENU_PAGE_SIZE=10
PAGE_MENU_RESULT=-1
PAGE_MENU_CANCELLED=0
PAGE_MENU_INPUT_BUFFER=""

page_menu_set_page_size() {
  local size=$1
  if [ -z "$size" ] || [ "$size" -le 0 ]; then
    PAGE_MENU_PAGE_SIZE=10
  else
    PAGE_MENU_PAGE_SIZE=$size
  fi
}

# Init with items only (no descs)
page_menu_init() {
  local items=("$@")
  PAGE_MENU_ITEMS=("${items[@]}")
  PAGE_MENU_DESCS=()
  PAGE_MENU_TOTAL=${#PAGE_MENU_ITEMS[@]}
  PAGE_MENU_RESULT=-1
  PAGE_MENU_CANCELLED=0
  PAGE_MENU_INPUT_BUFFER=""
}

# Init with items + descs (by array name)
page_menu_set_data() {
  local -n _items=$1
  local -n _descs=$2
  PAGE_MENU_ITEMS=("${_items[@]}")
  PAGE_MENU_DESCS=("${_descs[@]}")
  PAGE_MENU_TOTAL=${#PAGE_MENU_ITEMS[@]}
  PAGE_MENU_RESULT=-1
  PAGE_MENU_CANCELLED=0
  PAGE_MENU_INPUT_BUFFER=""
}

page_menu_render() {
  local selected=$1
  local title="${2:-Menu}"

  local total=$PAGE_MENU_TOTAL
  local page_size=$PAGE_MENU_PAGE_SIZE
  if [ $page_size -lt 1 ]; then page_size=1; fi

  local page=$((selected / page_size))
  local start=$((page * page_size))
  local end=$((start + page_size - 1))
  if [ $end -ge $((total - 1)) ]; then end=$((total - 1)); fi
  local total_pages=$(((total + page_size - 1) / page_size))

  clear
  echo -e "${BOLD}${CYAN}========================================${RESET}"
  echo -e "${BOLD}${CYAN}    $title    ${RESET}"
  echo -e "${BOLD}${CYAN}========================================${RESET}"
  echo -e "${CYAN}Page $((page+1))/${total_pages} (items $start-$end of $((total-1)))${RESET}"
  echo ""

  for ((idx=start; idx<=end; idx++)); do
    local name="${PAGE_MENU_ITEMS[$idx]}"
    local desc=""
    if [ $idx -lt ${#PAGE_MENU_DESCS[@]} ]; then
      desc="${PAGE_MENU_DESCS[$idx]}"
    fi

    if [ $selected -eq $idx ]; then
      if (( idx % 2 == 0 )); then
        echo -e "${BOLD}${BG_GREEN}${WHITE}▶ [$idx] $name${RESET}"
        if [ -n "${desc// }" ]; then
          echo -e "${BOLD}${BG_GREEN}${WHITE}   └─ ${desc}${RESET}"
        fi
      else
        echo -e "${BOLD}${BG_YELLOW}${BLUE}▶ [$idx] $name${RESET}"
        if [ -n "${desc// }" ]; then
          echo -e "${BOLD}${BG_YELLOW}${BLUE}   └─ ${desc}${RESET}"
        fi
      fi
    else
      if (( idx % 2 == 0 )); then
        echo -e "${GREEN}  [$idx] $name${RESET}"
        if [ -n "${desc// }" ]; then
          echo -e "${CYAN}     └─ ${desc}${RESET}"
        fi
      else
        echo -e "${YELLOW}  [$idx] $name${RESET}"
        if [ -n "${desc// }" ]; then
          echo -e "${CYAN}     └─ ${desc}${RESET}"
        fi
      fi
    fi
  done

  echo ""
  echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${BOLD}${WHITE}Controls: ${CYAN}↑↓${WHITE} Navigate | ${CYAN}←→${WHITE} Page | ${CYAN}Enter${WHITE} Select | ${CYAN}Type number${WHITE} Jump | ${CYAN}q/ESC${WHITE} Quit${RESET}"
  if [ -n "$PAGE_MENU_INPUT_BUFFER" ]; then
    echo -e "${BOLD}${CYAN}Input: ${GREEN}$PAGE_MENU_INPUT_BUFFER${RESET}"
  fi
}

page_menu_run() {
  local title="${1:-Menu}"
  local selected=0
  PAGE_MENU_INPUT_BUFFER=""

  if [ $PAGE_MENU_TOTAL -le 0 ]; then
    echo "❌ No items to display" >&2
    return 1
  fi

  page_menu_render $selected "$title"

  while true; do
    key=$(read_key)
    case "$key" in
      "UP")
        if [ $selected -gt 0 ]; then
          ((selected--))
        else
          selected=$((PAGE_MENU_TOTAL-1))
        fi
        PAGE_MENU_INPUT_BUFFER=""
        page_menu_render $selected "$title"
        ;;
      "DOWN")
        if [ $selected -lt $((PAGE_MENU_TOTAL-1)) ]; then
          ((selected++))
        else
          selected=0
        fi
        PAGE_MENU_INPUT_BUFFER=""
        page_menu_render $selected "$title"
        ;;
      "LEFT")
        if [ $selected -ge $PAGE_MENU_PAGE_SIZE ]; then
          selected=$((selected-PAGE_MENU_PAGE_SIZE))
        else
          selected=0
        fi
        PAGE_MENU_INPUT_BUFFER=""
        page_menu_render $selected "$title"
        ;;
      "RIGHT")
        if [ $((selected+PAGE_MENU_PAGE_SIZE)) -lt $PAGE_MENU_TOTAL ]; then
          selected=$((selected+PAGE_MENU_PAGE_SIZE))
        else
          selected=$((PAGE_MENU_TOTAL-1))
        fi
        PAGE_MENU_INPUT_BUFFER=""
        page_menu_render $selected "$title"
        ;;
      "ENTER")
        PAGE_MENU_RESULT=$selected
        PAGE_MENU_CANCELLED=0
        return 0
        ;;
      "q"|"Q"|"ESC")
        PAGE_MENU_RESULT=-1
        PAGE_MENU_CANCELLED=1
        return 1
        ;;
      "BACKSPACE")
        if [ -n "$PAGE_MENU_INPUT_BUFFER" ]; then
          PAGE_MENU_INPUT_BUFFER="${PAGE_MENU_INPUT_BUFFER%?}"
          if [[ "$PAGE_MENU_INPUT_BUFFER" =~ ^[0-9]+$ ]]; then
            num=$((10#$PAGE_MENU_INPUT_BUFFER))
            if [ $num -lt $PAGE_MENU_TOTAL ]; then
              selected=$num
            fi
          fi
          page_menu_render $selected "$title"
        fi
        ;;
      [0-9])
        PAGE_MENU_INPUT_BUFFER+="$key"
        if [[ "$PAGE_MENU_INPUT_BUFFER" =~ ^[0-9]+$ ]]; then
          num=$((10#$PAGE_MENU_INPUT_BUFFER))
          if [ $num -lt $PAGE_MENU_TOTAL ]; then
            selected=$num
            page_menu_render $selected "$title"
          fi
        fi
        ;;
      *)
        ;;
    esac
  done
}

