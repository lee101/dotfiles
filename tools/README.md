# JavaScript Error Checker

A Python tool that loads web pages in Chrome and collects JavaScript errors for debugging purposes.

## Features

- Loads web pages using Chrome WebDriver
- Collects JavaScript console errors and runtime errors
- Captures unhandled promise rejections
- Supports custom Chrome profiles via environment variables
- Automatic ChromeDriver management using webdriver-manager
- Clean, formatted error output

## Installation

1. Run the setup script:
   ```bash
   ./setup_js_checker.sh
   ```

   This will:
   - Install required Python dependencies (selenium, webdriver-manager)
   - Set up ChromeDriver automatically
   - Make the script executable

## Usage

### Basic Usage
```bash
python js_error_checker.py <url>
```

### Examples
```bash
# Test Google.com
python js_error_checker.py https://google.com

# Test without protocol (will default to https)
python js_error_checker.py google.com

# Test with explicit HTTP
python js_error_checker.py http://localhost:8080/page.html
```

### Using Chrome Profile
Set the `CHROME_PROFILE_PATH` environment variable to use a specific Chrome profile:

```bash
export CHROME_PROFILE_PATH="/path/to/chrome/profile"
python js_error_checker.py https://example.com
```

## Output

The tool provides a summary of errors found:

```
==================================================
ERROR SUMMARY: 2 errors found
==================================================

CONSOLE ERRORS (1):
------------------------------
1. [SEVERE] https://example.com/script.js 42:8 Uncaught ReferenceError: undefinedVariable is not defined
   Source: javascript

JAVASCRIPT ERRORS (1):
------------------------------
1. [error] undefinedVariable is not defined
   File: https://example.com/script.js:42
   Stack: ReferenceError: undefinedVariable is not defined
       at https://example.com/script.js:42:8
```

## Error Types Detected

- **Console Errors**: Errors logged to the browser console
- **JavaScript Runtime Errors**: Uncaught exceptions
- **Unhandled Promise Rejections**: Promises that reject without handling
- **Network Errors**: Failed resource loads (as console errors)

## Demo

Run the demo script to see the tool in action:

```bash
./demo.sh
```

This will test the tool on:
1. Google.com (should have no errors)
2. A local test page with intentional errors
3. Usage with Chrome profile (if configured)

## Requirements

- Python 3.6+
- Chrome browser
- Linux/macOS/Windows

## Files

- `js_error_checker.py` - Main script
- `setup_js_checker.sh` - Setup script
- `demo.sh` - Demo script
- `test_errors.html` - Test page with intentional errors
- `requirements.txt` - Python dependencies
- `README.md` - This file

## Troubleshooting

### ChromeDriver Issues
If you encounter ChromeDriver issues, the webdriver-manager will automatically download and manage the correct version.

### Permission Issues
Make sure the script is executable:
```bash
chmod +x js_error_checker.py
```

### Profile Path Issues
Ensure the Chrome profile path exists and is accessible:
```bash
ls -la "$CHROME_PROFILE_PATH"
```
