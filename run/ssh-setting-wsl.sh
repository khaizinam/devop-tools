#!/bin/bash

# Script metadata
NAME="SSH WSL Setup"
DESC="Configure SSH settings and keys for Windows Subsystem for Linux"

# Source UI components for better display
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

# Save terminal settings and setup Ctrl+C handling
TERM_SETTINGS=$(stty -g)

cleanup_terminal() {
    stty $TERM_SETTINGS 2>/dev/null 2>&1
    echo -ne "\033[?25h"
    echo ""
}

cleanup_and_exit() {
    cleanup_terminal
    echo -e "${BOLD}${YELLOW}⚠️  Interrupted by user${RESET}"
    exit 130
}

trap cleanup_terminal EXIT
trap cleanup_and_exit INT TERM

# Check if SSH agent is running
check_ssh_agent() {
    if [ -n "$SSH_AUTH_SOCK" ] && [ -S "$SSH_AUTH_SOCK" ]; then
        # Check if agent is responding
        if ssh-add -l &>/dev/null; then
            return 0  # SSH agent is running
        fi
    fi
    return 1  # SSH agent is not running
}

# Start SSH agent
start_ssh_agent() {
    echo -e "${BLUE}🔧 Starting SSH agent...${RESET}"
    
    # Start ssh-agent and capture output
    AGENT_OUTPUT=$(ssh-agent -s)
    
    # Extract PID and SOCKET from output
    SSH_AGENT_PID=$(echo "$AGENT_OUTPUT" | grep "SSH_AGENT_PID" | cut -d';' -f1 | cut -d'=' -f2 | tr -d ' ')
    SSH_AUTH_SOCK=$(echo "$AGENT_OUTPUT" | grep "SSH_AUTH_SOCK" | cut -d';' -f2 | cut -d'=' -f2 | tr -d ' ')
    
    # Export to current session
    eval "$AGENT_OUTPUT"
    
    # Add to shell profile for persistence
    if [ -f ~/.bashrc ]; then
        # Remove old agent settings if exist
        sed -i '/SSH_AUTH_SOCK/d' ~/.bashrc
        sed -i '/SSH_AGENT_PID/d' ~/.bashrc
        sed -i '/eval.*ssh-agent/d' ~/.bashrc
        
        # Add new agent settings
        echo "" >> ~/.bashrc
        echo "# SSH Agent" >> ~/.bashrc
        echo "export SSH_AUTH_SOCK=$SSH_AUTH_SOCK" >> ~/.bashrc
        echo "export SSH_AGENT_PID=$SSH_AGENT_PID" >> ~/.bashrc
    fi
    
    if [ -f ~/.zshrc ]; then
        # Remove old agent settings if exist
        sed -i '/SSH_AUTH_SOCK/d' ~/.zshrc
        sed -i '/SSH_AGENT_PID/d' ~/.zshrc
        sed -i '/eval.*ssh-agent/d' ~/.zshrc
        
        # Add new agent settings
        echo "" >> ~/.zshrc
        echo "# SSH Agent" >> ~/.zshrc
        echo "export SSH_AUTH_SOCK=$SSH_AUTH_SOCK" >> ~/.zshrc
        echo "export SSH_AGENT_PID=$SSH_AGENT_PID" >> ~/.zshrc
    fi
    
    echo -e "${GREEN}✅ SSH agent started successfully${RESET}"
    echo ""
}

# Main execution
clear
echo -e "${BOLD}${CYAN}========================================${RESET}"
echo -e "${BOLD}${CYAN}    SSH WSL Setup    ${RESET}"
echo -e "${BOLD}${CYAN}========================================${RESET}"
echo ""

# Ask for confirmation before deleting current SSH and loading new SSH
echo -e "${BOLD}${YELLOW}⚠️  Warning: This will delete your current SSH keys and load new ones from storage${RESET}"
echo -e "${BOLD}${CYAN}Do you want to delete current SSH and load new SSH? (Y/N):${RESET} "
read -r CONFIRM

# Convert to uppercase for comparison
CONFIRM=$(echo "$CONFIRM" | tr '[:lower:]' '[:upper:]')

if [ "$CONFIRM" != "Y" ] && [ "$CONFIRM" != "YES" ]; then
    echo -e "${BOLD}${YELLOW}⚠️  Operation cancelled by user${RESET}"
    exit 0
fi

echo ""

# Check SSH agent status
if check_ssh_agent; then
    echo -e "${BOLD}${GREEN}✅ SSH agent is already running${RESET}"
    echo ""
    
    # Show current loaded keys
    echo -e "${BLUE}📋 Currently loaded SSH keys:${RESET}"
    ssh-add -l || echo -e "${YELLOW}No keys loaded${RESET}"
    echo ""
    
    # Clear existing keys from agent
    echo -e "${YELLOW}🗑️  Clearing existing keys from agent...${RESET}"
    ssh-add -D 2>/dev/null || true
    echo ""
else
    echo -e "${BOLD}${YELLOW}⚠️  SSH agent is not running${RESET}"
    echo -e "${BLUE}🔧 Starting SSH agent...${RESET}"
    echo ""
    start_ssh_agent
fi

# Get project root and SSH source directory
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SSH_SOURCE_DIR="$PROJECT_ROOT/storage/.ssh"

# Check if .ssh directory exists in storage directory
if [ ! -d "$SSH_SOURCE_DIR" ]; then
    echo -e "${BOLD}${RED}❌ Error: .ssh directory not found in storage directory${RESET}"
    echo -e "${YELLOW}Expected location: $SSH_SOURCE_DIR${RESET}"
    echo -e "${YELLOW}Please make sure .ssh folder exists in storage/ directory${RESET}"
    exit 1
fi

# Remove existing SSH keys and config
echo -e "${BLUE}🧹 Cleaning existing SSH directory...${RESET}"
rm -rf ~/.ssh/*
echo -e "${GREEN}✅ Cleaned ~/.ssh directory${RESET}"
echo ""

# Copy SSH keys and config
echo -e "${BLUE}📋 Copying SSH keys and configuration from storage...${RESET}"
cp "$SSH_SOURCE_DIR"/* ~/.ssh/ 2>/dev/null || {
    echo -e "${BOLD}${RED}❌ Error: Failed to copy files from $SSH_SOURCE_DIR${RESET}"
    exit 1
}
echo -e "${GREEN}✅ Files copied successfully${RESET}"
echo ""

# Set correct permissions
echo -e "${BLUE}🔒 Setting correct permissions...${RESET}"
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa 2>/dev/null || true
chmod 644 ~/.ssh/id_rsa.pub 2>/dev/null || true
chmod 600 ~/.ssh/config 2>/dev/null || true
chmod 644 ~/.ssh/known_hosts 2>/dev/null || true
chmod 600 ~/.ssh/*.pem 2>/dev/null || true
echo -e "${GREEN}✅ Permissions set${RESET}"
echo ""

# Add private key to SSH agent
if [ -f ~/.ssh/id_rsa ]; then
    echo -e "${BLUE}🔑 Adding SSH key to agent...${RESET}"
    if ssh-add ~/.ssh/id_rsa; then
        echo -e "${GREEN}✅ SSH key added to agent successfully${RESET}"
    else
        echo -e "${BOLD}${YELLOW}⚠️  Failed to add SSH key to agent (may require passphrase)${RESET}"
    fi
else
    echo -e "${YELLOW}⚠️  No id_rsa file found, skipping ssh-add${RESET}"
fi

echo ""
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo -e "${BOLD}${GREEN}✅ SSH WSL Setup completed!${RESET}"
echo ""
echo -e "${BOLD}${CYAN}📊 SSH Agent Status:${RESET}"
if check_ssh_agent; then
    echo -e "${GREEN}  Status: ${CYAN}Running${RESET}"
    echo -e "${GREEN}  Socket: ${CYAN}$SSH_AUTH_SOCK${RESET}"
    echo -e "${GREEN}  PID: ${CYAN}$SSH_AGENT_PID${RESET}"
    echo ""
    echo -e "${BOLD}${CYAN}📋 Loaded Keys:${RESET}"
    ssh-add -l || echo -e "${YELLOW}No keys loaded${RESET}"
else
    echo -e "${RED}  Status: Not running${RESET}"
fi
echo ""
echo -e "${BOLD}${YELLOW}ℹ️  Note: If SSH agent was just started, you may need to restart your terminal or run:${RESET}"
echo -e "${WHITE}  source ~/.bashrc${RESET}"
echo ""
