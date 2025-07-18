#!/bin/bash
# Chrome Profile Manager - All-in-one script

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_menu() {
    echo -e "${GREEN}Chrome Profile Manager for Ubuntu Linux${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo ""
    echo "Choose an option:"
    echo ""
    echo -e "${YELLOW}1)${NC} List all Chrome profiles"
    echo -e "${YELLOW}2)${NC} Export default profile"
    echo -e "${YELLOW}3)${NC} Export specific profile"
    echo -e "${YELLOW}4)${NC} Export all profiles"
    echo -e "${YELLOW}5)${NC} Create complete Chrome backup"
    echo -e "${YELLOW}6)${NC} Setup Chrome profile environment variable"
    echo -e "${YELLOW}7)${NC} Test JS error checker with profile"
    echo -e "${YELLOW}8)${NC} Show manual export instructions"
    echo -e "${YELLOW}9)${NC} Show Chrome profile locations"
    echo -e "${YELLOW}0)${NC} Exit"
    echo ""
    echo -n "Enter your choice [0-9]: "
}

list_profiles() {
    echo -e "${GREEN}Listing Chrome profiles...${NC}"
    echo ""
    ./export_chrome_profile.sh -l
}

export_default() {
    echo -e "${GREEN}Exporting default profile...${NC}"
    echo ""
    ./export_chrome_profile.sh -d
}

export_specific() {
    echo -e "${GREEN}Available profiles:${NC}"
    ./export_chrome_profile.sh -l
    echo ""
    echo -n "Enter profile name (e.g., 'Profile 1'): "
    read profile_name
    if [ -n "$profile_name" ]; then
        ./export_chrome_profile.sh "$profile_name"
    else
        echo -e "${RED}No profile name provided.${NC}"
    fi
}

export_all() {
    echo -e "${GREEN}Exporting all profiles...${NC}"
    echo ""
    ./export_chrome_profile.sh -a
}

create_backup() {
    echo -e "${GREEN}Creating complete Chrome backup...${NC}"
    echo ""
    ./simple_chrome_backup.sh
}

setup_env() {
    echo -e "${GREEN}Setting up Chrome profile environment...${NC}"
    echo ""
    ./setup_chrome_profile.sh
}

test_js_checker() {
    echo -e "${GREEN}Testing JS error checker...${NC}"
    echo ""
    if [ -n "$CHROME_PROFILE_PATH" ]; then
        echo -e "Using profile: ${YELLOW}$CHROME_PROFILE_PATH${NC}"
    else
        echo -e "${YELLOW}No CHROME_PROFILE_PATH set. Using default Chrome behavior.${NC}"
    fi
    echo ""
    echo -n "Enter URL to test (default: google.com): "
    read test_url
    if [ -z "$test_url" ]; then
        test_url="google.com"
    fi
    echo ""
    python js_error_checker.py "$test_url"
}

show_manual_instructions() {
    echo -e "${GREEN}Manual Chrome Profile Export Instructions${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""
    echo -e "${YELLOW}1. Close Chrome completely:${NC}"
    echo "   pkill chrome"
    echo ""
    echo -e "${YELLOW}2. Chrome profile locations:${NC}"
    echo "   Default profile: ~/.config/google-chrome/Default/"
    echo "   Other profiles: ~/.config/google-chrome/Profile*/"
    echo ""
    echo -e "${YELLOW}3. Export profile:${NC}"
    echo "   cp -r ~/.config/google-chrome/Default ~/my_chrome_backup/"
    echo ""
    echo -e "${YELLOW}4. Important files to backup:${NC}"
    echo "   - Bookmarks (bookmarks)"
    echo "   - Preferences (settings)"
    echo "   - History (browsing history)"
    echo "   - Login Data (saved passwords)"
    echo "   - Web Data (form data, autofill)"
    echo "   - Extensions/ (installed extensions)"
    echo "   - Local Storage/ (website data)"
    echo ""
    echo -e "${YELLOW}5. Restore profile:${NC}"
    echo "   cp -r ~/my_chrome_backup ~/.config/google-chrome/Default/"
    echo "   chmod -R 700 ~/.config/google-chrome/Default/"
}

show_locations() {
    echo -e "${GREEN}Chrome Profile Locations${NC}"
    echo -e "${BLUE}========================${NC}"
    echo ""
    echo -e "${YELLOW}Ubuntu/Linux:${NC}"
    echo "   ~/.config/google-chrome/"
    echo ""
    echo -e "${YELLOW}macOS:${NC}"
    echo "   ~/Library/Application Support/Google/Chrome/"
    echo ""
    echo -e "${YELLOW}Windows:${NC}"
    echo "   %USERPROFILE%\\AppData\\Local\\Google\\Chrome\\User Data\\"
    echo ""
    echo -e "${YELLOW}Current system profiles:${NC}"
    if [ -d "$HOME/.config/google-chrome" ]; then
        ls -la "$HOME/.config/google-chrome" | grep "^d" | grep -E "(Default|Profile)" | while read -r line; do
            echo "   $line"
        done
    else
        echo "   Chrome directory not found"
    fi
}

# Main loop
while true; do
    show_menu
    read choice
    echo ""
    
    case $choice in
        1)
            list_profiles
            ;;
        2)
            export_default
            ;;
        3)
            export_specific
            ;;
        4)
            export_all
            ;;
        5)
            create_backup
            ;;
        6)
            setup_env
            ;;
        7)
            test_js_checker
            ;;
        8)
            show_manual_instructions
            ;;
        9)
            show_locations
            ;;
        0)
            echo -e "${GREEN}Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option. Please try again.${NC}"
            ;;
    esac
    
    echo ""
    echo -e "${BLUE}Press Enter to continue...${NC}"
    read
    clear
done
