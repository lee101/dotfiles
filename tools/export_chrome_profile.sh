#!/bin/bash
# Chrome Profile Export Script for Ubuntu Linux

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_usage() {
    echo "Usage: $0 [OPTIONS] [PROFILE_NAME]"
    echo ""
    echo "Options:"
    echo "  -l, --list          List all available Chrome profiles"
    echo "  -d, --default       Export default profile"
    echo "  -a, --all           Export all profiles"
    echo "  -o, --output DIR    Output directory (default: ./chrome_profiles_export)"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -l                           # List all profiles"
    echo "  $0 -d                           # Export default profile"
    echo "  $0 \"Profile 1\"                  # Export specific profile"
    echo "  $0 -a -o /tmp/chrome_backup     # Export all profiles to /tmp"
}

list_profiles() {
    echo -e "${GREEN}Available Chrome profiles:${NC}"
    echo ""
    
    chrome_dir="$HOME/.config/google-chrome"
    
    if [ -d "$chrome_dir/Default" ]; then
        echo -e "  ${YELLOW}Default${NC} (Default profile)"
    fi
    
    for profile in "$chrome_dir"/Profile*; do
        if [ -d "$profile" ]; then
            profile_name=$(basename "$profile")
            # Try to get the profile name from preferences
            if [ -f "$profile/Preferences" ]; then
                display_name=$(grep -o '"name":"[^"]*"' "$profile/Preferences" | head -1 | sed 's/"name":"//g' | sed 's/"//g')
                if [ -n "$display_name" ]; then
                    echo -e "  ${YELLOW}$profile_name${NC} ($display_name)"
                else
                    echo -e "  ${YELLOW}$profile_name${NC}"
                fi
            else
                echo -e "  ${YELLOW}$profile_name${NC}"
            fi
        fi
    done
}

export_profile() {
    local profile_path="$1"
    local profile_name="$2"
    local output_dir="$3"
    
    if [ ! -d "$profile_path" ]; then
        echo -e "${RED}Error: Profile directory not found: $profile_path${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Exporting profile: $profile_name${NC}"
    
    # Create output directory
    local export_path="$output_dir/$profile_name"
    mkdir -p "$export_path"
    
    # Important files to export
    local files_to_export=(
        "Bookmarks"
        "Preferences"
        "History"
        "Login Data"
        "Web Data"
        "Cookies"
        "Extensions"
        "Local Storage"
        "Session Storage"
        "IndexedDB"
        "databases"
        "Local Extension Settings"
        "Sync Extension Settings"
        "Extension Cookies"
        "Extension Scripts"
        "Favicons"
        "Top Sites"
        "Visited Links"
        "Shortcuts"
        "Network Persistent State"
        "TransportSecurity"
        "Certificate Revocation Lists"
        "Origin Bound Certs"
        "QuotaManager"
        "Application Cache"
        "GPUCache"
        "Service Worker"
        "Platform Notifications"
        "Budget Database"
        "Reporting and NEL"
        "Network Action Predictor"
        "Managed Extension Settings"
        "Extension State"
        "shared_proto_db"
        "File System"
        "VideoDecodeStats"
        "Accounts"
        "GCM Store"
        "Sessions"
        "Current Session"
        "Current Tabs"
        "Last Session"
        "Last Tabs"
        "Profile Avatar"
    )
    
    # Export files
    for file in "${files_to_export[@]}"; do
        if [ -e "$profile_path/$file" ]; then
            if [ -d "$profile_path/$file" ]; then
                echo "  Copying directory: $file"
                cp -r "$profile_path/$file" "$export_path/"
            else
                echo "  Copying file: $file"
                cp "$profile_path/$file" "$export_path/"
            fi
        fi
    done
    
    # Create a profile info file
    cat > "$export_path/profile_info.txt" << EOF
Chrome Profile Export Information
================================
Profile Name: $profile_name
Source Path: $profile_path
Export Date: $(date)
Export Host: $(hostname)
Chrome Version: $(google-chrome --version 2>/dev/null || echo "Not available")

To restore this profile:
1. Close Chrome completely
2. Copy the contents of this directory to: ~/.config/google-chrome/Default/
   (or create a new profile directory)
3. Restart Chrome

Important Files Included:
- Bookmarks: Your saved bookmarks
- Preferences: Chrome settings and preferences
- History: Browsing history
- Login Data: Saved passwords (encrypted)
- Web Data: Form data, autofill information
- Cookies: Website cookies
- Extensions: Installed extensions and their data
- Local Storage: Website local storage data
- And many more...

Note: Some files may be encrypted or tied to your specific system.
Passwords and some security-related data may not work on different systems.
EOF
    
    echo -e "${GREEN}Profile exported to: $export_path${NC}"
    echo -e "Total size: $(du -sh "$export_path" | cut -f1)"
}

# Main script
chrome_dir="$HOME/.config/google-chrome"
output_dir="./chrome_profiles_export"

# Check if Chrome directory exists
if [ ! -d "$chrome_dir" ]; then
    echo -e "${RED}Error: Chrome directory not found at $chrome_dir${NC}"
    echo "Make sure Google Chrome is installed and has been run at least once."
    exit 1
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -l|--list)
            list_profiles
            exit 0
            ;;
        -d|--default)
            export_profile "$chrome_dir/Default" "Default" "$output_dir"
            exit 0
            ;;
        -a|--all)
            mkdir -p "$output_dir"
            if [ -d "$chrome_dir/Default" ]; then
                export_profile "$chrome_dir/Default" "Default" "$output_dir"
            fi
            for profile in "$chrome_dir"/Profile*; do
                if [ -d "$profile" ]; then
                    profile_name=$(basename "$profile")
                    export_profile "$profile" "$profile_name" "$output_dir"
                fi
            done
            echo -e "${GREEN}All profiles exported to: $output_dir${NC}"
            exit 0
            ;;
        -o|--output)
            output_dir="$2"
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}"
            print_usage
            exit 1
            ;;
        *)
            # Profile name
            profile_name="$1"
            if [ "$profile_name" = "Default" ]; then
                export_profile "$chrome_dir/Default" "Default" "$output_dir"
            else
                export_profile "$chrome_dir/$profile_name" "$profile_name" "$output_dir"
            fi
            exit 0
            ;;
    esac
    shift
done

# No arguments provided
print_usage
