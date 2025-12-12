#!/bin/bash

# ============================================================================
# User Manager - Interactive Menu Functions
# ============================================================================
# Chứa các hàm menu tương tác: main menu, user management menu, group management menu
# ============================================================================

# Source dependencies
# Note: user.sh and group.sh are already sourced in usermgr.sh main script
# We don't need to source them again here, just use their functions

# Source page menu - calculate path immediately
MENU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$MENU_DIR/../../src/ui/page_menu.sh" ]; then
    source "$MENU_DIR/../../src/ui/page_menu.sh"
fi

# ============================================================================
# OLD MENU FUNCTIONS (DEPRECATED - Kept for reference)
# ============================================================================

# Menu quản lý User (DEPRECATED - replaced by view_users_list + user_detail_view)
# user_management_menu() {
#     local menu_items=(
#         "Create User"
#         "Delete User"
#         "List Users"
#         "Show User Info"
#         "Change Password"
#         "Lock User"
#         "Unlock User"
#         "Set Expiry Date"
#         "Add Sudo Access"
#         "Remove Sudo Access"
#         "Add SSH Key"
#         "Remove SSH Key"
#         "Back to Main Menu"
#     )
#     
#     local menu_descs=(
#         "Tạo user mới với home directory và password tự động"
#         "Xóa user và home directory"
#         "Liệt kê tất cả users (scroll menu)"
#         "Hiển thị thông tin chi tiết user"
#         "Đổi mật khẩu user (tự động generate)"
#         "Khóa tài khoản user"
#         "Mở khóa tài khoản user"
#         "Đặt ngày hết hạn cho user (YYYY-MM-DD)"
#         "Thêm quyền sudo cho user"
#         "Xóa quyền sudo của user"
#         "Thêm SSH public key cho user"
#         "Xóa SSH keys của user"
#         "Quay lại menu chính"
#     )
#     
#     page_menu_set_data menu_items menu_descs
#     page_menu_set_page_size 10
#     page_menu_run "User Management"
#     
#     if [ $PAGE_MENU_CANCELLED -eq 1 ] || [ $PAGE_MENU_RESULT -lt 0 ]; then
#         return 0
#     fi
#     
#     local selected=$PAGE_MENU_RESULT
#     clear
#     
#     case $selected in
#         0) # Create User
#             echo -e "${BOLD}${CYAN}Create User${RESET}"
#             echo -n "Enter username: "
#             read -r username
#             create_user "$username"
#             ;;
#         1) # Delete User
#             echo -e "${BOLD}${CYAN}Delete User${RESET}"
#             echo -n "Enter username: "
#             read -r username
#             delete_user "$username"
#             ;;
#         2) # List Users
#             list_users
#             ;;
#         3) # Show User Info
#             echo -e "${BOLD}${CYAN}Show User Info${RESET}"
#             echo -n "Enter username: "
#             read -r username
#             show_user_info "$username"
#             ;;
#         4) # Change Password
#             echo -e "${BOLD}${CYAN}Change Password${RESET}"
#             echo -n "Enter username: "
#             read -r username
#             change_password "$username"
#             ;;
#         5) # Lock User
#             echo -e "${BOLD}${CYAN}Lock User${RESET}"
#             echo -n "Enter username: "
#             read -r username
#             lock_user "$username"
#             ;;
#         6) # Unlock User
#             echo -e "${BOLD}${CYAN}Unlock User${RESET}"
#             echo -n "Enter username: "
#             read -r username
#             unlock_user "$username"
#             ;;
#         7) # Set Expiry
#             echo -e "${BOLD}${CYAN}Set Expiry Date${RESET}"
#             echo -n "Enter username: "
#             read -r username
#             echo -n "Enter expiry date (YYYY-MM-DD): "
#             read -r expiry
#             set_expiry "$username" "$expiry"
#             ;;
#         8) # Add Sudo
#             echo -e "${BOLD}${CYAN}Add Sudo Access${RESET}"
#             echo -n "Enter username: "
#             read -r username
#             add_sudo "$username"
#             ;;
#         9) # Remove Sudo
#             echo -e "${BOLD}${CYAN}Remove Sudo Access${RESET}"
#             echo -n "Enter username: "
#             read -r username
#             remove_sudo "$username"
#             ;;
#         10) # Add SSH Key
#             echo -e "${BOLD}${CYAN}Add SSH Key${RESET}"
#             echo -n "Enter username: "
#             read -r username
#             echo -n "Enter SSH public key: "
#             read -r key
#             add_ssh_key "$username" "$key"
#             ;;
#         11) # Remove SSH Key
#             echo -e "${BOLD}${CYAN}Remove SSH Key${RESET}"
#             echo -n "Enter username: "
#             read -r username
#             remove_ssh_key "$username"
#             ;;
#         12) # Back
#             return 0
#             ;;
#     esac
#     
#     echo ""
#     echo -e "${BOLD}${CYAN}Press Enter to continue...${RESET}"
#     read -r
# }

# Menu quản lý Group (DEPRECATED - replaced by view_groups_list + group_detail_view)
# group_management_menu() {
#     local menu_items=(
#         "Create Group"
#         "Delete Group"
#         "List Groups"
#         "Add User to Group"
#         "Remove User from Group"
#         "Set Group Permission"
#         "Back to Main Menu"
#     )
#     
#     local menu_descs=(
#         "Tạo group mới"
#         "Xóa group (phải rỗng)"
#         "Liệt kê tất cả groups (scroll menu)"
#         "Thêm user vào group"
#         "Xóa user khỏi group"
#         "Set permission cho folder (root:group, 775)"
#         "Quay lại menu chính"
#     )
#     
#     page_menu_set_data menu_items menu_descs
#     page_menu_set_page_size 10
#     page_menu_run "Group Management"
#     
#     if [ $PAGE_MENU_CANCELLED -eq 1 ] || [ $PAGE_MENU_RESULT -lt 0 ]; then
#         return 0
#     fi
#     
#     local selected=$PAGE_MENU_RESULT
#     clear
#     
#     case $selected in
#         0) # Create Group
#             echo -e "${BOLD}${CYAN}Create Group${RESET}"
#             echo -n "Enter groupname: "
#             read -r groupname
#             create_group "$groupname"
#             ;;
#         1) # Delete Group
#             echo -e "${BOLD}${CYAN}Delete Group${RESET}"
#             echo -n "Enter groupname: "
#             read -r groupname
#             delete_group "$groupname"
#             ;;
#         2) # List Groups
#             list_groups
#             ;;
#         3) # Add User to Group
#             echo -e "${BOLD}${CYAN}Add User to Group${RESET}"
#             echo -n "Enter username: "
#             read -r username
#             echo -n "Enter groupname: "
#             read -r groupname
#             add_user_group "$username" "$groupname"
#             ;;
#         4) # Remove User from Group
#             echo -e "${BOLD}${CYAN}Remove User from Group${RESET}"
#             echo -n "Enter username: "
#             read -r username
#             echo -n "Enter groupname: "
#             read -r groupname
#             remove_user_group "$username" "$groupname"
#             ;;
#         5) # Set Group Permission
#             echo -e "${BOLD}${CYAN}Set Group Permission${RESET}"
#             echo -n "Enter folder path: "
#             read -r folder
#             echo -n "Enter groupname: "
#             read -r groupname
#             set_group_permission "$folder" "$groupname"
#             ;;
#         6) # Back
#             return 0
#             ;;
#     esac
#     
#     echo ""
#     echo -e "${BOLD}${CYAN}Press Enter to continue...${RESET}"
#     read -r
# }

# ============================================================================
# LIST VIEWS
# ============================================================================

# View Users List
view_users_list() {
    local users=($(db_list_users))
    
    if [ ${#users[@]} -eq 0 ]; then
        clear
        print_warning "Không có user nào trong database!"
        echo ""
        echo -e "${BOLD}${CYAN}Press Enter to continue...${RESET}"
        read -r
        return 0
    fi
    
    # Dùng page_menu để hiển thị danh sách users
    page_menu_init "${users[@]}"
    page_menu_set_page_size 10
    page_menu_run "Danh sách Users"
    
    if [ $PAGE_MENU_CANCELLED -eq 1 ] || [ $PAGE_MENU_RESULT -lt 0 ]; then
        return 0
    fi
    
    local selected_user="${users[$PAGE_MENU_RESULT]}"
    if [ -n "$selected_user" ]; then
        user_detail_view "$selected_user"
    fi
}

# View Groups List
view_groups_list() {
    local groups=($(db_list_groups))
    
    if [ ${#groups[@]} -eq 0 ]; then
        clear
        print_warning "Không có group nào trong database!"
        echo ""
        echo -e "${BOLD}${CYAN}Press Enter to continue...${RESET}"
        read -r
        return 0
    fi
    
    # Dùng page_menu để hiển thị danh sách groups
    page_menu_init "${groups[@]}"
    page_menu_set_page_size 10
    page_menu_run "Danh sách Groups"
    
    if [ $PAGE_MENU_CANCELLED -eq 1 ] || [ $PAGE_MENU_RESULT -lt 0 ]; then
        return 0
    fi
    
    local selected_group="${groups[$PAGE_MENU_RESULT]}"
    if [ -n "$selected_group" ]; then
        group_detail_view "$selected_group"
    fi
}

# ============================================================================
# DETAIL VIEWS
# ============================================================================

# User Detail View
user_detail_view() {
    local username="$1"
    
    if [ -z "$username" ]; then
        print_error "Thiếu tên user!"
        return 1
    fi
    
    if ! check_user_exists "$username"; then
        print_error "User '$username' không tồn tại!"
        echo ""
        echo -e "${BOLD}${CYAN}Press Enter to continue...${RESET}"
        read -r
        return 1
    fi
    
    while true; do
        # Hiển thị thông tin user
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
        
        # Hiển thị với render_table
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
        
        # Menu actions
        local menu_items=(
            "Delete User"
            "Change Password"
            "Lock User"
            "Unlock User"
            "Set Expiry Date"
            "Add Sudo Access"
            "Remove Sudo Access"
            "Add SSH Key"
            "Remove SSH Key"
            "Back to List"
        )
        
        local menu_descs=(
            "Xóa user và home directory"
            "Đổi mật khẩu user (tự động generate)"
            "Khóa tài khoản user"
            "Mở khóa tài khoản user"
            "Đặt ngày hết hạn cho user (YYYY-MM-DD)"
            "Thêm quyền sudo cho user"
            "Xóa quyền sudo của user"
            "Thêm SSH public key cho user"
            "Xóa SSH keys của user"
            "Quay lại danh sách users"
        )
        
        page_menu_set_data menu_items menu_descs
        page_menu_set_page_size 10
        page_menu_run "User Actions: $username"
        
        if [ $PAGE_MENU_CANCELLED -eq 1 ] || [ $PAGE_MENU_RESULT -lt 0 ]; then
            return 0
        fi
        
        local selected=$PAGE_MENU_RESULT
        clear
        
        case $selected in
            0) # Delete User
                echo -e "${BOLD}${CYAN}Delete User: $username${RESET}"
                echo -n "Bạn có chắc chắn muốn xóa user này? (yes/no): "
                read -r confirm
                if [ "$confirm" = "yes" ]; then
                    delete_user "$username"
                    echo ""
                    echo -e "${BOLD}${CYAN}Press Enter to continue...${RESET}"
                    read -r
                    return 0  # Quay lại list sau khi xóa
                fi
                ;;
            1) # Change Password
                change_password "$username"
                echo ""
                echo -e "${BOLD}${CYAN}Press Enter to continue...${RESET}"
                read -r
                ;;
            2) # Lock User
                lock_user "$username"
                echo ""
                echo -e "${BOLD}${CYAN}Press Enter to continue...${RESET}"
                read -r
                ;;
            3) # Unlock User
                unlock_user "$username"
                echo ""
                echo -e "${BOLD}${CYAN}Press Enter to continue...${RESET}"
                read -r
                ;;
            4) # Set Expiry
                echo -e "${BOLD}${CYAN}Set Expiry Date for: $username${RESET}"
                echo -n "Enter expiry date (YYYY-MM-DD): "
                read -r expiry
                if [ -n "$expiry" ]; then
                    set_expiry "$username" "$expiry"
                fi
                echo ""
                echo -e "${BOLD}${CYAN}Press Enter to continue...${RESET}"
                read -r
                ;;
            5) # Add Sudo
                add_sudo "$username"
                echo ""
                echo -e "${BOLD}${CYAN}Press Enter to continue...${RESET}"
                read -r
                ;;
            6) # Remove Sudo
                remove_sudo "$username"
                echo ""
                echo -e "${BOLD}${CYAN}Press Enter to continue...${RESET}"
                read -r
                ;;
            7) # Add SSH Key
                echo -e "${BOLD}${CYAN}Add SSH Key for: $username${RESET}"
                echo -n "Enter SSH public key: "
                read -r key
                if [ -n "$key" ]; then
                    add_ssh_key "$username" "$key"
                fi
                echo ""
                echo -e "${BOLD}${CYAN}Press Enter to continue...${RESET}"
                read -r
                ;;
            8) # Remove SSH Key
                remove_ssh_key "$username"
                echo ""
                echo -e "${BOLD}${CYAN}Press Enter to continue...${RESET}"
                read -r
                ;;
            9) # Back to List
                return 0
                ;;
        esac
    done
}

# Group Detail View
group_detail_view() {
    local groupname="$1"
    
    if [ -z "$groupname" ]; then
        print_error "Thiếu tên group!"
        return 1
    fi
    
    if ! check_group_exists "$groupname"; then
        print_error "Group '$groupname' không tồn tại!"
        echo ""
        echo -e "${BOLD}${CYAN}Press Enter to continue...${RESET}"
        read -r
        return 1
    fi
    
    while true; do
        # Hiển thị thông tin group
        local db_group=$(db_get_group "$groupname")
        if [ -z "$db_group" ]; then
            print_error "Không tìm thấy thông tin group trong database!"
            echo ""
            echo -e "${BOLD}${CYAN}Press Enter to continue...${RESET}"
            read -r
            return 1
        fi
        
        IFS='|' read -r gname gid members created <<< "$db_group"
        
        clear
        print_header "Thông tin Group: $groupname"
        
        local group_table=$(render_table "GROUP INFO" "Field|Value" \
            "Group Name|$gname" \
            "GID|$gid" \
            "Members|${members:-None}" \
            "Created Date|$created")
        echo -e "$group_table"
        echo ""
        
        # Menu actions
        local menu_items=(
            "Delete Group"
            "Add User to Group"
            "Remove User from Group"
            "Set Group Permission"
            "Back to List"
        )
        
        local menu_descs=(
            "Xóa group (phải rỗng)"
            "Thêm user vào group"
            "Xóa user khỏi group"
            "Set permission cho folder (root:group, 775)"
            "Quay lại danh sách groups"
        )
        
        page_menu_set_data menu_items menu_descs
        page_menu_set_page_size 10
        page_menu_run "Group Actions: $groupname"
        
        if [ $PAGE_MENU_CANCELLED -eq 1 ] || [ $PAGE_MENU_RESULT -lt 0 ]; then
            return 0
        fi
        
        local selected=$PAGE_MENU_RESULT
        clear
        
        case $selected in
            0) # Delete Group
                echo -e "${BOLD}${CYAN}Delete Group: $groupname${RESET}"
                echo -n "Bạn có chắc chắn muốn xóa group này? (yes/no): "
                read -r confirm
                if [ "$confirm" = "yes" ]; then
                    delete_group "$groupname"
                    echo ""
                    echo -e "${BOLD}${CYAN}Press Enter to continue...${RESET}"
                    read -r
                    return 0  # Quay lại list sau khi xóa
                fi
                ;;
            1) # Add User to Group
                echo -e "${BOLD}${CYAN}Add User to Group: $groupname${RESET}"
                echo -n "Enter username: "
                read -r username
                if [ -n "$username" ]; then
                    add_user_group "$username" "$groupname"
                fi
                echo ""
                echo -e "${BOLD}${CYAN}Press Enter to continue...${RESET}"
                read -r
                ;;
            2) # Remove User from Group
                echo -e "${BOLD}${CYAN}Remove User from Group: $groupname${RESET}"
                echo -n "Enter username: "
                read -r username
                if [ -n "$username" ]; then
                    remove_user_group "$username" "$groupname"
                fi
                echo ""
                echo -e "${BOLD}${CYAN}Press Enter to continue...${RESET}"
                read -r
                ;;
            3) # Set Group Permission
                echo -e "${BOLD}${CYAN}Set Group Permission for: $groupname${RESET}"
                echo -n "Enter folder path: "
                read -r folder
                if [ -n "$folder" ]; then
                    set_group_permission "$folder" "$groupname"
                fi
                echo ""
                echo -e "${BOLD}${CYAN}Press Enter to continue...${RESET}"
                read -r
                ;;
            4) # Back to List
                return 0
                ;;
        esac
    done
}

# ============================================================================
# MAIN MENU
# ============================================================================

# Menu chính
interactive_menu() {
    while true; do
        local menu_items=(
            "Create User"
            "View Users"
            "Create Group"
            "View Groups"
            "View Logs"
            "Exit"
        )
        
        local menu_descs=(
            "Tạo user mới với home directory và password tự động"
            "Xem danh sách users và quản lý chi tiết"
            "Tạo group mới"
            "Xem danh sách groups và quản lý chi tiết"
            "Xem log file (scroll menu)"
            "Thoát chương trình"
        )
        
        page_menu_set_data menu_items menu_descs
        page_menu_set_page_size 10
        page_menu_run "User & Group Manager"
        
        if [ $PAGE_MENU_CANCELLED -eq 1 ] || [ $PAGE_MENU_RESULT -lt 0 ]; then
            break
        fi
        
        local selected=$PAGE_MENU_RESULT
        
        case $selected in
            0) # Create User
                clear
                echo -e "${BOLD}${CYAN}Create User${RESET}"
                echo -n "Enter username: "
                read -r username
                if [ -n "$username" ]; then
                    create_user "$username"
                    echo ""
                    echo -e "${BOLD}${CYAN}Press Enter to continue...${RESET}"
                    read -r
                fi
                ;;
            1) # View Users
                view_users_list
                ;;
            2) # Create Group
                clear
                echo -e "${BOLD}${CYAN}Create Group${RESET}"
                echo -n "Enter groupname: "
                read -r groupname
                if [ -n "$groupname" ]; then
                    create_group "$groupname"
                    echo ""
                    echo -e "${BOLD}${CYAN}Press Enter to continue...${RESET}"
                    read -r
                fi
                ;;
            3) # View Groups
                view_groups_list
                ;;
            4) # View Logs
                show_log
                ;;
            5) # Exit
                print_success "Cảm ơn bạn đã sử dụng User & Group Manager!"
                exit 0
                ;;
        esac
    done
}
