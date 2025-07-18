#!/bin/bash
# Setup script for JS Error Checker

echo "Installing dependencies for JS Error Checker..."

# Install Python dependencies
pip install -r requirements.txt

# Check if chromedriver is available
if ! command -v chromedriver &> /dev/null; then
    echo "ChromeDriver not found. Installing via webdriver-manager..."
    python -c "from webdriver_manager.chrome import ChromeDriverManager; ChromeDriverManager().install()"
else
    echo "ChromeDriver found: $(which chromedriver)"
fi

# Make the script executable
chmod +x js_error_checker.py

echo "Setup complete!"
echo ""
echo "Usage:"
echo "  python js_error_checker.py <url>"
echo ""
echo "Example:"
echo "  python js_error_checker.py https://google.com"
echo ""
echo "Optional: Set CHROME_PROFILE_PATH environment variable to use a specific Chrome profile"
