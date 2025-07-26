# Chrome Profile Export Guide for Ubuntu Linux

This guide provides multiple methods to export your Chrome profile in Ubuntu Linux.

## Method 1: Using the Export Script (Recommended)

### Quick Start
```bash
# List all available profiles
./export_chrome_profile.sh -l

# Export default profile
./export_chrome_profile.sh -d

# Export specific profile
./export_chrome_profile.sh "Profile 1"

# Export all profiles
./export_chrome_profile.sh -a
```

### Script Features
- Lists all available Chrome profiles with their names
- Exports important Chrome data (bookmarks, history, extensions, etc.)
- Creates detailed export information file
- Supports custom output directories
- Handles multiple profiles

## Method 2: Simple Complete Backup

Create a full backup of your entire Chrome configuration:

```bash
./simple_chrome_backup.sh
```

This creates:
- Complete backup directory
- Compressed archive
- Restore instructions

## Method 3: Manual Export

### Location of Chrome Profiles
Chrome profiles are stored in:
```
~/.config/google-chrome/
├── Default/                 # Default profile
├── Profile 1/              # Additional profiles
├── Profile 2/
└── ...
```

### Manual Export Steps

1. **Close Chrome completely**:
   ```bash
   pkill chrome
   ```

2. **Create backup directory**:
   ```bash
   mkdir -p ~/chrome_profile_export
   ```

3. **Copy profile data**:
   ```bash
   # For default profile
   cp -r ~/.config/google-chrome/Default ~/chrome_profile_export/
   
   # For specific profile
   cp -r ~/.config/google-chrome/"Profile 1" ~/chrome_profile_export/
   ```

4. **Important files to backup**:
   - `Bookmarks` - Your saved bookmarks
   - `Preferences` - Chrome settings
   - `History` - Browsing history
   - `Login Data` - Saved passwords (encrypted)
   - `Web Data` - Form data, autofill
   - `Cookies` - Website cookies
   - `Extensions/` - Installed extensions
   - `Local Storage/` - Website data
   - `Session Storage/` - Session data
   - `IndexedDB/` - Database storage

## Method 4: Using Chrome's Built-in Sync

### Enable Chrome Sync
1. Sign in to Chrome with your Google account
2. Go to Settings > You and Google > Sync and Google services
3. Enable "Sync everything" or select specific items
4. Your data will be synced to your Google account

### Restore on Another System
1. Install Chrome
2. Sign in with the same Google account
3. Your data will be automatically synced

## Setting Up Profile for JS Error Checker

To use your Chrome profile with the JS error checker:

```bash
# Run the setup script
./setup_chrome_profile.sh

# Or set manually
export CHROME_PROFILE_PATH="$HOME/.config/google-chrome/Default"

# Test with JS error checker
python js_error_checker.py https://google.com
```

## Restoring Chrome Profile

### From Export Script Backup
1. Close Chrome: `pkill chrome`
2. Copy profile data: `cp -r exported_profile_dir ~/.config/google-chrome/Default/`
3. Fix permissions: `chmod -R 700 ~/.config/google-chrome/Default/`
4. Start Chrome

### From Complete Backup
1. Close Chrome: `pkill chrome`
2. Backup current config: `mv ~/.config/google-chrome ~/.config/google-chrome.backup`
3. Restore backup: `cp -r backup_dir/google-chrome ~/.config/`
4. Fix permissions: `chmod -R 700 ~/.config/google-chrome`
5. Start Chrome

## Important Notes

- **Close Chrome before exporting** to ensure all data is saved
- **Passwords are encrypted** and may not work on different systems
- **Extensions** may need to be re-enabled after restore
- **Some data is system-specific** (like cache files)
- **Permissions matter** - ensure proper file permissions after restore

## Troubleshooting

### Permission Issues
```bash
# Fix Chrome profile permissions
chmod -R 700 ~/.config/google-chrome
```

### Profile Not Loading
```bash
# Reset Chrome profile permissions
chown -R $(whoami):$(whoami) ~/.config/google-chrome
chmod -R 700 ~/.config/google-chrome
```

### Chrome Won't Start
```bash
# Remove lock files
rm -f ~/.config/google-chrome/SingletonLock
rm -f ~/.config/google-chrome/SingletonSocket
```

## Available Scripts

- `export_chrome_profile.sh` - Advanced profile export with options
- `setup_chrome_profile.sh` - Set up environment variable for profile
- `simple_chrome_backup.sh` - Complete Chrome backup
- `js_error_checker.py` - Test JavaScript errors with your profile

## Profile Locations by OS

- **Ubuntu/Linux**: `~/.config/google-chrome/`
- **macOS**: `~/Library/Application Support/Google/Chrome/`
- **Windows**: `%USERPROFILE%\AppData\Local\Google\Chrome\User Data\`
