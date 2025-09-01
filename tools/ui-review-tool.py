#!/usr/bin/env python3
"""
UI Review Tool - Captures screenshots and gets AI feedback on UI/UX
"""

import base64
import io
import os
import sys
import argparse
from typing import Optional, Dict, Any
from pathlib import Path

# Try to import required libraries
try:
    from PIL import Image, ImageGrab
    import mss
    from openai import OpenAI
except ImportError as e:
    print(f"Error: Missing required library. Please install with:")
    print("pip install pillow mss openai")
    sys.exit(1)


class UIReviewTool:
    """Tool for capturing screenshots and getting AI feedback on UI"""
    
    def __init__(self, api_key: Optional[str] = None):
        """Initialize the tool with OpenAI API key"""
        self.api_key = api_key or os.environ.get("OPENAI_API_KEY")
        if not self.api_key:
            raise ValueError("OpenAI API key required. Set OPENAI_API_KEY env var or pass as argument")
        
        self.client = OpenAI(api_key=self.api_key)
        self.screenshot_tool = mss.mss()
    
    def capture_screenshot(self, region: Optional[Dict[str, int]] = None) -> Image.Image:
        """
        Capture a screenshot of the screen or specific region
        
        Args:
            region: Optional dict with keys 'left', 'top', 'width', 'height'
        
        Returns:
            PIL Image object
        """
        if region:
            # Capture specific region
            monitor = {
                "left": region.get("left", 0),
                "top": region.get("top", 0),
                "width": region.get("width", 800),
                "height": region.get("height", 600)
            }
        else:
            # Capture primary monitor
            monitor = self.screenshot_tool.monitors[1]
        
        screenshot = self.screenshot_tool.grab(monitor)
        img = Image.frombytes("RGB", screenshot.size, screenshot.bgra, "raw", "BGRX")
        return img
    
    def convert_to_webp(self, image: Image.Image, quality: int = 85) -> bytes:
        """
        Convert PIL Image to WebP format with specified quality
        
        Args:
            image: PIL Image object
            quality: WebP quality (1-100, default 85)
        
        Returns:
            WebP image as bytes
        """
        buffer = io.BytesIO()
        image.save(buffer, format="WEBP", quality=quality, method=6)
        return buffer.getvalue()
    
    def encode_image_base64(self, image_bytes: bytes) -> str:
        """
        Encode image bytes to base64 string
        
        Args:
            image_bytes: Image as bytes
        
        Returns:
            Base64 encoded string
        """
        return base64.b64encode(image_bytes).decode("utf-8")
    
    def get_ai_feedback(
        self,
        image_base64: str,
        prompt: Optional[str] = None,
        model: str = "gpt-4o-mini",
        detail: str = "auto"
    ) -> str:
        """
        Get AI feedback on the UI screenshot
        
        Args:
            image_base64: Base64 encoded image
            prompt: Custom prompt for the AI review
            model: OpenAI model to use (default: gpt-4o-mini for efficiency)
            detail: Image detail level (low, high, auto)
        
        Returns:
            AI feedback text
        """
        if not prompt:
            prompt = """Please analyze this UI screenshot and provide feedback on:
1. Overall design and visual hierarchy
2. User experience and usability issues
3. Accessibility concerns
4. Layout and spacing
5. Color scheme and contrast
6. Typography and readability
7. Any potential improvements or suggestions

Be specific and actionable in your feedback."""
        
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
                max_tokens=1000
            )
            return response.choices[0].message.content
        except Exception as e:
            return f"Error getting AI feedback: {str(e)}"
    
    def review_ui(
        self,
        region: Optional[Dict[str, int]] = None,
        save_screenshot: Optional[str] = None,
        prompt: Optional[str] = None,
        model: str = "gpt-4o-mini",
        detail: str = "auto",
        auto_save: bool = True
    ) -> Dict[str, Any]:
        """
        Complete UI review workflow
        
        Args:
            region: Optional screen region to capture
            save_screenshot: Optional path to save the screenshot
            prompt: Custom prompt for AI review
            model: OpenAI model to use
            detail: Image detail level
        
        Returns:
            Dict with feedback and metadata
        """
        # Capture screenshot
        print("📸 Capturing screenshot...")
        image = self.capture_screenshot(region)
        
        # Convert to WebP
        print("🔄 Converting to WebP (85% quality)...")
        webp_bytes = self.convert_to_webp(image, quality=85)
        
        # Auto-save if no explicit save path provided but auto_save is True
        if not save_screenshot and auto_save:
            # Create screenshots directory if it doesn't exist
            screenshots_dir = Path("screenshots")
            screenshots_dir.mkdir(exist_ok=True)
            # Generate timestamp-based filename
            from datetime import datetime
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            save_screenshot = str(screenshots_dir / f"screenshot_{timestamp}.webp")
        
        # Save if requested
        if save_screenshot:
            path = Path(save_screenshot)
            if not path.suffix:
                path = path.with_suffix(".webp")
            with open(path, "wb") as f:
                f.write(webp_bytes)
            print(f"💾 Screenshot saved to: {path}")
        
        # Encode for API
        image_base64 = self.encode_image_base64(webp_bytes)
        
        # Get AI feedback
        print(f"🤖 Getting AI feedback from {model}...")
        feedback = self.get_ai_feedback(image_base64, prompt, model, detail)
        
        return {
            "feedback": feedback,
            "image_size": len(webp_bytes),
            "image_dimensions": f"{image.width}x{image.height}",
            "model": model,
            "detail": detail
        }


def main():
    """CLI interface for the UI review tool"""
    parser = argparse.ArgumentParser(
        description="Capture screenshots and get AI feedback on UI/UX",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Review full screen
  %(prog)s
  
  # Review specific region
  %(prog)s --region 100 100 800 600
  
  # Save screenshot
  %(prog)s --save screenshot.webp
  
  # Custom prompt
  %(prog)s --prompt "Focus on mobile responsiveness"
  
  # Use high detail mode
  %(prog)s --detail high
  
  # Use GPT-4 for more detailed analysis
  %(prog)s --model gpt-4o
"""
    )
    
    parser.add_argument(
        "--api-key",
        help="OpenAI API key (or set OPENAI_API_KEY env var)"
    )
    parser.add_argument(
        "--region",
        nargs=4,
        type=int,
        metavar=("LEFT", "TOP", "WIDTH", "HEIGHT"),
        help="Screen region to capture"
    )
    parser.add_argument(
        "--save",
        help="Save screenshot to file"
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
        "--no-feedback",
        action="store_true",
        help="Only capture screenshot without AI feedback"
    )
    
    args = parser.parse_args()
    
    try:
        # Initialize tool
        tool = UIReviewTool(api_key=args.api_key)
        
        # Prepare region if specified
        region = None
        if args.region:
            region = {
                "left": args.region[0],
                "top": args.region[1],
                "width": args.region[2],
                "height": args.region[3]
            }
        
        if args.no_feedback:
            # Just capture and save
            image = tool.capture_screenshot(region)
            webp_bytes = tool.convert_to_webp(image)
            
            if args.save:
                path = Path(args.save)
                if not path.suffix:
                    path = path.with_suffix(".webp")
                with open(path, "wb") as f:
                    f.write(webp_bytes)
                print(f"✅ Screenshot saved to: {path}")
                print(f"📊 Size: {len(webp_bytes):,} bytes")
                print(f"📐 Dimensions: {image.width}x{image.height}")
            else:
                print("❌ No save path specified. Use --save to save the screenshot.")
        else:
            # Full review workflow
            result = tool.review_ui(
                region=region,
                save_screenshot=args.save,
                prompt=args.prompt,
                model=args.model,
                detail=args.detail
            )
            
            print("\n" + "="*60)
            print("🎨 UI REVIEW FEEDBACK")
            print("="*60)
            print(f"\n{result['feedback']}")
            print("\n" + "="*60)
            print(f"📊 Image size: {result['image_size']:,} bytes")
            print(f"📐 Dimensions: {result['image_dimensions']}")
            print(f"🤖 Model: {result['model']}")
            print(f"🔍 Detail: {result['detail']}")
            print("="*60)
    
    except KeyboardInterrupt:
        print("\n❌ Cancelled by user")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()