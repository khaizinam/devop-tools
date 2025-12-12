#!/bin/bash

# Script metadata
NAME="System Monitor"
DESC="Monitor disk space, RAM, and CPU usage with real-time updates (5s refresh)"

# Source UI components
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/../src/ui/ui_common.sh" ]; then
    source "$SCRIPT_DIR/../src/ui/ui_common.sh"
else
    # Fallback color codes
    RED="\033[31m"
    GREEN="\033[32m"
    YELLOW="\033[33m"
    BLUE="\033[34m"
    CYAN="\033[36m"
    WHITE="\033[37m"
    BOLD="\033[1m"
    RESET="\033[0m"
fi

# Source table rendering functions
if [ -f "$SCRIPT_DIR/../src/ui/table_data.sh" ]; then
    source "$SCRIPT_DIR/../src/ui/table_data.sh"
fi

# Global variables for CPU calculation
PREV_CPU_TOTAL=0
PREV_CPU_IDLE=0
FIRST_CPU_READ=true

# Function to get CPU usage percentage
get_cpu_usage() {
    local cpu_line=$(grep '^cpu ' /proc/stat)
    local idle=$(echo $cpu_line | awk '{print $5}')
    local total=0
    
    for val in $cpu_line; do
        if [ "$val" != "cpu" ]; then
            total=$((total + val))
        fi
    done
    
    if [ "$FIRST_CPU_READ" = true ]; then
        PREV_CPU_TOTAL=$total
        PREV_CPU_IDLE=$idle
        FIRST_CPU_READ=false
        echo "0"
        return
    fi
    
    local total_diff=$((total - PREV_CPU_TOTAL))
    local idle_diff=$((idle - PREV_CPU_IDLE))
    
    PREV_CPU_TOTAL=$total
    PREV_CPU_IDLE=$idle
    
    if [ $total_diff -gt 0 ]; then
        local usage=$((100 - (idle_diff * 100 / total_diff)))
        echo $usage
    else
        echo "0"
    fi
}

# Function to format bytes to human readable
format_bytes() {
    local bytes=$1
    if [ $bytes -ge 1073741824 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1073741824}") GB"
    elif [ $bytes -ge 1048576 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1048576}") MB"
    elif [ $bytes -ge 1024 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1024}") KB"
    else
        echo "${bytes} B"
    fi
}

# Function to collect disk usage data
# Using render_table function from table_data.sh
collect_disk_info() {
    local disk_data=""
    local table_rows=()
    
    # Collect all disk data rows
    while IFS= read -r line; do
        # Parse df -h output: Filesystem Size Used Avail Use% Mounted on
        local device=$(echo "$line" | awk '{print $1}')
        local total=$(echo "$line" | awk '{print $2}')
        local used=$(echo "$line" | awk '{print $3}')
        local available=$(echo "$line" | awk '{print $4}')
        local percent=$(echo "$line" | awk '{print $5}' | sed 's/%//')
        # Mount point is the last field (might contain spaces)
        local mount=$(echo "$line" | awk '{print $NF}')
        
        # Skip if any essential field is empty
        if [ -z "$device" ] || [ -z "$total" ] || [ -z "$used" ] || [ -z "$available" ] || [ -z "$percent" ]; then
            continue
        fi
        
        # Default mount to "N/A" if empty
        if [ -z "$mount" ]; then
            mount="N/A"
        fi
        
        local used_with_percent="${used} (${percent}%)"
        
        # Store row data
        table_rows+=("${device}|${used_with_percent}|${total}|${available}|${mount}")
    done < <(df -h | grep -E '^/dev/')
    
    # Render table using render_table function
    if [ ${#table_rows[@]} -gt 0 ]; then
        local disk_table=$(render_table "DISK USAGE" "Device|Used|Total|Available|Mount Point" "${table_rows[@]}")
        disk_data+="$disk_table"
        # Ensure newline at the end
        disk_data+=$'\n'
    else
        # No disks found
        local disk_table=$(render_table "DISK USAGE" "Device|Used|Total|Available|Mount Point" "Status|No disks found")
        disk_data+="$disk_table"
        disk_data+=$'\n'
    fi
    
    printf "%s" "$disk_data"
}

# Function to collect RAM usage data
# Using render_table function from ui_common.sh
collect_ram_info() {
    local mem_info=$(free -b | grep '^Mem:')
    local total=$(echo $mem_info | awk '{print $2}')
    local used=$(echo $mem_info | awk '{print $3}')
    local free=$(echo $mem_info | awk '{print $4}')
    local available=$(echo $mem_info | awk '{print $7}')
    local percent=$((used * 100 / total))
    
    local swap_info=$(free -b | grep '^Swap:')
    local swap_total=$(echo $swap_info | awk '{print $2}')
    local swap_used=$(echo $swap_info | awk '{print $3}')
    local swap_percent=0
    if [ $swap_total -gt 0 ]; then
        swap_percent=$((swap_used * 100 / swap_total))
    fi
    
    local ram_data=""
    local used_text="$(format_bytes $used) ($percent%)"
    
    # RAM USAGE table using render_table
    local ram_table=$(render_table "RAM USAGE" "Type|Value" \
        "Total RAM|$(format_bytes $total)" \
        "Used RAM|${used_text}" \
        "Free RAM|$(format_bytes $free)" \
        "Available RAM|$(format_bytes $available)")
    ram_data+="$ram_table"
    # Ensure newline between tables
    if [ -n "$ram_table" ]; then
        ram_data+=$'\n'
    fi
    
    # SWAP USAGE table using render_table
    if [ $swap_total -gt 0 ]; then
        local swap_used_text="$(format_bytes $swap_used) ($swap_percent%)"
        local swap_table=$(render_table "SWAP USAGE" "Type|Value" \
            "Total Swap|$(format_bytes $swap_total)" \
            "Used Swap|${swap_used_text}" \
            "Free Swap|$(format_bytes $((swap_total - swap_used)))")
        ram_data+="$swap_table"
    else
        local swap_table=$(render_table "SWAP USAGE" "Type|Value" \
            "Status|No swap configured")
        ram_data+="$swap_table"
    fi
    # Ensure newline at the end
    if [ -n "$swap_table" ]; then
        ram_data+=$'\n'
    fi
    
    printf "%s" "$ram_data"
}

# Function to collect CPU usage data
# Using render_table function from table_data.sh
collect_cpu_info() {
    local cpu_usage=$(get_cpu_usage)
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^ *//')
    local cpu_count=$(nproc)
    
    local cpu_data=""
    local cpu_usage_text="${cpu_usage}%"
    
    # CPU USAGE table using render_table (without color)
    local cpu_table=$(render_table "CPU USAGE" "Type|Value" \
        "CPU Usage|${cpu_usage_text}" \
        "CPU Cores|${cpu_count}" \
        "Load Average|${load_avg}")
    
    cpu_data+="$cpu_table"
    # Ensure newline at the end
    cpu_data+=$'\n'
    
    printf "%s" "$cpu_data"
}

# Function to display system info
display_system_info() {
    # Bước 1: Tính toán và thu thập tất cả dữ liệu trước
    local disk_info=$(collect_disk_info)
    local ram_info=$(collect_ram_info)
    local cpu_info=$(collect_cpu_info)
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Bước 2: Render màn hình (bước cuối cùng)
    clear
    printf "%b" "${BOLD}${CYAN}┌─────────────────────────────────────────────────────────────┐${RESET}\n"
    printf "%b" "${BOLD}${CYAN}│            System Resource Monitor                          │${RESET}\n"
    printf "%b" "${BOLD}${CYAN}└─────────────────────────────────────────────────────────────┘${RESET}\n"
    
    # Print each table separately to ensure proper newlines
    # Use echo -e to properly handle escape sequences and newlines
    echo -e "$disk_info"
    echo -e "$ram_info"
    echo -e "$cpu_info"
    
    printf "%b" "${BOLD}${CYAN}┌─────────────────────────────────────────────────────────────┐${RESET}\n"
    local footer_line1="Last updated: $current_time"
    local footer_line1_len=$(get_text_length "$footer_line1")
    local footer_line1_padding=$((59 - footer_line1_len))
    if [ $footer_line1_padding -lt 0 ]; then
        footer_line1_padding=0
    fi
    printf "${BOLD}${CYAN}│${RESET} %s%${footer_line1_padding}s ${BOLD}${CYAN}│${RESET}\n" "$footer_line1" ""
    
    local footer_line2_text="Press 'q' to exit script and return to app_ui"
    local footer_line2_len=$(get_text_length "$footer_line2_text")
    local footer_line2_padding=$((59 - footer_line2_len))
    if [ $footer_line2_padding -lt 0 ]; then
        footer_line2_padding=0
    fi
    printf "${BOLD}${CYAN}│${RESET} ${YELLOW}%s${RESET}%${footer_line2_padding}s ${BOLD}${CYAN}│${RESET}\n" "$footer_line2_text" ""
    printf "%b" "${BOLD}${CYAN}└─────────────────────────────────────────────────────────────┘${RESET}\n"
}

# Trap Ctrl+C to exit gracefully
trap 'stty echo 2>/dev/null; echo -e "\n${BOLD}${GREEN}👋 Exiting System Monitor...${RESET}"; exit 0' INT

# Main loop
while true; do
    display_system_info
    
    # Wait for input with timeout (5 seconds)
    # If 'q' or 'Q' is pressed, exit gracefully
    # Disable echo to hide input characters
    stty -echo 2>/dev/null
    if read -t 5 -n 1 input 2>/dev/null; then
        stty echo 2>/dev/null
        if [ "$input" = "q" ] || [ "$input" = "Q" ]; then
            echo -e "\n${BOLD}${GREEN}👋 Exiting System Monitor and returning to app_ui...${RESET}"
            exit 0
        fi
    else
        stty echo 2>/dev/null
    fi
done

