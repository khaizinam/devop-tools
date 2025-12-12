#!/bin/bash

# ============================================================================
# User Manager - Utility Functions
# ============================================================================
# Chứa các hàm tiện ích: print functions, validation, checks, password generation
# ============================================================================

# Source UI common functions
UTILS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$UTILS_SCRIPT_DIR/../../src/ui/ui_common.sh" ]; then
    source "$UTILS_SCRIPT_DIR/../../src/ui/ui_common.sh"
else
    echo "Error: ui_common.sh not found" >&2
    exit 1
fi

# Export storage configuration (nếu chưa được export)
if [ -z "$STORAGE_DIR" ]; then
    export STORAGE_DIR="$UTILS_SCRIPT_DIR/../../storage/usermgr"
    export LOG_FILE="$STORAGE_DIR/log.txt"
    export USERS_DB="$STORAGE_DIR/users.db"
    export GROUPS_DB="$STORAGE_DIR/groups.db"
    export PASSWORDS_DB="$STORAGE_DIR/passwords.db"
    export SSH_KEYS_DB="$STORAGE_DIR/ssh_keys.db"
fi

# ============================================================================
# PRINT FUNCTIONS
# ============================================================================

# In header đẹp
print_header() {
    local title="${1:-User & Group Manager}"
    local width=50
    local title_len=${#title}
    local padding=$(( (width - title_len - 2) / 2 ))
    
    echo -e "${BOLD}${CYAN}┌$(printf '%*s' $((width-2)) '' | tr ' ' '─')┐${RESET}"
    printf "${BOLD}${CYAN}│${RESET}%*s${BOLD}${CYAN}│${RESET}\n" $width "$(printf '%*s%s%*s' $padding '' "$title" $padding '')"
    echo -e "${BOLD}${CYAN}└$(printf '%*s' $((width-2)) '' | tr ' ' '─')┘${RESET}"
}

# In thông báo thành công
print_success() {
    echo -e "${BOLD}${GREEN}✓${RESET} ${GREEN}$1${RESET}"
}

# In thông báo lỗi
print_error() {
    echo -e "${BOLD}${RED}✗${RESET} ${RED}$1${RESET}" >&2
}

# In cảnh báo
print_warning() {
    echo -e "${BOLD}${YELLOW}⚠${RESET} ${YELLOW}$1${RESET}"
}

# In thông tin
print_info() {
    echo -e "${BOLD}${CYAN}ℹ${RESET} ${CYAN}$1${RESET}"
}

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

# Kiểm tra quyền root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Script này cần quyền root để chạy!"
        echo "Sử dụng: sudo $0"
        exit 1
    fi
}

# Validate username format
validate_username() {
    local username="$1"
    if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]*$ ]] || [ ${#username} -gt 32 ]; then
        return 1
    fi
    return 0
}

# Validate groupname format
validate_groupname() {
    local groupname="$1"
    if [[ ! "$groupname" =~ ^[a-z_][a-z0-9_-]*$ ]] || [ ${#groupname} -gt 32 ]; then
        return 1
    fi
    return 0
}

# ============================================================================
# CHECK FUNCTIONS
# ============================================================================

# Kiểm tra user hệ thống (UID < 1000)
is_system_user() {
    local username="$1"
    local uid=$(id -u "$username" 2>/dev/null)
    if [ -n "$uid" ] && [ "$uid" -lt 1000 ]; then
        return 0
    fi
    return 1
}

# Kiểm tra user tồn tại
check_user_exists() {
    local username="$1"
    id "$username" &>/dev/null
}

# Kiểm tra group tồn tại
check_group_exists() {
    local groupname="$1"
    getent group "$groupname" &>/dev/null
}

# ============================================================================
# PASSWORD GENERATION
# ============================================================================

# Tạo mật khẩu ngẫu nhiên 8 ký tự
generate_password() {
    tr -dc 'a-z0-9' </dev/urandom | head -c 8
}
