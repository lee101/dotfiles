#!/usr/bin/env python3

import os
import sys
import argparse
from pathlib import Path
from PIL import Image
import subprocess

def get_file_size(filepath):
    """Get file size in bytes."""
    return os.path.getsize(filepath)

def is_image_file(filepath):
    """Check if file is a supported image format."""
    extensions = {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.tif'}
    return filepath.suffix.lower() in extensions

def convert_to_webp(input_path, quality=85):
    """Convert image to WebP format."""
    output_path = input_path.with_suffix('.webp')
    try:
        with Image.open(input_path) as img:
            # Convert RGBA to RGB if necessary
            if img.mode in ('RGBA', 'LA', 'P'):
                rgb_img = Image.new('RGB', img.size, (255, 255, 255))
                if img.mode == 'P':
                    img = img.convert('RGBA')
                rgb_img.paste(img, mask=img.split()[-1] if img.mode in ('RGBA', 'LA') else None)
                img = rgb_img
            
            img.save(output_path, 'WebP', quality=quality, optimize=True)
        return output_path
    except Exception as e:
        print(f"Error converting {input_path}: {e}")
        return None

def format_bytes(bytes_size):
    """Format bytes to human readable format."""
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if bytes_size < 1024.0:
            return f"{bytes_size:.2f} {unit}"
        bytes_size /= 1024.0
    return f"{bytes_size:.2f} PB"

def main():
    parser = argparse.ArgumentParser(description='Find and optimize image files')
    parser.add_argument('path', nargs='?', default='.', help='Path to search (default: current directory)')
    parser.add_argument('--optim', action='store_true', help='Convert images to WebP and delete originals')
    parser.add_argument('--dryrun', action='store_true', help='Create one WebP file for testing, then exit')
    parser.add_argument('--quality', type=int, default=85, help='WebP quality (default: 85)')
    
    args = parser.parse_args()
    
    search_path = Path(args.path)
    if not search_path.exists():
        print(f"Error: Path '{search_path}' does not exist")
        sys.exit(1)
    
    total_size = 0
    file_count = 0
    converted_count = 0
    total_saved = 0
    
    print(f"Scanning for image files in: {search_path.absolute()}")
    print("-" * 60)
    
    for root, dirs, files in os.walk(search_path):
        for file in files:
            filepath = Path(root) / file
            
            if is_image_file(filepath):
                file_size = get_file_size(filepath)
                total_size += file_size
                file_count += 1
                
                print(f"{filepath.relative_to(search_path)}: {format_bytes(file_size)}")
                
                # Handle optimization
                if args.optim or args.dryrun:
                    webp_path = convert_to_webp(filepath, args.quality)
                    if webp_path:
                        webp_size = get_file_size(webp_path)
                        saved = file_size - webp_size
                        total_saved += saved
                        converted_count += 1
                        
                        print(f"  → {webp_path.name}: {format_bytes(webp_size)} (saved: {format_bytes(saved)})")
                        
                        if args.dryrun:
                            print(f"\nDry run complete. Created {webp_path}")
                            print(f"Original: {format_bytes(file_size)} → WebP: {format_bytes(webp_size)}")
                            print(f"Potential savings: {format_bytes(saved)} ({(saved/file_size)*100:.1f}%)")
                            sys.exit(0)
                        
                        if args.optim:
                            try:
                                os.remove(filepath)
                                print(f"  Deleted original: {filepath.name}")
                            except Exception as e:
                                print(f"  Error deleting {filepath}: {e}")
    
    print("-" * 60)
    print(f"Total images found: {file_count}")
    print(f"Total size: {format_bytes(total_size)}")
    
    if args.optim:
        print(f"Images converted: {converted_count}")
        print(f"Total space saved: {format_bytes(total_saved)}")
        if total_size > 0:
            print(f"Space reduction: {(total_saved/total_size)*100:.1f}%")

if __name__ == "__main__":
    main()
