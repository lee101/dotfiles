#!/usr/bin/env python3

import sys
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager

def check_js_errors(url):
    # Setup Chrome options
    chrome_options = Options()
    chrome_options.add_argument("--headless=new")
    chrome_options.add_argument("--no-sandbox")
    chrome_options.add_argument("--disable-dev-shm-usage")
    chrome_options.add_argument("--disable-gpu")
    chrome_options.set_capability('goog:loggingPrefs', {'browser': 'ALL'})
    
    # Create driver
    service = Service(ChromeDriverManager().install())
    driver = webdriver.Chrome(service=service, options=chrome_options)
    
    try:
        print(f"Loading {url}...")
        driver.get(url)
        
        # Get browser logs
        logs = driver.get_log('browser')
        
        # Filter for errors
        errors = [log for log in logs if log['level'] in ['SEVERE', 'ERROR']]
        
        if errors:
            print(f"\nFound {len(errors)} JavaScript errors:")
            for error in errors:
                print(f"[{error['level']}] {error['message']}")
        else:
            print("\n✅ No JavaScript errors found!")
            
    finally:
        driver.quit()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: jscheck_simple.py <url>")
        sys.exit(1)
    
    url = sys.argv[1]
    if not url.startswith(('http://', 'https://')):
        url = 'https://' + url
    
    check_js_errors(url)