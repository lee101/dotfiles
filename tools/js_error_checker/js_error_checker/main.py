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
    def __init__(self, profile_path=None):
        self.profile_path = profile_path or os.getenv('CHROME_PROFILE_PATH')
        self.driver = None
        
    def setup_driver(self):
        """Set up Chrome driver with appropriate options"""
        chrome_options = Options()
        
        # Add Chrome profile if specified
        if self.profile_path:
            chrome_options.add_argument(f"--user-data-dir={self.profile_path}")
            print(f"Using Chrome profile: {self.profile_path}")
        
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
    
    def collect_javascript_errors(self):
        """Collect JavaScript errors using custom script injection"""
        try:
            # Inject JavaScript to capture errors
            error_script = """
            window.jsErrors = window.jsErrors || [];
            
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
            
            return window.jsErrors;
            """
            
            # Execute the error capturing script
            self.driver.execute_script(error_script)
            
            # Wait a bit for any async errors
            time.sleep(2)
            
            # Get collected errors
            js_errors = self.driver.execute_script("return window.jsErrors || [];")
            return js_errors
            
        except Exception as e:
            print(f"Error collecting JavaScript errors: {e}")
            return []
    
    def check_url(self, url):
        """Load URL and check for JavaScript errors"""
        print(f"Loading URL: {url}")
        
        try:
            # Load the page
            self.driver.get(url)
            
            # Wait for page to load
            WebDriverWait(self.driver, 10).until(
                EC.presence_of_element_located((By.TAG_NAME, "body"))
            )
            
            print("Page loaded successfully")
            
            # Wait a bit more for dynamic content
            time.sleep(3)
            
            # Collect errors from both sources
            console_errors = self.collect_console_errors()
            js_errors = self.collect_javascript_errors()
            
            return console_errors, js_errors
            
        except TimeoutException:
            print("Timeout waiting for page to load")
            return [], []
        except Exception as e:
            print(f"Error loading page: {e}")
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
                self.driver.quit()

def main():
    # Handle help flag first
    if len(sys.argv) > 1 and sys.argv[1] in ['-h', '--help']:
        print("Usage: js-error-checker <url>")
        print("Example: js-error-checker https://google.com")
        print("\nEnvironment Variables:")
        print("  CHROME_PROFILE_PATH: Path to Chrome profile directory")
        sys.exit(0)
    
    # Then check for correct number of arguments
    if len(sys.argv) != 2:
        print("Usage: js-error-checker <url>")
        print("Example: js-error-checker https://google.com")
        sys.exit(1)
    
    url = sys.argv[1]
    
    # Add protocol if missing
    if not url.startswith(('http://', 'https://')):
        url = 'https://' + url
    
    checker = JSErrorChecker()
    checker.run(url)

if __name__ == "__main__":
    main()
