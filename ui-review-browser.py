#!/usr/bin/env python3
"""
Browser UI Review Tool - Captures browser screenshots and gets AI feedback
Integrates with Selenium for automated browser testing
"""

import base64
import io
import os
import sys
import time
import argparse
from typing import Optional, Dict, Any, List
from pathlib import Path

try:
    from PIL import Image
    from openai import OpenAI
    from selenium import webdriver
    from selenium.webdriver.common.by import By
    from selenium.webdriver.support.ui import WebDriverWait
    from selenium.webdriver.support import expected_conditions as EC
    from selenium.webdriver.chrome.options import Options as ChromeOptions
    from selenium.webdriver.firefox.options import Options as FirefoxOptions
except ImportError as e:
    print(f"Error: Missing required library. Please install with:")
    print("pip install pillow openai selenium")
    sys.exit(1)


class BrowserUIReviewTool:
    """Tool for capturing browser screenshots and getting AI feedback"""
    
    def __init__(self, api_key: Optional[str] = None, browser: str = "chrome", headless: bool = True):
        """
        Initialize the tool with OpenAI API key and browser
        
        Args:
            api_key: OpenAI API key
            browser: Browser to use (chrome or firefox)
            headless: Run browser in headless mode
        """
        self.api_key = api_key or os.environ.get("OPENAI_API_KEY")
        if not self.api_key:
            raise ValueError("OpenAI API key required. Set OPENAI_API_KEY env var or pass as argument")
        
        self.client = OpenAI(api_key=self.api_key)
        self.driver = None
        self.browser_type = browser.lower()
        self.headless = headless
        
    def start_browser(self, window_size: tuple = (1920, 1080)):
        """Start the browser with specified options"""
        if self.browser_type == "chrome":
            options = ChromeOptions()
            if self.headless:
                options.add_argument("--headless")
            options.add_argument(f"--window-size={window_size[0]},{window_size[1]}")
            options.add_argument("--no-sandbox")
            options.add_argument("--disable-dev-shm-usage")
            self.driver = webdriver.Chrome(options=options)
        elif self.browser_type == "firefox":
            options = FirefoxOptions()
            if self.headless:
                options.add_argument("--headless")
            options.add_argument(f"--width={window_size[0]}")
            options.add_argument(f"--height={window_size[1]}")
            self.driver = webdriver.Firefox(options=options)
        else:
            raise ValueError(f"Unsupported browser: {self.browser_type}")
        
        self.driver.set_window_size(window_size[0], window_size[1])
    
    def stop_browser(self):
        """Stop the browser"""
        if self.driver:
            self.driver.quit()
            self.driver = None
    
    def navigate_to(self, url: str, wait_time: int = 3):
        """
        Navigate to a URL and wait for page load
        
        Args:
            url: URL to navigate to
            wait_time: Time to wait after page load (seconds)
        """
        if not self.driver:
            self.start_browser()
        
        self.driver.get(url)
        time.sleep(wait_time)
    
    def capture_screenshot(self, element_selector: Optional[str] = None) -> Image.Image:
        """
        Capture a screenshot of the browser or specific element
        
        Args:
            element_selector: CSS selector for specific element
        
        Returns:
            PIL Image object
        """
        if not self.driver:
            raise RuntimeError("Browser not started. Call start_browser() first")
        
        if element_selector:
            try:
                element = self.driver.find_element(By.CSS_SELECTOR, element_selector)
                screenshot_bytes = element.screenshot_as_png
            except Exception as e:
                print(f"Warning: Could not find element '{element_selector}', capturing full page")
                screenshot_bytes = self.driver.get_screenshot_as_png()
        else:
            screenshot_bytes = self.driver.get_screenshot_as_png()
        
        return Image.open(io.BytesIO(screenshot_bytes))
    
    def convert_to_webp(self, image: Image.Image, quality: int = 85) -> bytes:
        """Convert PIL Image to WebP format"""
        buffer = io.BytesIO()
        image.save(buffer, format="WEBP", quality=quality, method=6)
        return buffer.getvalue()
    
    def encode_image_base64(self, image_bytes: bytes) -> str:
        """Encode image bytes to base64 string"""
        return base64.b64encode(image_bytes).decode("utf-8")
    
    def get_ai_feedback(
        self,
        image_base64: str,
        url: str,
        prompt: Optional[str] = None,
        model: str = "gpt-4o-mini",
        detail: str = "auto"
    ) -> str:
        """Get AI feedback on the UI screenshot"""
        if not prompt:
            prompt = f"""Please analyze this UI screenshot from {url} and provide feedback on:
1. Overall design and visual hierarchy
2. User experience and usability issues
3. Accessibility concerns (WCAG compliance)
4. Mobile responsiveness indicators
5. Layout and spacing consistency
6. Color scheme and contrast ratios
7. Typography and readability
8. Navigation clarity and intuitiveness
9. Call-to-action effectiveness
10. Loading performance indicators
11. Any broken elements or rendering issues

Be specific and actionable in your feedback. Prioritize the most critical issues."""
        
        try:
            response = self.client.chat.completions.create(
                model=model,
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": prompt},
                            {
                                "type": "image_url",
                                "image_url": {
                                    "url": f"data:image/webp;base64,{image_base64}",
                                    "detail": detail
                                }
                            }
                        ]
                    }
                ],
                max_tokens=1500
            )
            return response.choices[0].message.content
        except Exception as e:
            return f"Error getting AI feedback: {str(e)}"
    
    def review_page(
        self,
        url: str,
        element_selector: Optional[str] = None,
        save_screenshot: Optional[str] = None,
        prompt: Optional[str] = None,
        model: str = "gpt-4o-mini",
        detail: str = "auto",
        wait_time: int = 3,
        auto_save: bool = True
    ) -> Dict[str, Any]:
        """
        Complete page review workflow
        
        Args:
            url: URL to review
            element_selector: Optional CSS selector for specific element
            save_screenshot: Optional path to save the screenshot
            prompt: Custom prompt for AI review
            model: OpenAI model to use
            detail: Image detail level
            wait_time: Time to wait after page load
        
        Returns:
            Dict with feedback and metadata
        """
        pass  # Removed verbose output
        self.navigate_to(url, wait_time)
        
        pass  # Removed verbose output
        image = self.capture_screenshot(element_selector)
        
        pass  # Removed verbose output
        webp_bytes = self.convert_to_webp(image, quality=85)
        
        # Auto-save if no explicit save path provided but auto_save is True
        if not save_screenshot and auto_save:
            # Create screenshots directory if it doesn't exist
            screenshots_dir = Path("screenshots")
            screenshots_dir.mkdir(exist_ok=True)
            # Generate filename from URL
            filename = url.replace("://", "_").replace("/", "_").replace(".", "_")[:50] + ".webp"
            save_screenshot = str(screenshots_dir / filename)
        
        if save_screenshot:
            path = Path(save_screenshot)
            if not path.suffix:
                path = path.with_suffix(".webp")
            with open(path, "wb") as f:
                f.write(webp_bytes)
            pass  # Removed verbose output
        
        image_base64 = self.encode_image_base64(webp_bytes)
        
        pass  # Removed verbose output
        feedback = self.get_ai_feedback(image_base64, url, prompt, model, detail)
        
        return {
            "url": url,
            "feedback": feedback,
            "image_size": len(webp_bytes),
            "image_dimensions": f"{image.width}x{image.height}",
            "model": model,
            "detail": detail,
            "element": element_selector or "full page"
        }
    
    def batch_review(
        self,
        urls: List[str],
        save_dir: Optional[str] = None,
        model: str = "gpt-4o-mini",
        detail: str = "auto"
    ) -> List[Dict[str, Any]]:
        """
        Review multiple URLs in batch
        
        Args:
            urls: List of URLs to review
            save_dir: Optional directory to save screenshots
            model: OpenAI model to use
            detail: Image detail level
        
        Returns:
            List of review results
        """
        results = []
        
        if save_dir:
            save_path = Path(save_dir)
            save_path.mkdir(parents=True, exist_ok=True)
        
        for i, url in enumerate(urls, 1):
            pass  # Removed verbose output
            pass  # Removed verbose output
            
            screenshot_path = None
            if save_dir:
                filename = f"screenshot_{i}_{url.replace('://', '_').replace('/', '_')}.webp"
                screenshot_path = str(save_path / filename)
            
            result = self.review_page(
                url=url,
                save_screenshot=screenshot_path,
                model=model,
                detail=detail
            )
            results.append(result)
        
        return results


def main():
    """CLI interface for the browser UI review tool"""
    parser = argparse.ArgumentParser(
        description="Capture browser screenshots and get AI feedback on UI/UX",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Review a single page
  %(prog)s https://example.com
  
  # Review specific element
  %(prog)s https://example.com --element "#main-content"
  
  # Save screenshot
  %(prog)s https://example.com --save screenshot.webp
  
  # Custom prompt
  %(prog)s https://example.com --prompt "Focus on accessibility"
  
  # Use GPT-4 for detailed analysis
  %(prog)s https://example.com --model gpt-4o
  
  # Batch review multiple URLs
  %(prog)s --batch urls.txt --save-dir screenshots/
  
  # Show browser (not headless)
  %(prog)s https://example.com --headed
"""
    )
    
    parser.add_argument(
        "url",
        nargs="?",
        help="URL to review"
    )
    parser.add_argument(
        "--api-key",
        help="OpenAI API key (or set OPENAI_API_KEY env var)"
    )
    parser.add_argument(
        "--browser",
        choices=["chrome", "firefox"],
        default="chrome",
        help="Browser to use (default: chrome)"
    )
    parser.add_argument(
        "--headed",
        action="store_true",
        help="Show browser (default: headless)"
    )
    parser.add_argument(
        "--element",
        help="CSS selector for specific element to review"
    )
    parser.add_argument(
        "--save",
        help="Save screenshot to file"
    )
    parser.add_argument(
        "--save-dir",
        help="Directory to save screenshots (for batch mode)"
    )
    parser.add_argument(
        "--prompt",
        help="Custom prompt for AI review"
    )
    parser.add_argument(
        "--model",
        default="gpt-4o-mini",
        help="OpenAI model to use (default: gpt-4o-mini)"
    )
    parser.add_argument(
        "--detail",
        choices=["low", "high", "auto"],
        default="auto",
        help="Image detail level (default: auto)"
    )
    parser.add_argument(
        "--wait",
        type=int,
        default=3,
        help="Seconds to wait after page load (default: 3)"
    )
    parser.add_argument(
        "--batch",
        help="File containing URLs to review (one per line)"
    )
    parser.add_argument(
        "--window-size",
        nargs=2,
        type=int,
        default=[1920, 1080],
        metavar=("WIDTH", "HEIGHT"),
        help="Browser window size (default: 1920 1080)"
    )
    
    args = parser.parse_args()
    
    if not args.url and not args.batch:
        parser.error("Either URL or --batch is required")
    
    try:
        # Initialize tool
        tool = BrowserUIReviewTool(
            api_key=args.api_key,
            browser=args.browser,
            headless=not args.headed
        )
        
        # Start browser
        tool.start_browser(window_size=tuple(args.window_size))
        
        try:
            if args.batch:
                # Batch mode
                with open(args.batch, "r") as f:
                    urls = [line.strip() for line in f if line.strip()]
                
                results = tool.batch_review(
                    urls=urls,
                    save_dir=args.save_dir,
                    model=args.model,
                    detail=args.detail
                )
                
                print("\n" + "="*60)
                print("📊 BATCH REVIEW SUMMARY")
                print("="*60)
                for i, result in enumerate(results, 1):
                    print(f"\n[{i}] {result['url']}")
                    print("-" * 40)
                    print(result['feedback'][:500] + "..." if len(result['feedback']) > 500 else result['feedback'])
                print("="*60)
            else:
                # Single page mode
                result = tool.review_page(
                    url=args.url,
                    element_selector=args.element,
                    save_screenshot=args.save,
                    prompt=args.prompt,
                    model=args.model,
                    detail=args.detail,
                    wait_time=args.wait
                )
                
                print(f"\n{result['feedback']}")
        
        finally:
            # Always stop browser
            tool.stop_browser()
    
    except KeyboardInterrupt:
        print("\n❌ Cancelled by user")
        if 'tool' in locals():
            tool.stop_browser()
        sys.exit(1)
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        if 'tool' in locals():
            tool.stop_browser()
        sys.exit(1)


if __name__ == "__main__":
    main()