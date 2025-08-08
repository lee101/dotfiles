#!/usr/bin/env python3
"""
JavaScript Error Checker Tool

This script loads a web URL in Chrome using a local profile (configured via ENV var),
collects any JavaScript errors, prints them out, and then exits the browser.

Usage:
    js-error-checker <url>
    
Environment Variables:
    CHROME_PROFILE_PATH: Path to the Chrome profile directory (optional)
"""

import sys
import os
import time
import subprocess
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException, WebDriverException
from webdriver_manager.chrome import ChromeDriverManager

class JSErrorChecker:
    def __init__(self, profile_path=None, show_window=False):
        self.profile_path = profile_path or os.getenv('CHROME_PROFILE_PATH')
        self.show_window = show_window
        self.driver = None
        self.temp_profile = None
        
    def setup_driver(self):
        """Set up Chrome driver with appropriate options"""
        chrome_options = Options()
        
        # Add Chrome profile if specified - use a temp copy to avoid locks
        if self.profile_path:
            import tempfile
            import shutil
            # Create a temporary copy of the profile to avoid lock issues
            self.temp_profile = tempfile.mkdtemp(prefix="chrome_profile_")
            print(f"Creating temporary profile copy at: {self.temp_profile}")
            try:
                # Only copy essential directories, skip lock files
                for item in ['Default', 'Local State']:
                    src = os.path.join(self.profile_path, item)
                    if os.path.exists(src):
                        if os.path.isdir(src):
                            shutil.copytree(src, os.path.join(self.temp_profile, item), 
                                          ignore=shutil.ignore_patterns('SingletonLock', 'SingletonCookie', 'SingletonSocket'))
                        else:
                            shutil.copy2(src, self.temp_profile)
            except Exception as e:
                print(f"Warning: Could not copy profile data: {e}")
            
            chrome_options.add_argument(f"--user-data-dir={self.temp_profile}")
            print(f"Using temporary Chrome profile: {self.temp_profile}")
        
        # Run in headless mode unless explicitly showing window
        if not self.show_window:
            chrome_options.add_argument("--headless=new")
            chrome_options.add_argument("--disable-blink-features=AutomationControlled")
            print("Running in headless mode (no visible window)")
        
        # Options to prevent window from stealing focus (popunder behavior)
        chrome_options.add_argument("--no-first-run")
        chrome_options.add_argument("--no-default-browser-check")
        chrome_options.add_argument("--disable-popup-blocking")
        chrome_options.add_argument("--disable-translate")
        chrome_options.add_argument("--disable-default-apps")
        chrome_options.add_argument("--disable-background-timer-throttling")
        chrome_options.add_argument("--disable-renderer-backgrounding")
        chrome_options.add_argument("--disable-device-discovery-notifications")
        
        # Additional Chrome options for better error collection
        chrome_options.add_argument("--no-sandbox")
        chrome_options.add_argument("--disable-dev-shm-usage")
        chrome_options.add_argument("--disable-gpu")
        chrome_options.add_argument("--remote-debugging-port=9222")
        chrome_options.add_argument("--enable-logging")
        chrome_options.add_argument("--log-level=0")
        chrome_options.add_argument("--v=1")
        
        # Enable logging capabilities
        chrome_options.set_capability('goog:loggingPrefs', {
            'browser': 'ALL',
            'performance': 'ALL'
        })
        
        try:
            # Use webdriver-manager to handle ChromeDriver automatically
            service = Service(ChromeDriverManager().install())
            self.driver = webdriver.Chrome(service=service, options=chrome_options)
            print("Chrome driver initialized successfully")
            
            # Only minimize if showing window
            if self.show_window:
                # Minimize window and send to background to prevent focus stealing
                self.driver.minimize_window()
                
                # Use xdotool to ensure window doesn't steal focus (Linux only)
                try:
                    # Get the window ID of the Chrome instance
                    window_title = self.driver.title or "Chrome"
                    subprocess.run(['xdotool', 'search', '--name', window_title, 'windowminimize'], 
                                 capture_output=True, check=False)
                    # Switch focus back to the current window
                    subprocess.run(['xdotool', 'getactivewindow', 'windowfocus'], 
                                 capture_output=True, check=False)
                except:
                    # xdotool not available or command failed, that's okay
                    pass
                
        except WebDriverException as e:
            print(f"Error initializing Chrome driver: {e}")
            sys.exit(1)
    
    def collect_console_errors(self):
        """Collect JavaScript console errors"""
        try:
            # Get browser logs
            logs = self.driver.get_log('browser')
            errors = []
            
            for log in logs:
                if log['level'] in ['SEVERE', 'ERROR']:
                    errors.append({
                        'level': log['level'],
                        'message': log['message'],
                        'timestamp': log['timestamp'],
                        'source': log.get('source', 'unknown')
                    })
            
            return errors
        except Exception as e:
            print(f"Error collecting console logs: {e}")
            return []
    
    
    def check_url(self, url):
        """Load URL and check for JavaScript errors"""
        print(f"Loading URL: {url}")
        
        try:
            # First inject error capturing script before navigation
            inject_script = """
            window.jsErrors = [];
            
            // Override console.error to capture errors
            const originalConsoleError = console.error;
            console.error = function(...args) {
                window.jsErrors.push({
                    type: 'console.error',
                    message: args.join(' '),
                    timestamp: Date.now(),
                    stack: new Error().stack
                });
                originalConsoleError.apply(console, args);
            };
            
            // Capture unhandled errors
            window.addEventListener('error', function(event) {
                window.jsErrors.push({
                    type: 'error',
                    message: event.message,
                    filename: event.filename,
                    lineno: event.lineno,
                    colno: event.colno,
                    stack: event.error ? event.error.stack : null,
                    timestamp: Date.now()
                });
            });
            
            // Capture unhandled promise rejections
            window.addEventListener('unhandledrejection', function(event) {
                window.jsErrors.push({
                    type: 'unhandledrejection',
                    message: event.reason ? event.reason.toString() : 'Unknown promise rejection',
                    timestamp: Date.now()
                });
            });
            """
            
            # Navigate to about:blank first to inject script
            self.driver.get("about:blank")
            self.driver.execute_script(inject_script)
            
            # Now load the actual page
            print(f"Navigating to: {url}")
            self.driver.get(url)
            
            # Wait for page to load with shorter timeout
            try:
                WebDriverWait(self.driver, 5).until(
                    EC.presence_of_element_located((By.TAG_NAME, "body"))
                )
                print("Page loaded successfully")
            except TimeoutException:
                print("Warning: Page load timeout, but continuing to collect errors")
            
            # Get current URL to verify navigation
            current_url = self.driver.current_url
            print(f"Current URL: {current_url}")
            
            # Wait a bit more for dynamic content and errors to accumulate
            time.sleep(3)
            
            # Collect errors from both sources
            console_errors = self.collect_console_errors()
            js_errors = self.driver.execute_script("return window.jsErrors || [];")
            
            print(f"Found {len(console_errors)} console errors and {len(js_errors)} JS errors")
            
            return console_errors, js_errors
            
        except TimeoutException:
            print("Timeout waiting for page to load")
            # Try to collect any errors that might have occurred
            try:
                console_errors = self.collect_console_errors()
                js_errors = self.driver.execute_script("return window.jsErrors || [];")
                return console_errors, js_errors
            except:
                return [], []
        except Exception as e:
            print(f"Error loading page: {e}")
            import traceback
            traceback.print_exc()
            return [], []
    
    def print_errors(self, console_errors, js_errors):
        """Print collected errors in a formatted way"""
        total_errors = len(console_errors) + len(js_errors)
        
        print(f"\n{'='*50}")
        print(f"ERROR SUMMARY: {total_errors} errors found")
        print(f"{'='*50}")
        
        if console_errors:
            print(f"\nCONSOLE ERRORS ({len(console_errors)}):")
            print("-" * 30)
            for i, error in enumerate(console_errors, 1):
                print(f"{i}. [{error['level']}] {error['message']}")
                if error.get('source'):
                    print(f"   Source: {error['source']}")
                print()
        
        if js_errors:
            print(f"\nJAVASCRIPT ERRORS ({len(js_errors)}):")
            print("-" * 30)
            for i, error in enumerate(js_errors, 1):
                print(f"{i}. [{error['type']}] {error['message']}")
                if error.get('filename'):
                    print(f"   File: {error['filename']}:{error.get('lineno', 'unknown')}")
                if error.get('stack'):
                    print(f"   Stack: {error['stack'][:200]}...")
                print()
        
        if not console_errors and not js_errors:
            print("\n✅ No JavaScript errors found!")
    
    def run(self, url):
        """Main execution method"""
        try:
            self.setup_driver()
            console_errors, js_errors = self.check_url(url)
            self.print_errors(console_errors, js_errors)
            
        finally:
            if self.driver:
                print("\nClosing browser...")
                try:
                    self.driver.quit()
                except:
                    pass
            
            # Clean up temporary profile
            if self.temp_profile and os.path.exists(self.temp_profile):
                import shutil
                try:
                    shutil.rmtree(self.temp_profile)
                    print(f"Cleaned up temporary profile: {self.temp_profile}")
                except Exception as e:
                    print(f"Warning: Could not clean up temp profile: {e}")

def main():
    import argparse
    
    # Handle help before initializing anything
    if len(sys.argv) > 1 and sys.argv[1] in ['-h', '--help']:
        print("Usage: js-error-checker [options] <url>")
        print("\nPositional arguments:")
        print("  url                   URL to check for JavaScript errors")
        print("\nOptional arguments:")
        print("  -h, --help           Show this help message and exit")
        print("  --show-window        Show Chrome window (default: headless mode)")
        print("\nEnvironment Variables:")
        print("  CHROME_PROFILE_PATH  Path to Chrome profile directory")
        print(f"                       Current: {os.getenv('CHROME_PROFILE_PATH', 'Not set')}")
        print("\nExamples:")
        print("  js-error-checker https://google.com")
        print("  js-error-checker --show-window https://example.com")
        sys.exit(0)
    
    parser = argparse.ArgumentParser(description='JavaScript Error Checker Tool', add_help=False)
    parser.add_argument('url', nargs='?', help='URL to check for JavaScript errors')
    parser.add_argument('--show-window', action='store_true', 
                        help='Show Chrome window (default: headless mode)')
    parser.add_argument('-h', '--help', action='store_true', help='Show help message')
    
    args = parser.parse_args()
    
    # Check if URL is provided
    if not args.url:
        print("Error: URL is required")
        print("Usage: js-error-checker [options] <url>")
        print("Try 'js-error-checker --help' for more information.")
        sys.exit(1)
    
    url = args.url
    
    # Add protocol if missing
    if not url.startswith(('http://', 'https://')):
        url = 'https://' + url
    
    checker = JSErrorChecker(show_window=args.show_window)
    checker.run(url)

if __name__ == "__main__":
    main()
