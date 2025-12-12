#!/bin/bash

# ============================================================================
# User & Group Manager Script
# ============================================================================
# Script quản lý user và group với database storage và UI core
# Tác giả: Khaizinam
# Ngày tạo: 2024
# ============================================================================

# Script metadata
NAME="User & Group Manager"
DESC="Quản lý user và group với database storage và UI tương tác"

# Source UI components
# Store SCRIPT_DIR in a separate variable to avoid conflicts
USRMGR_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source service files theo thứ tự dependency
# 1. Utils (base functions)
if [ -f "$USRMGR_SCRIPT_DIR/../src/usermgr/utils.sh" ]; then
    source "$USRMGR_SCRIPT_DIR/../src/usermgr/utils.sh"
else
    echo "Error: utils.sh not found" >&2
    exit 1
fi

# 2. Database functions
if [ -f "$USRMGR_SCRIPT_DIR/../src/usermgr/db.sh" ]; then
    source "$USRMGR_SCRIPT_DIR/../src/usermgr/db.sh"
else
    echo "Error: db.sh not found" >&2
    exit 1
fi

# 3. User management functions
if [ -f "$USRMGR_SCRIPT_DIR/../src/usermgr/user.sh" ]; then
    source "$USRMGR_SCRIPT_DIR/../src/usermgr/user.sh"
else
    echo "Error: user.sh not found" >&2
    exit 1
fi

# 4. Group management functions
if [ -f "$USRMGR_SCRIPT_DIR/../src/usermgr/group.sh" ]; then
    source "$USRMGR_SCRIPT_DIR/../src/usermgr/group.sh"
else
    echo "Error: group.sh not found" >&2
    exit 1
fi

# 5. Menu functions
if [ -f "$USRMGR_SCRIPT_DIR/../src/usermgr/menu.sh" ]; then
    source "$USRMGR_SCRIPT_DIR/../src/usermgr/menu.sh"
else
    echo "Error: menu.sh not found" >&2
    exit 1
fi

# ============================================================================
# HELP FUNCTION
# ============================================================================

show_help() {
    print_header "User & Group Manager - Help"
    echo ""
    echo -e "${BOLD}${CYAN}Usage:${RESET}"
    echo "  $0 [command] [arguments]"
    echo "  $0                    # Chạy interactive menu"
    echo ""
    echo -e "${BOLD}${CYAN}Basic Commands:${RESET}"
    echo "  create-user <username>              Tạo user mới"
    echo "  delete-user <username>              Xóa user"
    echo "  create-group <groupname>            Tạo group mới"
    echo "  delete-group <groupname>            Xóa group"
    echo "  add-user-group <user> <group>       Thêm user vào group"
    echo "  remove-user-group <user> <group>    Xóa user khỏi group"
    echo "  set-group-permission <folder> <group>  Set permission (root:group, 775)"
    echo "  list-users                          Liệt kê users"
    echo "  list-groups                         Liệt kê groups"
    echo "  show-log                            Hiển thị log"
    echo ""
    echo -e "${BOLD}${CYAN}Extended Commands:${RESET}"
    echo "  change-password <username>          Đổi mật khẩu"
    echo "  lock-user <username>                Khóa user"
    echo "  unlock-user <username>              Mở khóa user"
    echo "  set-expiry <username> <YYYY-MM-DD>  Đặt ngày hết hạn"
    echo "  add-sudo <username>                 Thêm quyền sudo"
    echo "  remove-sudo <username>              Xóa quyền sudo"
    echo "  add-ssh-key <username> <key>        Thêm SSH key"
    echo "  remove-ssh-key <username>           Xóa SSH key"
    echo "  show-user-info <username>           Hiển thị thông tin user"
    echo ""
    echo -e "${BOLD}${CYAN}Options:${RESET}"
    echo "  -h, --help                          Hiển thị help này"
    echo ""
}

# ============================================================================
# MAIN FUNCTION
# ============================================================================

main() {
    # Kiểm tra quyền root
    check_root
    
    # Khởi tạo database
    db_init
    
    # Parse arguments
    if [ $# -eq 0 ]; then
        # Không có argument -> chạy interactive menu
        interactive_menu
        exit 0
    fi
    
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        create-user)
            create_user "$2"
            ;;
        delete-user)
            delete_user "$2"
            ;;
        create-group)
            create_group "$2"
            ;;
        delete-group)
            delete_group "$2"
            ;;
        add-user-group)
            add_user_group "$2" "$3"
            ;;
        remove-user-group)
            remove_user_group "$2" "$3"
            ;;
        set-group-permission)
            set_group_permission "$2" "$3"
            ;;
        list-users)
            list_users
            ;;
        list-groups)
            list_groups
            ;;
        show-log)
            show_log
            ;;
        change-password)
            change_password "$2"
            ;;
        lock-user)
            lock_user "$2"
            ;;
        unlock-user)
            unlock_user "$2"
            ;;
        set-expiry)
            set_expiry "$2" "$3"
            ;;
        add-sudo)
            add_sudo "$2"
            ;;
        remove-sudo)
            remove_sudo "$2"
            ;;
        add-ssh-key)
            add_ssh_key "$2" "$3"
            ;;
        remove-ssh-key)
            remove_ssh_key "$2"
            ;;
        show-user-info)
            show_user_info "$2"
            ;;
        *)
            print_error "Lệnh không hợp lệ: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Chạy main function
main "$@"
