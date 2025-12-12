#!/bin/bash

# ============================================================================
# User Manager - Database Functions
# ============================================================================
# Chứa các hàm quản lý database: init, log, CRUD operations cho users, groups, passwords, SSH keys
# ============================================================================

# Source utils first
DB_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$DB_SCRIPT_DIR/utils.sh" ]; then
    source "$DB_SCRIPT_DIR/utils.sh"
else
    echo "Error: utils.sh not found" >&2
    exit 1
fi

# ============================================================================
# DATABASE INITIALIZATION
# ============================================================================

# Khởi tạo storage directory và database files
db_init() {
    mkdir -p "$STORAGE_DIR"
    
    # Tạo database files nếu chưa có
    [ ! -f "$USERS_DB" ] && touch "$USERS_DB"
    [ ! -f "$GROUPS_DB" ] && touch "$GROUPS_DB"
    [ ! -f "$PASSWORDS_DB" ] && touch "$PASSWORDS_DB"
    [ ! -f "$SSH_KEYS_DB" ] && touch "$SSH_KEYS_DB"
    [ ! -f "$LOG_FILE" ] && touch "$LOG_FILE"
    
    # Thêm header vào database files nếu rỗng
    if [ ! -s "$USERS_DB" ]; then
        echo "username|uid|gid|home|created_date|status|expiry|last_login" > "$USERS_DB"
    fi
    if [ ! -s "$GROUPS_DB" ]; then
        echo "groupname|gid|members|created_date" > "$GROUPS_DB"
    fi
    if [ ! -s "$PASSWORDS_DB" ]; then
        echo "username|password|created_date|last_changed" > "$PASSWORDS_DB"
    fi
    if [ ! -s "$SSH_KEYS_DB" ]; then
        echo "username|key|added_date" > "$SSH_KEYS_DB"
    fi
}

# Ghi log
db_log() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

# ============================================================================
# USER DATABASE OPERATIONS
# ============================================================================

# Thêm user vào database
db_add_user() {
    local username="$1"
    local uid="$2"
    local gid="$3"
    local home="$4"
    local status="${5:-active}"
    local expiry="${6:-}"
    local created_date=$(date '+%Y-%m-%d')
    
    echo "$username|$uid|$gid|$home|$created_date|$status|$expiry|" >> "$USERS_DB"
}

# Lấy thông tin user từ database
db_get_user() {
    local username="$1"
    grep "^$username|" "$USERS_DB" 2>/dev/null | head -1
}

# Cập nhật user trong database
db_update_user() {
    local username="$1"
    local field="$2"  # uid, gid, home, status, expiry, last_login
    local value="$3"
    
    local temp_file=$(mktemp)
    local updated=0
    
    while IFS='|' read -r u uid gid home created status expiry last_login; do
        if [ "$u" = "$username" ]; then
            case "$field" in
                uid) uid="$value" ;;
                gid) gid="$value" ;;
                home) home="$value" ;;
                status) status="$value" ;;
                expiry) expiry="$value" ;;
                last_login) last_login="$value" ;;
            esac
            updated=1
        fi
        echo "$u|$uid|$gid|$home|$created|$status|$expiry|$last_login"
    done < "$USERS_DB" > "$temp_file"
    
    if [ $updated -eq 1 ]; then
        mv "$temp_file" "$USERS_DB"
        return 0
    else
        rm -f "$temp_file"
        return 1
    fi
}

# Xóa user khỏi database
db_delete_user() {
    local username="$1"
    local temp_file=$(mktemp)
    grep -v "^$username|" "$USERS_DB" > "$temp_file"
    mv "$temp_file" "$USERS_DB"
}

# Lấy danh sách users từ database (bỏ header và system users)
db_list_users() {
    local users=()
    while IFS='|' read -r username uid gid home created status expiry last_login; do
        # Bỏ header và system users
        if [ "$username" != "username" ] && [ -n "$uid" ] && [ "$uid" -ge 1000 ]; then
            users+=("$username")
        fi
    done < "$USERS_DB"
    echo "${users[@]}"
}

# ============================================================================
# GROUP DATABASE OPERATIONS
# ============================================================================

# Thêm group vào database
db_add_group() {
    local groupname="$1"
    local gid="$2"
    local members="${3:-}"
    local created_date=$(date '+%Y-%m-%d')
    
    echo "$groupname|$gid|$members|$created_date" >> "$GROUPS_DB"
}

# Lấy thông tin group từ database
db_get_group() {
    local groupname="$1"
    grep "^$groupname|" "$GROUPS_DB" 2>/dev/null | head -1
}

# Cập nhật group trong database
db_update_group() {
    local groupname="$1"
    local members="$2"
    
    local temp_file=$(mktemp)
    local updated=0
    
    while IFS='|' read -r g gid m created; do
        if [ "$g" = "$groupname" ]; then
            m="$members"
            updated=1
        fi
        echo "$g|$gid|$m|$created"
    done < "$GROUPS_DB" > "$temp_file"
    
    if [ $updated -eq 1 ]; then
        mv "$temp_file" "$GROUPS_DB"
        return 0
    else
        rm -f "$temp_file"
        return 1
    fi
}

# Xóa group khỏi database
db_delete_group() {
    local groupname="$1"
    local temp_file=$(mktemp)
    grep -v "^$groupname|" "$GROUPS_DB" > "$temp_file"
    mv "$temp_file" "$GROUPS_DB"
}

# Lấy danh sách groups từ database (bỏ header)
db_list_groups() {
    local groups=()
    while IFS='|' read -r groupname gid members created; do
        if [ "$groupname" != "groupname" ]; then
            groups+=("$groupname")
        fi
    done < "$GROUPS_DB"
    echo "${groups[@]}"
}

# ============================================================================
# PASSWORD DATABASE OPERATIONS
# ============================================================================

# Lưu password vào database
db_save_password() {
    local username="$1"
    local password="$2"
    local created_date=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Xóa password cũ nếu có
    local temp_file=$(mktemp)
    grep -v "^$username|" "$PASSWORDS_DB" > "$temp_file"
    mv "$temp_file" "$PASSWORDS_DB"
    
    # Thêm password mới
    echo "$username|$password|$created_date|$created_date" >> "$PASSWORDS_DB"
}

# Lấy password từ database
db_get_password() {
    local username="$1"
    grep "^$username|" "$PASSWORDS_DB" 2>/dev/null | head -1 | cut -d'|' -f2
}

# ============================================================================
# SSH KEY DATABASE OPERATIONS
# ============================================================================

# Thêm SSH key vào database
db_add_ssh_key() {
    local username="$1"
    local key="$2"
    local added_date=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "$username|$key|$added_date" >> "$SSH_KEYS_DB"
}

# Lấy SSH keys của user
db_get_ssh_keys() {
    local username="$1"
    grep "^$username|" "$SSH_KEYS_DB" 2>/dev/null | cut -d'|' -f2
}

# Xóa SSH key khỏi database
db_remove_ssh_key() {
    local username="$1"
    local key="$2"
    local temp_file=$(mktemp)
    grep -v "^$username|$key|" "$SSH_KEYS_DB" > "$temp_file"
    mv "$temp_file" "$SSH_KEYS_DB"
}
