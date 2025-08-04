#!/usr/bin/env python3
"""Generate a flamegraph from Python profile data."""

import subprocess
import sys
import os
from pathlib import Path


def generate_flamegraph_from_profile(profile_file, output_svg):
    """Convert Python profile to flamegraph SVG using py-spy."""
    
    # First check if py-spy is available
    try:
        subprocess.run(['py-spy', '--version'], capture_output=True, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("py-spy not found. Installing it...")
        subprocess.run([sys.executable, '-m', 'pip', 'install', 'py-spy'], check=True)
    
    # Alternative: use flameprof if py-spy doesn't work with profile files
    try:
        import flameprof
    except ImportError:
        print("Installing flameprof for profile conversion...")
        subprocess.run([sys.executable, '-m', 'pip', 'install', 'flameprof'], check=True)
    
    # Generate flamegraph using flameprof
    print(f"Generating flamegraph from {profile_file}...")
    
    # First convert profile to flamegraph format
    cmd = [sys.executable, '-m', 'flameprof', profile_file, '-o', output_svg]
    
    try:
        subprocess.run(cmd, check=True)
        print(f"Flamegraph saved to {output_svg}")
    except subprocess.CalledProcessError as e:
        print(f"Error generating flamegraph: {e}")
        # Try alternative method with direct SVG generation
        generate_manual_flamegraph(profile_file, output_svg)


def generate_manual_flamegraph(profile_file, output_svg):
    """Generate a flamegraph manually from profile stats."""
    import pstats
    from xml.etree.ElementTree import Element, SubElement, tostring
    from xml.dom import minidom
    
    # Load profile stats
    stats = pstats.Stats(profile_file)
    stats.strip_dirs()
    
    # Get total time
    total_time = sum(timing[2] for timing in stats.stats.values())
    
    # Create SVG
    svg = Element('svg', {
        'version': '1.1',
        'width': '1200',
        'height': '600',
        'xmlns': 'http://www.w3.org/2000/svg'
    })
    
    # Add style
    defs = SubElement(svg, 'defs')
    style = SubElement(defs, 'style', {'type': 'text/css'})
    style.text = '.func_g:hover { stroke:black; stroke-width:0.5; cursor:pointer; }'
    
    # Sort functions by cumulative time
    sorted_stats = sorted(stats.stats.items(), key=lambda x: x[1][3], reverse=True)
    
    y_offset = 500
    x_offset = 10
    height = 15
    scale = 1180 / total_time if total_time > 0 else 1
    
    # Create rectangles for each function
    for i, (func_key, (cc, nc, tt, ct, callers)) in enumerate(sorted_stats[:30]):  # Top 30
        filename, line, func_name = func_key
        
        # Calculate width based on cumulative time
        width = ct * scale
        if width < 1:
            continue
            
        # Create group
        g = SubElement(svg, 'g', {'class': 'func_g'})
        
        # Add title (tooltip)
        title = SubElement(g, 'title')
        percentage = (ct / total_time * 100) if total_time > 0 else 0
        samples = int(ct * 1000)  # Convert to milliseconds
        title.text = f"{func_name}\n{samples} ms ({percentage:.2f}%)"
        
        # Add rectangle
        colors = ['rgb(250,128,114)', 'rgb(250,200,100)', 'rgb(100,200,250)', 
                  'rgb(150,250,150)', 'rgb(250,150,250)', 'rgb(200,100,200)']
        color = colors[i % len(colors)]
        
        rect = SubElement(g, 'rect', {
            'x': str(x_offset),
            'y': str(y_offset - i * 20),
            'width': str(width),
            'height': str(height),
            'fill': color
        })
        
        # Add text
        text = SubElement(g, 'text', {
            'x': str(x_offset + 5),
            'y': str(y_offset - i * 20 + 12),
            'font-size': '12',
            'font-family': 'Verdana'
        })
        text.text = func_name[:50]  # Truncate long names
    
    # Pretty print XML
    xml_str = minidom.parseString(tostring(svg)).toprettyxml(indent='  ')
    
    with open(output_svg, 'w') as f:
        f.write(xml_str)
    
    print(f"Manual flamegraph saved to {output_svg}")


if __name__ == '__main__':
    # Generate a new profile with the example
    print("Generating new profile data...")
    subprocess.run([sys.executable, 'example_profiler.py'])
    
    # Convert to flamegraph
    generate_flamegraph_from_profile('example.prof', 'example_generated.svg')