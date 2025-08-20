# JavaScript Error Checker

Check JavaScript errors on any webpage using Chrome with Selenium.

## Installation

```bash
# Install globally with uvx
uvx install .

# Or run directly
uvx js-error-checker https://example.com
```

## Usage

```bash
# Basic usage
js-error-checker https://example.com

# With Chrome profile
export CHROME_PROFILE_PATH="$HOME/.config/google-chrome/Default"
js-error-checker https://example.com
```

## Chrome Profile Setup

To use your existing Chrome profile:

```bash
# Add to your .bashrc or .zshrc
export CHROME_PROFILE_PATH="$HOME/.config/google-chrome/Default"
```

Find your Chrome profile path:
- Linux: `~/.config/google-chrome/`
- macOS: `~/Library/Application Support/Google/Chrome/`
- Windows: `%USERPROFILE%\AppData\Local\Google\Chrome\User Data\`