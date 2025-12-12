#!/bin/bash

# Table Rendering Functions and Demo
# This file contains the render_table function and usage examples

# Source UI components for color codes (same directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/ui_common.sh" ]; then
    source "$SCRIPT_DIR/ui_common.sh"
else
    echo "Error: ui_common.sh not found"
    exit 1
fi

# ============================================================================
# TABLE RENDERING FUNCTIONS
# ============================================================================

# Function to get actual text length (without escape sequences)
# This is useful when calculating column widths with colored text
# 
# Parameters:
#   $1: Text string (may contain ANSI escape sequences)
#
# Returns: Number of visible characters (excluding escape sequences)
#
# Example:
#   get_text_length "${BOLD}Hello${RESET}"  # Returns: 5
get_text_length() {
  local text="$1"
  # Remove escape sequences and count characters
  local clean_text=$(echo -n "$text" | sed 's/\x1b\[[0-9;]*m//g')
  echo -n "${#clean_text}"
}

# Generic function to render ASCII table with borders
# 
# This function automatically calculates column widths based on content
# (similar to HTML/CSS table behavior) or accepts manual column widths.
# The table is rendered with cyan borders and supports colored content.
#
# Usage examples:
#
#   1. Auto-calculate column widths (recommended):
#      render_table "RAM USAGE" "Type|Value" \
#        "Total RAM|9.71 GB" \
#        "Used RAM|1.50 GB (15%)" \
#        "Free RAM|7.41 GB" \
#        "Available RAM|8.23 GB"
#
#   2. Specify column widths manually:
#      render_table "DISK USAGE" "Device|Used|Total|Mount Point" "10|10|10|12" \
#        "/dev/sdd|55G (6%)|1007G|/" \
#        "/dev/sda|100G (50%)|200G|/home"
#
#   3. With colored values (apply colors after rendering):
#      local color=$(get_percent_color 85)
#      render_table "CPU USAGE" "Metric|Value" \
#        "Usage|${color}85%${RESET}" \
#        "Cores|4"
#
# Parameters:
#   $1: Table title (will be centered automatically)
#   $2: Column headers separated by "|" (e.g., "Type|Value|Status")
#   $3: (Optional) Column widths separated by "|" (e.g., "10|20|15")
#       - If all values are numeric and count matches columns, treated as widths
#       - Otherwise, treated as first data row
#   $4+: Data rows, each row is column values separated by "|"
#       - Empty cells can be represented as empty string between "|"
#       - Example: "Value1||Value3" (middle column is empty)
#
# Returns: Formatted table string (use printf "%s" or echo -e to display)
#
# Algorithm:
#   1. Parse column headers
#   2. Detect if first data row is column widths (all numeric)
#   3. If no widths provided:
#      - Calculate max width for each column based on:
#        * Header text length
#        * All cell content lengths in data rows
#      - Add padding (2 spaces: 1 before + 1 after content)
#   4. Calculate total table width
#   5. Render:
#      - Top border (┌───┐)
#      - Title row (centered)
#      - Separator (├───┤)
#      - Header row (bold text)
#      - Separator (├───┤)
#      - Data rows
#      - Bottom border (└───┘)
#
# Notes:
#   - Column widths include padding (content + 2 spaces)
#   - Table automatically adjusts to content
#   - Supports colored text (escape sequences don't affect width calculation)
#   - All borders and separators use CYAN color
#   - Headers are rendered in BOLD
#
render_table() {
  local title="$1"
  shift
  local columns_str="$1"
  shift
  
  # Parse columns
  IFS='|' read -ra COLUMNS <<< "$columns_str"
  local num_cols=${#COLUMNS[@]}
  
  # Check if first data row is column widths (all numeric values)
  local col_widths=()
  local first_data_row="$1"
  local is_widths_row=true
  
  if [ -n "$first_data_row" ]; then
    IFS='|' read -ra first_row <<< "$first_data_row"
    for val in "${first_row[@]}"; do
      if ! [[ "$val" =~ ^[0-9]+$ ]]; then
        is_widths_row=false
        break
      fi
    done
    
    # Also check if number of values matches number of columns
    if [ ${#first_row[@]} -ne $num_cols ]; then
      is_widths_row=false
    fi
  else
    is_widths_row=false
  fi
  
  if [ "$is_widths_row" = true ]; then
    # First row is column widths
    IFS='|' read -ra col_widths <<< "$first_data_row"
    shift
  else
    # Auto-calculate column widths based on content
    local max_widths=()
    for ((i=0; i<num_cols; i++)); do
      max_widths[i]=${#COLUMNS[i]}
    done
    
    # Check all data rows
    for data_row in "$@"; do
      IFS='|' read -ra row_data <<< "$data_row"
      for ((i=0; i<num_cols && i<${#row_data[@]}; i++)); do
        local cell_len=$(get_text_length "${row_data[i]}")
        if [ $cell_len -gt ${max_widths[i]} ]; then
          max_widths[i]=$cell_len
        fi
      done
    done
    
    # Add padding (2 spaces for each column: 1 before + 1 after)
    for ((i=0; i<num_cols; i++)); do
      col_widths[i]=$((${max_widths[i]} + 2))
    done
  fi
  
  # Calculate total table width
  local total_width=1  # Start with left border
  for width in "${col_widths[@]}"; do
    total_width=$((total_width + width + 1))  # +1 for separator
  done
  local content_width=$((total_width - 2))  # Exclude borders
  
  local table_data=""
  local temp_line=""
  
  # Top border
  local top_border=""
  for ((i=0; i<content_width; i++)); do
    top_border+="─"
  done
  table_data+="${BOLD}${CYAN}┌${top_border}┐${RESET}"$'\n'
  
  # Title row
  local title_len=$(get_text_length "$title")
  local padding_total=$((content_width - title_len))
  local padding_left=$((padding_total / 2))
  local padding_right=$((padding_total - padding_left))
  local title_line=$(printf "%${padding_left}s%s%${padding_right}s" "" "$title" "")
  table_data+="${BOLD}${CYAN}│${RESET}${title_line}${BOLD}${CYAN}│${RESET}"$'\n'
  
  # Separator after title
  local separator=""
  for ((i=0; i<num_cols; i++)); do
    for ((j=0; j<${col_widths[i]}; j++)); do
      separator+="─"
    done
    if [ $i -lt $((num_cols - 1)) ]; then
      separator+="┬"
    fi
  done
  table_data+="${BOLD}${CYAN}├${separator}┤${RESET}"$'\n'
  
  # Header row
  temp_line="${BOLD}${CYAN}│${RESET}"
  for ((i=0; i<num_cols; i++)); do
    local header_text="${COLUMNS[i]}"
    local header_len=${#header_text}
    # col_widths[i] includes 2 spaces (1 before + 1 after), so content width is col_widths[i] - 2
    local content_width=$((${col_widths[i]} - 2))
    local padding_needed=$((content_width - header_len))
    if [ $padding_needed -lt 0 ]; then
      padding_needed=0
    fi
    # Build header: bold text + padding spaces
    local header="${BOLD}${header_text}${RESET}"
    for ((p=0; p<padding_needed; p++)); do
      header+=" "
    done
    temp_line+=" ${header} ${BOLD}${CYAN}│${RESET}"
  done
  table_data+="$temp_line"$'\n'
  
  # Separator after header
  separator=""
  for ((i=0; i<num_cols; i++)); do
    for ((j=0; j<${col_widths[i]}; j++)); do
      separator+="─"
    done
    if [ $i -lt $((num_cols - 1)) ]; then
      separator+="┼"
    fi
  done
  table_data+="${BOLD}${CYAN}├${separator}┤${RESET}"$'\n'
  
  # Data rows
  for data_row in "$@"; do
    IFS='|' read -ra row_data <<< "$data_row"
    temp_line="${BOLD}${CYAN}│${RESET}"
    for ((i=0; i<num_cols; i++)); do
      local cell_value="${row_data[i]:-}"
      # Get actual text length (without escape sequences)
      local cell_len=$(get_text_length "$cell_value")
      # col_widths[i] includes 2 spaces (1 before + 1 after), so content width is col_widths[i] - 2
      local content_width=$((${col_widths[i]} - 2))
      # Calculate padding needed
      local padding_needed=$((content_width - cell_len))
      if [ $padding_needed -lt 0 ]; then
        padding_needed=0
      fi
      # Build cell: cell_value + padding spaces
      local cell="${cell_value}"
      for ((p=0; p<padding_needed; p++)); do
        cell+=" "
      done
      temp_line+=" ${cell} ${BOLD}${CYAN}│${RESET}"
    done
    table_data+="$temp_line"$'\n'
  done
  
  # Bottom border
  separator=""
  for ((i=0; i<num_cols; i++)); do
    for ((j=0; j<${col_widths[i]}; j++)); do
      separator+="─"
    done
    if [ $i -lt $((num_cols - 1)) ]; then
      separator+="┴"
    fi
  done
  table_data+="${BOLD}${CYAN}└${separator}┘${RESET}"$'\n'
  table_data+=$'\n'
  
  # Always ensure newline at the end
  # Use printf to ensure newline is preserved when output is captured with $()
  printf "%s" "$table_data"
}