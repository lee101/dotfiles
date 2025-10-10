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
            driver_path = ChromeDriverManager().install()
            # Fix for ChromeDriverManager returning wrong file
            if driver_path.endswith('THIRD_PARTY_NOTICES.chromedriver'):
                # Get the directory and look for the actual chromedriver executable
                driver_dir = os.path.dirname(driver_path)
                chromedriver_path = os.path.join(driver_dir, 'chromedriver')
                if os.path.exists(chromedriver_path):
                    driver_path = chromedriver_path
                else:
                    # Try with .exe extension on Windows
                    chromedriver_exe_path = os.path.join(driver_dir, 'chromedriver.exe')
                    if os.path.exists(chromedriver_exe_path):
                        driver_path = chromedriver_exe_path
                    else:
                        print(f"Warning: ChromeDriver not found in expected location: {driver_dir}")
                        print(f"Contents of directory: {os.listdir(driver_dir)}")
            
            print(f"Using ChromeDriver at: {driver_path}")
            service = Service(driver_path)
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
    
    
    def get_page_info(self):
        """Get page status code and content information"""
        try:
            # Get response status using Performance API
            status_script = """
            const perfEntries = performance.getEntriesByType('navigation');
            if (perfEntries.length > 0) {
                // For navigation timing API v2
                return perfEntries[0].responseStatus || null;
            }
            // Try to get from fetch/XHR if available
            const resourceEntries = performance.getEntriesByType('resource');
            for (let entry of resourceEntries) {
                if (entry.name === window.location.href) {
                    return entry.responseStatus || null;
                }
            }
            return null;
            """
            
            # Note: Getting actual HTTP status via Selenium is limited
            # We'll check for common error indicators
            page_source = self.driver.page_source
            page_title = self.driver.title
            body_text = self.driver.find_element(By.TAG_NAME, "body").text if self.driver.find_elements(By.TAG_NAME, "body") else ""
            
            # Check for common error patterns
            is_error = False
            error_indicators = [
                '500', '503', '502', '504', '404', '403', '401',
                'Internal Server Error', 'Bad Gateway', 'Service Unavailable',
                'Gateway Timeout', 'Not Found', 'Forbidden', 'Unauthorized'
            ]
            
            for indicator in error_indicators:
                if indicator in page_title or indicator in body_text[:500]:
                    is_error = True
                    break
            
            # Check if page is very short (under 2000 characters)
            is_short = len(page_source) < 2000
            
            return {
                'is_error': is_error,
                'is_short': is_short,
                'page_source': page_source,
                'body_text': body_text,
                'title': page_title
            }
        except Exception as e:
            print(f"Error getting page info: {e}")
            return {'is_error': False, 'is_short': False, 'page_source': '', 'body_text': '', 'title': ''}
    
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
            
            # Get page info to check if we should print content
            page_info = self.get_page_info()
            
            return console_errors, js_errors, page_info
            
        except TimeoutException:
            print("Timeout waiting for page to load")
            # Try to collect any errors that might have occurred
            try:
                console_errors = self.collect_console_errors()
                js_errors = self.driver.execute_script("return window.jsErrors || [];")
                page_info = self.get_page_info()
                return console_errors, js_errors, page_info
            except:
                return [], [], {'is_error': False, 'is_short': False, 'page_source': '', 'body_text': '', 'title': ''}
        except Exception as e:
            print(f"Error loading page: {e}")
            import traceback
            traceback.print_exc()
            return [], [], {'is_error': False, 'is_short': False, 'page_source': '', 'body_text': '', 'title': ''}
    
    def print_errors(self, console_errors, js_errors, page_info=None):
        """Print collected errors and page content if needed"""
        total_errors = len(console_errors) + len(js_errors)
        
        # Print page content if it's an error page or very short
        if page_info and (page_info['is_error'] or page_info['is_short']):
            print(f"\n{'='*50}")
            print("PAGE CONTENT (Error page or short response detected)")
            print(f"{'='*50}")
            print(f"Title: {page_info['title']}")
            print(f"Content length: {len(page_info['page_source'])} characters")
            print(f"\nBody text:\n{'-'*30}")
            print(page_info['body_text'][:5000])  # Limit to 5000 chars for readability
            if len(page_info['body_text']) > 5000:
                print("\n... (truncated)")
            print(f"{'-'*30}\n")
        
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
            result = self.check_url(url)
            if len(result) == 3:
                console_errors, js_errors, page_info = result
                self.print_errors(console_errors, js_errors, page_info)
            else:
                # Fallback for compatibility
                console_errors, js_errors = result
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
