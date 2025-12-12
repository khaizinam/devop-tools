#!/bin/bash

# ============================================================================
# User Manager - Group Management Functions
# ============================================================================
# Chứa các hàm quản lý group: create, delete, add/remove users, permissions, list
# ============================================================================

# Source dependencies
GROUP_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source db and utils
if [ -f "$GROUP_SCRIPT_DIR/db.sh" ]; then
    source "$GROUP_SCRIPT_DIR/db.sh"
else
    echo "Error: db.sh not found" >&2
    exit 1
fi

# Source UI components
if [ -f "$GROUP_SCRIPT_DIR/../../src/ui/scroll_menu.sh" ]; then
    source "$GROUP_SCRIPT_DIR/../../src/ui/scroll_menu.sh"
fi

if [ -f "$GROUP_SCRIPT_DIR/../../src/ui/table_data.sh" ]; then
    source "$GROUP_SCRIPT_DIR/../../src/ui/table_data.sh"
fi

# ============================================================================
# GROUP MANAGEMENT FUNCTIONS
# ============================================================================

# 3. Tạo group
create_group() {
    local groupname="$1"
    
    if [ -z "$groupname" ]; then
        print_error "Thiếu tên group!"
        echo "Sử dụng: $0 create-group <groupname>"
        return 1
    fi
    
    if ! validate_groupname "$groupname"; then
        print_error "Tên group không hợp lệ! (chỉ a-z, 0-9, _, -, tối đa 32 ký tự)"
        return 1
    fi
    
    if check_group_exists "$groupname"; then
        print_error "Group '$groupname' đã tồn tại!"
        return 1
    fi
    
    # Tạo group
    if ! groupadd "$groupname" 2>/dev/null; then
        print_error "Không thể tạo group '$groupname'!"
        return 1
    fi
    
    # Lấy GID
    local gid=$(getent group "$groupname" | cut -d: -f3)
    
    # Lưu vào database
    db_add_group "$groupname" "$gid" ""
    
    # Ghi log
    db_log "Created group: $groupname (GID: $gid)"
    
    print_success "Đã tạo group '$groupname' thành công! (GID: $gid)"
    return 0
}

# 4. Xóa group
delete_group() {
    local groupname="$1"
    
    if [ -z "$groupname" ]; then
        print_error "Thiếu tên group!"
        echo "Sử dụng: $0 delete-group <groupname>"
        return 1
    fi
    
    if ! check_group_exists "$groupname"; then
        print_error "Group '$groupname' không tồn tại!"
        return 1
    fi
    
    # Kiểm tra group có members không
    local members=$(getent group "$groupname" | cut -d: -f4)
    if [ -n "$members" ]; then
        print_error "Group '$groupname' vẫn còn members: $members"
        print_info "Vui lòng remove tất cả members trước khi xóa group!"
        return 1
    fi
    
    # Xóa group
    if ! groupdel "$groupname" 2>/dev/null; then
        print_error "Không thể xóa group '$groupname'!"
        return 1
    fi
    
    # Xóa khỏi database
    db_delete_group "$groupname"
    
    # Ghi log
    db_log "Deleted group: $groupname"
    
    print_success "Đã xóa group '$groupname' thành công!"
    return 0
}

# 5. Thêm user vào group
add_user_group() {
    local username="$1"
    local groupname="$2"
    
    if [ -z "$username" ] || [ -z "$groupname" ]; then
        print_error "Thiếu tham số!"
        echo "Sử dụng: $0 add-user-group <username> <group>"
        return 1
    fi
    
    if ! check_user_exists "$username"; then
        print_error "User '$username' không tồn tại!"
        return 1
    fi
    
    if ! check_group_exists "$groupname"; then
        print_error "Group '$groupname' không tồn tại!"
        return 1
    fi
    
    # Thêm user vào group
    if ! usermod -a -G "$groupname" "$username" 2>/dev/null; then
        print_error "Không thể thêm user '$username' vào group '$groupname'!"
        return 1
    fi
    
    # Cập nhật database
    local db_group=$(db_get_group "$groupname")
    if [ -n "$db_group" ]; then
        local current_members=$(echo "$db_group" | cut -d'|' -f3)
        if [ -z "$current_members" ]; then
            current_members="$username"
        else
            # Kiểm tra user đã có trong members chưa
            if [[ ! ",$current_members," =~ ,$username, ]]; then
                current_members="$current_members,$username"
            fi
        fi
        db_update_group "$groupname" "$current_members"
    fi
    
    # Ghi log
    db_log "Added user '$username' to group '$groupname'"
    
    print_success "Đã thêm user '$username' vào group '$groupname'!"
    return 0
}

# 6. Xóa user khỏi group
remove_user_group() {
    local username="$1"
    local groupname="$2"
    
    if [ -z "$username" ] || [ -z "$groupname" ]; then
        print_error "Thiếu tham số!"
        echo "Sử dụng: $0 remove-user-group <username> <group>"
        return 1
    fi
    
    if ! check_user_exists "$username"; then
        print_error "User '$username' không tồn tại!"
        return 1
    fi
    
    if ! check_group_exists "$groupname"; then
        print_error "Group '$groupname' không tồn tại!"
        return 1
    fi
    
    # Xóa user khỏi group
    if ! gpasswd -d "$username" "$groupname" 2>/dev/null; then
        print_error "Không thể xóa user '$username' khỏi group '$groupname'!"
        return 1
    fi
    
    # Cập nhật database
    local db_group=$(db_get_group "$groupname")
    if [ -n "$db_group" ]; then
        local current_members=$(echo "$db_group" | cut -d'|' -f3)
        # Xóa username khỏi members
        current_members=$(echo ",$current_members," | sed "s/,$username,/,/g" | sed 's/^,\|,$//g')
        db_update_group "$groupname" "$current_members"
    fi
    
    # Ghi log
    db_log "Removed user '$username' from group '$groupname'"
    
    print_success "Đã xóa user '$username' khỏi group '$groupname'!"
    return 0
}

# 7. Set group permission cho folder
set_group_permission() {
    local folder="$1"
    local groupname="$2"
    
    if [ -z "$folder" ] || [ -z "$groupname" ]; then
        print_error "Thiếu tham số!"
        echo "Sử dụng: $0 set-group-permission <folder> <group>"
        return 1
    fi
    
    if [ ! -d "$folder" ]; then
        print_error "Folder '$folder' không tồn tại!"
        return 1
    fi
    
    if ! check_group_exists "$groupname"; then
        print_error "Group '$groupname' không tồn tại!"
        return 1
    fi
    
    # Chown và chmod
    if ! chown root:"$groupname" "$folder" 2>/dev/null; then
        print_error "Không thể chown folder '$folder'!"
        return 1
    fi
    
    if ! chmod 775 "$folder" 2>/dev/null; then
        print_error "Không thể chmod folder '$folder'!"
        return 1
    fi
    
    # Ghi log
    db_log "Set permission for folder '$folder' to root:$groupname (775)"
    
    print_success "Đã set permission cho folder '$folder' thành công!"
    echo -e "${BOLD}${CYAN}Owner:${RESET} root:$groupname"
    echo -e "${BOLD}${CYAN}Permission:${RESET} 775"
    return 0
}

# 9. Liệt kê groups (dùng scroll_menu)
list_groups() {
    local groups=($(db_list_groups))
    
    if [ ${#groups[@]} -eq 0 ]; then
        print_warning "Không có group nào trong database!"
        return 0
    fi
    
    # Sử dụng scroll_menu để hiển thị
    scroll_menu_init "${groups[@]}"
    scroll_menu_run "Danh sách Groups"
    
    if [ $SCROLL_MENU_CANCELLED -eq 1 ] || [ $SCROLL_MENU_RESULT -lt 0 ]; then
        return 0
    fi
    
    local selected_group="${groups[$SCROLL_MENU_RESULT]}"
    if [ -n "$selected_group" ]; then
        # Hiển thị thông tin group
        local db_group=$(db_get_group "$selected_group")
        if [ -n "$db_group" ]; then
            IFS='|' read -r gname gid members created <<< "$db_group"
            clear
            print_header "Thông tin Group: $gname"
            # Render table với dữ liệu thuần túy (không có màu)
            local group_table=$(render_table "GROUP INFO" "Field|Value" \
                "Group Name|$gname" \
                "GID|$gid" \
                "Members|${members:-None}" \
                "Created Date|$created")
            echo -e "$group_table"
            echo ""
            echo -e "${BOLD}${CYAN}Press Enter to continue...${RESET}"
            read -r
        fi
    fi
}
