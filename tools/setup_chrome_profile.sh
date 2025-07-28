#!/bin/bash
# Script to set up Chrome profile environment variable

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Chrome Profile Environment Setup${NC}"
echo ""

# Default Chrome directory
CHROME_DIR="$HOME/.config/google-chrome"

# Check if Chrome directory exists
if [ ! -d "$CHROME_DIR" ]; then
    echo "Chrome directory not found at $CHROME_DIR"
    echo "Make sure Google Chrome is installed and has been run at least once."
    exit 1
fi

echo "Available Chrome profiles:"
echo ""

# List available profiles
profiles=()
profile_paths=()

if [ -d "$CHROME_DIR/Default" ]; then
    profiles+=("Default")
    profile_paths+=("$CHROME_DIR/Default")
    echo "  1) Default (Default profile)"
fi

counter=2
for profile in "$CHROME_DIR"/Profile*; do
    if [ -d "$profile" ]; then
        profile_name=$(basename "$profile")
        profiles+=("$profile_name")
        profile_paths+=("$profile")
        
        # Try to get the profile name from preferences
        if [ -f "$profile/Preferences" ]; then
            display_name=$(grep -o '"name":"[^"]*"' "$profile/Preferences" | head -1 | sed 's/"name":"//g' | sed 's/"//g')
            if [ -n "$display_name" ]; then
                echo "  $counter) $profile_name ($display_name)"
            else
                echo "  $counter) $profile_name"
            fi
        else
            echo "  $counter) $profile_name"
        fi
        ((counter++))
    fi
done

echo ""
echo -n "Select a profile number (or press Enter for Default): "
read choice

# Default to profile 1 (Default) if no choice
if [ -z "$choice" ]; then
    choice=1
fi

# Validate choice
if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#profiles[@]} ]; then
    echo "Invalid choice. Using Default profile."
    choice=1
fi

# Get selected profile
selected_profile="${profiles[$((choice-1))]}"
selected_path="${profile_paths[$((choice-1))]}"

echo ""
echo -e "${GREEN}Selected profile: $selected_profile${NC}"
echo -e "${GREEN}Profile path: $selected_path${NC}"
echo ""

# Add to bashrc
echo "# Chrome profile environment variable" >> ~/.bashrc
echo "export CHROME_PROFILE_PATH=\"$selected_path\"" >> ~/.bashrc

# Add to zshrc if it exists
if [ -f ~/.zshrc ]; then
    echo "# Chrome profile environment variable" >> ~/.zshrc
    echo "export CHROME_PROFILE_PATH=\"$selected_path\"" >> ~/.zshrc
fi

# Set for current session
export CHROME_PROFILE_PATH="$selected_path"

echo -e "${YELLOW}Environment variable set!${NC}"
echo ""
echo "To use immediately in this session:"
echo "  export CHROME_PROFILE_PATH=\"$selected_path\""
echo ""
echo "For new sessions, the variable has been added to your shell configuration."
echo ""
echo "Test with the JS error checker:"
echo "  cd /home/lee/code/dotfiles/tools"
echo "  python js_error_checker.py https://google.com"
echo ""
echo "Or check the current value:"
echo "  echo \$CHROME_PROFILE_PATH"
