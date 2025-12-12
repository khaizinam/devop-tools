#!/bin/bash

# ============================================================================
# User Manager - User Management Functions
# ============================================================================
# Chứa các hàm quản lý user: create, delete, password, lock/unlock, expiry, sudo, SSH keys, info, list
# ============================================================================

# Source dependencies
USER_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source db and utils
if [ -f "$USER_SCRIPT_DIR/db.sh" ]; then
    source "$USER_SCRIPT_DIR/db.sh"
else
    echo "Error: db.sh not found" >&2
    exit 1
fi

# Source UI components
if [ -f "$USER_SCRIPT_DIR/../../src/ui/scroll_menu.sh" ]; then
    source "$USER_SCRIPT_DIR/../../src/ui/scroll_menu.sh"
fi

if [ -f "$USER_SCRIPT_DIR/../../src/ui/table_data.sh" ]; then
    source "$USER_SCRIPT_DIR/../../src/ui/table_data.sh"
fi

# ============================================================================
# USER MANAGEMENT FUNCTIONS
# ============================================================================

# 1. Tạo user
create_user() {
    local username="$1"
    
    if [ -z "$username" ]; then
        print_error "Thiếu tên user!"
        echo "Sử dụng: $0 create-user <username>"
        return 1
    fi
    
    if ! validate_username "$username"; then
        print_error "Tên user không hợp lệ! (chỉ a-z, 0-9, _, -, tối đa 32 ký tự)"
        return 1
    fi
    
    if check_user_exists "$username"; then
        print_error "User '$username' đã tồn tại!"
        return 1
    fi
    
    # Tạo user với home directory
    local home_dir="/home/$username"
    if ! useradd -m -d "$home_dir" "$username" 2>/dev/null; then
        print_error "Không thể tạo user '$username'!"
        return 1
    fi
    
    # Tạo mật khẩu
    local password=$(generate_password)
    echo "$username:$password" | chpasswd 2>/dev/null
    
    # Lấy thông tin user
    local uid=$(id -u "$username")
    local gid=$(id -g "$username")
    
    # Lưu vào database
    db_add_user "$username" "$uid" "$gid" "$home_dir" "active" ""
    db_save_password "$username" "$password"
    
    # Ghi log
    db_log "Created user: $username (UID: $uid, GID: $gid, Home: $home_dir)"
    
    print_success "Đã tạo user '$username' thành công!"
    echo -e "${BOLD}${CYAN}Username:${RESET} $username"
    echo -e "${BOLD}${CYAN}Password:${RESET} ${BOLD}${GREEN}$password${RESET}"
    echo -e "${BOLD}${YELLOW}⚠ Lưu mật khẩu này ngay!${RESET}"
    
    return 0
}

# 2. Xóa user
delete_user() {
    local username="$1"
    
    if [ -z "$username" ]; then
        print_error "Thiếu tên user!"
        echo "Sử dụng: $0 delete-user <username>"
        return 1
    fi
    
    if ! check_user_exists "$username"; then
        print_error "User '$username' không tồn tại!"
        return 1
    fi
    
    if is_system_user "$username"; then
        print_error "Không thể xóa system user '$username'!"
        return 1
    fi
    
    # Xóa user và home directory
    if ! userdel -r "$username" 2>/dev/null; then
        print_error "Không thể xóa user '$username'!"
        return 1
    fi
    
    # Xóa khỏi database
    db_delete_user "$username"
    
    # Ghi log
    db_log "Deleted user: $username"
    
    print_success "Đã xóa user '$username' thành công!"
    return 0
}

# 8. Liệt kê users (dùng scroll_menu)
list_users() {
    local users=($(db_list_users))
    
    if [ ${#users[@]} -eq 0 ]; then
        print_warning "Không có user nào trong database!"
        return 0
    fi
    
    # Sử dụng scroll_menu để hiển thị
    scroll_menu_init "${users[@]}"
    scroll_menu_run "Danh sách Users"
    
    if [ $SCROLL_MENU_CANCELLED -eq 1 ] || [ $SCROLL_MENU_RESULT -lt 0 ]; then
        return 0
    fi
    
    local selected_user="${users[$SCROLL_MENU_RESULT]}"
    if [ -n "$selected_user" ]; then
        show_user_info "$selected_user"
    fi
}

# 10. Hiển thị log
show_log() {
    if [ ! -f "$LOG_FILE" ] || [ ! -s "$LOG_FILE" ]; then
        print_warning "Log file trống!"
        return 0
    fi
    
    # Đọc log và hiển thị với scroll_menu
    local log_lines=()
    while IFS= read -r line; do
        log_lines+=("$line")
    done < "$LOG_FILE"
    
    if [ ${#log_lines[@]} -eq 0 ]; then
        print_warning "Không có log nào!"
        return 0
    fi
    
    scroll_menu_init "${log_lines[@]}"
    scroll_menu_run "User Manager Log"
}

# ============================================================================
# EXTENDED USER FEATURES
# ============================================================================

# Đổi mật khẩu user
change_password() {
    local username="$1"
    
    if [ -z "$username" ]; then
        print_error "Thiếu tên user!"
        echo "Sử dụng: $0 change-password <username>"
        return 1
    fi
    
    if ! check_user_exists "$username"; then
        print_error "User '$username' không tồn tại!"
        return 1
    fi
    
    # Tạo mật khẩu mới
    local password=$(generate_password)
    if ! echo "$username:$password" | chpasswd 2>/dev/null; then
        print_error "Không thể đổi mật khẩu cho user '$username'!"
        return 1
    fi
    
    # Cập nhật database
    db_save_password "$username" "$password"
    
    # Ghi log
    db_log "Changed password for user: $username"
    
    print_success "Đã đổi mật khẩu cho user '$username'!"
    echo -e "${BOLD}${CYAN}New Password:${RESET} ${BOLD}${GREEN}$password${RESET}"
    echo -e "${BOLD}${YELLOW}⚠ Lưu mật khẩu này ngay!${RESET}"
    return 0
}

# Khóa user
lock_user() {
    local username="$1"
    
    if [ -z "$username" ]; then
        print_error "Thiếu tên user!"
        echo "Sử dụng: $0 lock-user <username>"
        return 1
    fi
    
    if ! check_user_exists "$username"; then
        print_error "User '$username' không tồn tại!"
        return 1
    fi
    
    if ! usermod -L "$username" 2>/dev/null; then
        print_error "Không thể khóa user '$username'!"
        return 1
    fi
    
    # Cập nhật database
    db_update_user "$username" "status" "locked"
    
    # Ghi log
    db_log "Locked user: $username"
    
    print_success "Đã khóa user '$username'!"
    return 0
}

# Mở khóa user
unlock_user() {
    local username="$1"
    
    if [ -z "$username" ]; then
        print_error "Thiếu tên user!"
        echo "Sử dụng: $0 unlock-user <username>"
        return 1
    fi
    
    if ! check_user_exists "$username"; then
        print_error "User '$username' không tồn tại!"
        return 1
    fi
    
    if ! usermod -U "$username" 2>/dev/null; then
        print_error "Không thể mở khóa user '$username'!"
        return 1
    fi
    
    # Cập nhật database
    db_update_user "$username" "status" "active"
    
    # Ghi log
    db_log "Unlocked user: $username"
    
    print_success "Đã mở khóa user '$username'!"
    return 0
}

# Đặt ngày hết hạn cho user
set_expiry() {
    local username="$1"
    local expiry_date="$2"
    
    if [ -z "$username" ] || [ -z "$expiry_date" ]; then
        print_error "Thiếu tham số!"
        echo "Sử dụng: $0 set-expiry <username> <YYYY-MM-DD>"
        return 1
    fi
    
    if ! check_user_exists "$username"; then
        print_error "User '$username' không tồn tại!"
        return 1
    fi
    
    # Validate date format (YYYY-MM-DD)
    if [[ ! "$expiry_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        print_error "Định dạng ngày không hợp lệ! Sử dụng YYYY-MM-DD"
        return 1
    fi
    
    # Set expiry date
    if ! chage -E "$expiry_date" "$username" 2>/dev/null; then
        print_error "Không thể set expiry date cho user '$username'!"
        return 1
    fi
    
    # Cập nhật database
    db_update_user "$username" "expiry" "$expiry_date"
    
    # Ghi log
    db_log "Set expiry date for user '$username': $expiry_date"
    
    print_success "Đã set expiry date cho user '$username': $expiry_date"
    return 0
}

# Thêm quyền sudo
add_sudo() {
    local username="$1"
    
    if [ -z "$username" ]; then
        print_error "Thiếu tên user!"
        echo "Sử dụng: $0 add-sudo <username>"
        return 1
    fi
    
    if ! check_user_exists "$username"; then
        print_error "User '$username' không tồn tại!"
        return 1
    fi
    
    # Thêm vào group sudo
    if ! usermod -aG sudo "$username" 2>/dev/null; then
        print_error "Không thể thêm quyền sudo cho user '$username'!"
        return 1
    fi
    
    # Ghi log
    db_log "Added sudo access for user: $username"
    
    print_success "Đã thêm quyền sudo cho user '$username'!"
    return 0
}

# Xóa quyền sudo
remove_sudo() {
    local username="$1"
    
    if [ -z "$username" ]; then
        print_error "Thiếu tên user!"
        echo "Sử dụng: $0 remove-sudo <username>"
        return 1
    fi
    
    if ! check_user_exists "$username"; then
        print_error "User '$username' không tồn tại!"
        return 1
    fi
    
    # Xóa khỏi group sudo
    if ! gpasswd -d "$username" sudo 2>/dev/null; then
        print_error "Không thể xóa quyền sudo cho user '$username'!"
        return 1
    fi
    
    # Ghi log
    db_log "Removed sudo access for user: $username"
    
    print_success "Đã xóa quyền sudo cho user '$username'!"
    return 0
}

# Thêm SSH key
add_ssh_key() {
    local username="$1"
    local key="$2"
    
    if [ -z "$username" ] || [ -z "$key" ]; then
        print_error "Thiếu tham số!"
        echo "Sử dụng: $0 add-ssh-key <username> <key>"
        return 1
    fi
    
    if ! check_user_exists "$username"; then
        print_error "User '$username' không tồn tại!"
        return 1
    fi
    
    local home_dir=$(getent passwd "$username" | cut -d: -f6)
    local ssh_dir="$home_dir/.ssh"
    local auth_keys="$ssh_dir/authorized_keys"
    
    # Tạo .ssh directory nếu chưa có
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
    chown "$username:$username" "$ssh_dir"
    
    # Thêm key vào authorized_keys
    echo "$key" >> "$auth_keys"
    chmod 600 "$auth_keys"
    chown "$username:$username" "$auth_keys"
    
    # Lưu vào database
    db_add_ssh_key "$username" "$key"
    
    # Ghi log
    db_log "Added SSH key for user: $username"
    
    print_success "Đã thêm SSH key cho user '$username'!"
    return 0
}

# Xóa SSH key
remove_ssh_key() {
    local username="$1"
    
    if [ -z "$username" ]; then
        print_error "Thiếu tên user!"
        echo "Sử dụng: $0 remove-ssh-key <username>"
        return 1
    fi
    
    if ! check_user_exists "$username"; then
        print_error "User '$username' không tồn tại!"
        return 1
    fi
    
    local home_dir=$(getent passwd "$username" | cut -d: -f6)
    local auth_keys="$home_dir/.ssh/authorized_keys"
    
    if [ ! -f "$auth_keys" ]; then
        print_warning "User '$username' không có SSH keys!"
        return 0
    fi
    
    # Xóa tất cả keys
    > "$auth_keys"
    
    # Xóa khỏi database
    local keys=($(db_get_ssh_keys "$username"))
    for key in "${keys[@]}"; do
        db_remove_ssh_key "$username" "$key"
    done
    
    # Ghi log
    db_log "Removed SSH keys for user: $username"
    
    print_success "Đã xóa tất cả SSH keys của user '$username'!"
    return 0
}

# Hiển thị thông tin chi tiết user (dùng render_table)
show_user_info() {
    local username="$1"
    
    if [ -z "$username" ]; then
        print_error "Thiếu tên user!"
        echo "Sử dụng: $0 show-user-info <username>"
        return 1
    fi
    
    if ! check_user_exists "$username"; then
        print_error "User '$username' không tồn tại!"
        return 1
    fi
    
    # Lấy thông tin từ system
    local uid=$(id -u "$username")
    local gid=$(id -g "$username")
    local groups=$(id -Gn "$username" | tr ' ' ',')
    local home_dir=$(getent passwd "$username" | cut -d: -f6)
    local shell=$(getent passwd "$username" | cut -d: -f7)
    
    # Lấy thông tin từ database
    local db_user=$(db_get_user "$username")
    local status="active"
    local expiry=""
    local created=""
    local last_login=""
    
    if [ -n "$db_user" ]; then
        IFS='|' read -r u u_id g_id h c s e l <<< "$db_user"
        status="${s:-active}"
        expiry="${e:-Never}"
        created="${c:-Unknown}"
        last_login="${l:-Never}"
    fi
    
    # Kiểm tra lock status
    if passwd -S "$username" 2>/dev/null | grep -q "L "; then
        status="locked"
    fi
    
    # Hiển thị với render_table - dữ liệu thuần túy (không có màu)
    clear
    print_header "Thông tin User: $username"
    
    local user_table=$(render_table "USER INFORMATION" "Field|Value" \
        "Username|$username" \
        "UID|$uid" \
        "GID|$gid" \
        "Home Directory|$home_dir" \
        "Shell|$shell" \
        "Groups|$groups" \
        "Status|$status" \
        "Created Date|$created" \
        "Expiry Date|$expiry" \
        "Last Login|$last_login")
    echo -e "$user_table"
    
    echo ""
    echo -e "${BOLD}${CYAN}Press Enter to continue...${RESET}"
    read -r
}
