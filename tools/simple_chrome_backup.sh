#!/bin/bash
# Simple Chrome Profile Backup Script

# Create backup directory with timestamp
backup_dir="$HOME/chrome_profile_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$backup_dir"

echo "Creating Chrome profile backup..."

# Copy the entire Chrome directory
cp -r "$HOME/.config/google-chrome" "$backup_dir/"

# Create a compressed archive
cd "$HOME"
tar -czf "chrome_profile_backup_$(date +%Y%m%d_%H%M%S).tar.gz" -C "$backup_dir" .

echo "Backup created:"
echo "  Directory: $backup_dir"
echo "  Archive: $HOME/chrome_profile_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
echo "  Size: $(du -sh "$backup_dir" | cut -f1)"

# Create restore instructions
cat > "$backup_dir/RESTORE_INSTRUCTIONS.txt" << EOF
Chrome Profile Restore Instructions
==================================

To restore this Chrome profile backup:

1. Close Chrome completely:
   pkill chrome

2. Backup your current Chrome directory (optional):
   mv ~/.config/google-chrome ~/.config/google-chrome.backup

3. Restore the backup:
   cp -r google-chrome ~/.config/

4. Fix permissions:
   chmod -R 700 ~/.config/google-chrome

5. Start Chrome

Alternative: Restore specific profile
====================================

To restore only a specific profile:

1. Extract the profile you want from: google-chrome/Default/ or google-chrome/Profile X/
2. Copy to: ~/.config/google-chrome/Default/ (or create new profile directory)
3. Fix permissions: chmod -R 700 ~/.config/google-chrome/Default/

Important Files:
- Bookmarks: Your saved bookmarks
- Preferences: Chrome settings
- History: Browsing history  
- Login Data: Saved passwords
- Web Data: Form data, autofill
- Cookies: Website cookies
- Extensions/: Installed extensions
- Local Storage/: Website data
- And many more...

Backup created on: $(date)
System: $(hostname)
EOF

echo ""
echo "Restore instructions created: $backup_dir/RESTORE_INSTRUCTIONS.txt"
