#!/usr/bin/env python3

import os
import subprocess
import argparse
import sys
from pathlib import Path

def convert_webm_to_opus(input_file, output_file, dry_run=False):
    """Convert a WebM file to Opus audio format using ffmpeg."""
    cmd = [
        'ffmpeg',
        '-hwaccel', 'cuda',  # Use CUDA hardware acceleration
        '-hwaccel_output_format', 'cuda',  # Keep decoded frames in GPU memory
        '-i', str(input_file),
        '-vn',  # No video
        '-c:a', 'libopus',  # Use Opus codec
        '-b:a', '96k',  # Good quality/compression balance
        '-application', 'audio',  # Optimize for audio
        '-y',  # Overwrite output file
        str(output_file)
    ]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return True
    except subprocess.CalledProcessError as e:
        print(f"Error converting {input_file}: {e.stderr}")
        return False

def main():
    parser = argparse.ArgumentParser(description='Convert WebM videos to Opus audio files')
    parser.add_argument('--dry-run-once', action='store_true', 
                       help='Process only one file without removing originals (for testing)')
    parser.add_argument('--source-dir', default='/media/lee/crucial/downloads/',
                       help='Source directory containing WebM files')
    
    args = parser.parse_args()
    
    source_dir = Path(args.source_dir)
    if not source_dir.exists():
        print(f"Error: Source directory {source_dir} does not exist")
        sys.exit(1)
    
    # Find all WebM files
    webm_files = list(source_dir.rglob('*.webm'))
    if not webm_files:
        print(f"No WebM files found in {source_dir}")
        return
    
    print(f"Found {len(webm_files)} WebM files")
    
    # Process files
    files_to_process = webm_files[:1] if args.dry_run_once else webm_files
    
    for webm_file in files_to_process:
        opus_file = webm_file.with_suffix('.opus')
        
        print(f"Converting: {webm_file.name} -> {opus_file.name}")
        
        success = convert_webm_to_opus(webm_file, opus_file, dry_run=args.dry_run_once)
        
        if success and not args.dry_run_once:
            # Only remove original if conversion succeeded and not in dry-run mode
            try:
                webm_file.unlink()
                print(f"Removed original: {webm_file.name}")
            except Exception as e:
                print(f"Warning: Could not remove {webm_file}: {e}")
        
        if args.dry_run_once:
            print("Dry run complete - processed one file only")
            break

if __name__ == '__main__':
    main()
