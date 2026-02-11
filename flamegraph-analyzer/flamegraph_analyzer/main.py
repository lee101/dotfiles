#!/usr/bin/env python3
"""Main entry point for flamegraph analyzer."""

import json
import re
from pathlib import Path
from typing import Dict, List, Tuple
import xml.etree.ElementTree as ET

import click
# NOTE: `lxml` isn't required for the current parser implementation; avoid an
# extra dependency so this works in minimal Python environments.


class FlamegraphParser:
    """Parse SVG flamegraph files and extract performance data."""
    
    def __init__(self, svg_path: Path):
        self.svg_path = svg_path
        self.frames = []
        
    def parse(self) -> List[Dict]:
        """Parse SVG and extract frame data."""
        tree = ET.parse(self.svg_path)
        root = tree.getroot()
        
        # Find all frame elements - could be in g elements or nested svg elements
        frames_found = []
        
        # Method 1: Look for g elements with class func_g (original format)
        for g in root.findall('.//{http://www.w3.org/2000/svg}g'):
            if g.get('class') == 'func_g':
                frames_found.extend(self._extract_frame_from_g(g))
        
        # Method 2: Look for nested svg elements with class func_g (flameprof format)
        for svg in root.findall('.//{http://www.w3.org/2000/svg}svg'):
            if svg.get('class') == 'func_g':
                frames_found.extend(self._extract_frame_from_svg(svg))
        
        self.frames = frames_found
        
        # Sort by width (time spent) descending
        self.frames.sort(key=lambda x: x.get('percentage', 0), reverse=True)
        return self.frames
    
    def _extract_frame_from_g(self, g):
        """Extract frame info from g element."""
        frames = []
        # Extract title (tooltip) which contains function info
        title_elem = g.find('{http://www.w3.org/2000/svg}title')
        if title_elem is not None and title_elem.text:
            # Parse the title text
            frame_info = self._parse_frame_title(title_elem.text)
            
            # Get visual properties
            rect = g.find('{http://www.w3.org/2000/svg}rect')
            if rect is not None:
                frame_info['width'] = float(rect.get('width', 0))
                frame_info['x'] = float(rect.get('x', 0))
                
            frames.append(frame_info)
        return frames
    
    def _extract_frame_from_svg(self, svg):
        """Extract frame info from nested svg element (flameprof format)."""
        frames = []
        # Look for g element inside this svg
        g_elem = svg.find('{http://www.w3.org/2000/svg}g')
        if g_elem is not None:
            title_elem = g_elem.find('{http://www.w3.org/2000/svg}title')
            if title_elem is not None and title_elem.text:
                # Parse the title text
                frame_info = self._parse_flameprof_title(title_elem.text)
                
                # Get visual properties from svg element
                frame_info['width'] = float(svg.get('width', 0))
                frame_info['x'] = float(svg.get('x', 0))
                frame_info['y'] = float(svg.get('y', 0))
                
                frames.append(frame_info)
        return frames
    
    def _parse_frame_title(self, title: str) -> Dict:
        """Parse the title/tooltip text to extract function info."""
        lines = title.strip().split('\n')
        info = {'raw_title': title}
        
        if lines:
            # First line is usually the function name
            info['function'] = lines[0].strip()
            
            # Look for sample count and percentage
            for line in lines[1:]:
                if 'samples' in line or 'ms' in line:
                    # Extract numbers from line
                    numbers = re.findall(r'[\d,]+\.?\d*', line)
                    if numbers:
                        info['samples'] = numbers[0].replace(',', '')
                    
                    # Extract percentage if present
                    percent_match = re.search(r'(\d+\.?\d*)%', line)
                    if percent_match:
                        info['percentage'] = float(percent_match.group(1))
        
        return info
    
    def _parse_flameprof_title(self, title: str) -> Dict:
        """Parse flameprof format title text to extract function info."""
        # Format: "filename:line:function percentage% (calls own_time cum_time)"
        info = {'raw_title': title}
        
        # Extract percentage
        percent_match = re.search(r'(\d+\.?\d*)%', title)
        if percent_match:
            info['percentage'] = float(percent_match.group(1))
        
        # Extract function name (everything after last colon before percentage)
        # Example: "/path/file.py:34:main 100.00% ..." -> "main"
        parts = title.split(' ')[0]  # Get the first part before space
        if ':' in parts:
            path_parts = parts.split(':')
            if len(path_parts) >= 3:
                info['function'] = path_parts[-1]  # Last part is function name
                info['filename'] = ':'.join(path_parts[:-2])  # Everything except last 2 parts
                info['line'] = path_parts[-2]  # Second to last is line number
            else:
                info['function'] = parts
        else:
            info['function'] = parts
        
        # Extract timing info from parentheses
        paren_match = re.search(r'\(([^)]+)\)', title)
        if paren_match:
            timing_parts = paren_match.group(1).split()
            if len(timing_parts) >= 4:
                info['calls'] = timing_parts[0]
                info['own_time'] = timing_parts[2]
                info['cum_time'] = timing_parts[3]
        
        return info


class ProfileParser:
    """Parse .profile and .prof files."""

    def __init__(self, profile_path: Path):
        self.profile_path = profile_path
        self.profile_data = []
        self.stats = None

    def parse(self) -> List[Dict]:
        """Parse profile file and extract performance data."""
        import pstats

        try:
            # Try to load as pstats file
            stats = pstats.Stats(str(self.profile_path))
            stats.strip_dirs()
            self.stats = stats

            # Get the stats in a parseable format
            stats_dict = {}
            stats.calc_callees()

            for func, (cc, nc, tt, ct, callers) in stats.stats.items():
                filename, line, func_name = func
                stats_dict[func] = {
                    'function': f"{func_name} ({filename}:{line})",
                    'filename': filename,
                    'line': line,
                    'func_name': func_name,
                    'ncalls': nc,
                    'tottime': tt,
                    'percall': tt/nc if nc > 0 else 0,
                    'cumtime': ct,
                    'percall_cum': ct/nc if nc > 0 else 0,
                    'location': f"{filename}:{line}"
                }

            # Convert to list and sort by cumulative time
            self.profile_data = list(stats_dict.values())
            self.profile_data.sort(key=lambda x: x['cumtime'], reverse=True)

            # Calculate percentages
            total_time = sum(x['cumtime'] for x in self.profile_data)
            for item in self.profile_data:
                item['percentage'] = (item['cumtime'] / total_time * 100) if total_time > 0 else 0

        except Exception as e:
            # If pstats fails, try to parse as text profile
            self._parse_text_profile()

        return self.profile_data
    
    def _parse_text_profile(self):
        """Parse text-based profile output."""
        content = self.profile_path.read_text()
        
        # Look for typical profile output patterns
        # This is a simplified parser - extend based on actual format
        lines = content.strip().split('\n')
        
        for line in lines:
            # Skip headers and empty lines
            if not line.strip() or line.startswith('#'):
                continue
                
            # Try to extract function timing info
            # Adapt this regex based on your profile format
            match = re.match(r'\s*(\d+\.?\d*)\s+(\d+\.?\d*)\s+(\d+\.?\d*)\s+(\d+\.?\d*)\s+(.+)', line)
            if match:
                cumtime, tottime, percall, percall_cum, func_info = match.groups()
                self.profile_data.append({
                    'function': func_info.strip(),
                    'cumtime': float(cumtime),
                    'tottime': float(tottime),
                    'percall': float(percall),
                    'percall_cum': float(percall_cum),
                    'percentage': 0  # Will calculate later
                })
        
        # Calculate percentages
        if self.profile_data:
            total_time = sum(x['cumtime'] for x in self.profile_data)
            for item in self.profile_data:
                item['percentage'] = (item['cumtime'] / total_time * 100) if total_time > 0 else 0


class MarkdownFormatter:
    """Format performance data as markdown."""
    
    def format_flamegraph(self, frames: List[Dict], input_file: str) -> str:
        """Format flamegraph data as markdown."""
        md_lines = [
            f"# Flamegraph Analysis: {Path(input_file).name}",
            "",
            "## Summary",
            "",
            f"Total functions analyzed: {len(frames)}",
            "",
            "## Top Time-Consuming Functions",
            "",
            "| Function | Time % | Samples/Time |",
            "|----------|--------|--------------|"
        ]
        
        # Show top 20 functions
        for frame in frames[:20]:
            func_name = frame.get('function', 'Unknown')
            # Truncate long function names
            if len(func_name) > 60:
                func_name = func_name[:57] + "..."
            
            percentage = frame.get('percentage', 0)
            samples = frame.get('samples', 'N/A')
            
            md_lines.append(f"| {func_name} | {percentage:.2f}% | {samples} |")
        
        # Add flame width distribution
        md_lines.extend([
            "",
            "## Performance Distribution",
            "",
            "Functions consuming more than 1% of total time:",
            ""
        ])
        
        significant_frames = [f for f in frames if f.get('percentage', 0) >= 1.0]
        
        for frame in significant_frames:
            func_name = frame.get('function', 'Unknown')
            percentage = frame.get('percentage', 0)
            bar_length = int(percentage / 2)  # Scale to max 50 chars
            bar = "█" * bar_length + "░" * (50 - bar_length)
            
            md_lines.append(f"- {func_name}")
            md_lines.append(f"  {bar} {percentage:.2f}%")
            md_lines.append("")
        
        return "\n".join(md_lines)
    
    def format_profile(self, profile_data: List[Dict], input_file: str, top_n=50, hotspot_threshold=1.0) -> str:
        """Format profile data as markdown with hot paths analysis."""
        md_lines = [
            f"# Profile Analysis: {Path(input_file).name}",
            "",
            "## Summary",
            "",
            f"Total functions profiled: {len(profile_data)}",
            ""
        ]

        # Calculate total time
        total_time = sum(x.get('cumtime', 0) for x in profile_data)
        if total_time > 0:
            md_lines.append(f"Total execution time: {total_time:.3f} seconds")
            md_lines.append("")

        md_lines.extend([
            f"## Top {top_n} Time-Consuming Functions (Hot Paths)",
            "",
            "| Rank | Function | Location | Cumulative | Own Time | Calls | % Total |",
            "|------|----------|----------|------------|----------|-------|---------|"
        ])

        # Show top N functions
        for idx, item in enumerate(profile_data[:top_n], 1):
            func_name = item.get('func_name', item.get('function', 'Unknown'))
            location = item.get('location', 'Unknown')

            # Truncate long names for table
            if len(func_name) > 40:
                func_name = func_name[:37] + "..."
            if len(location) > 50:
                location = "..." + location[-47:]

            cumtime = item.get('cumtime', 0)
            tottime = item.get('tottime', 0)
            ncalls = item.get('ncalls', 0)
            percentage = item.get('percentage', 0)

            md_lines.append(
                f"| {idx} | `{func_name}` | {location} | {cumtime:.3f}s | {tottime:.3f}s | {ncalls:,} | {percentage:.1f}% |"
            )

        # Add hotspots section (functions taking >threshold% of time)
        md_lines.extend([
            "",
            f"## Performance Hotspots (>{hotspot_threshold}% of total time)",
            "",
        ])

        hotspots = [f for f in profile_data if f.get('percentage', 0) >= hotspot_threshold]

        for item in hotspots[:30]:  # Limit to top 30 hotspots
            func_name = item.get('func_name', item.get('function', 'Unknown'))
            location = item.get('location', 'Unknown')
            percentage = item.get('percentage', 0)
            cumtime = item.get('cumtime', 0)
            tottime = item.get('tottime', 0)
            ncalls = item.get('ncalls', 0)

            # Create visual bar
            bar_length = min(int(percentage), 50)
            bar = "█" * bar_length

            md_lines.extend([
                f"### `{func_name}` ({location})",
                f"{bar} **{percentage:.2f}%**",
                f"- **Cumulative time**: {cumtime:.3f}s",
                f"- **Own time**: {tottime:.3f}s",
                f"- **Calls**: {ncalls:,}",
                f"- **Time per call**: {item.get('percall_cum', 0):.6f}s",
                ""
            ])

        # Add recommendations section
        md_lines.extend([
            "",
            "## Optimization Recommendations",
            "",
            "Based on the profile data, consider optimizing:",
            ""
        ])

        # Top 5 by cumulative time
        for idx, item in enumerate(profile_data[:5], 1):
            func_name = item.get('func_name', item.get('function', 'Unknown'))
            location = item.get('location', 'Unknown')
            percentage = item.get('percentage', 0)

            md_lines.append(
                f"{idx}. **{func_name}** ({location}) - {percentage:.1f}% of total time"
            )

        return "\n".join(md_lines)


@click.command()
@click.argument('input_file', type=click.Path(exists=True))
@click.option('-o', '--output', type=click.Path(), help='Output markdown file (default: stdout)')
@click.option('-n', '--top-n', type=int, default=50, help='Number of top functions to display (default: 50)')
@click.option('-t', '--threshold', type=float, default=1.0, help='Hotspot threshold percentage (default: 1.0)')
def cli(input_file, output, top_n, threshold):
    """Convert flamegraph SVG or profile data to markdown description with hot paths analysis."""
    input_path = Path(input_file)

    # Determine file type and parse accordingly
    if input_path.suffix.lower() == '.svg':
        parser = FlamegraphParser(input_path)
        data = parser.parse()
        formatter = MarkdownFormatter()
        markdown = formatter.format_flamegraph(data, input_file)
    elif input_path.suffix.lower() in ['.profile', '.prof']:
        parser = ProfileParser(input_path)
        data = parser.parse()
        formatter = MarkdownFormatter()
        markdown = formatter.format_profile(data, input_file, top_n=top_n, hotspot_threshold=threshold)
    else:
        click.echo(f"Unsupported file type: {input_path.suffix}", err=True)
        return

    # Output result
    if output:
        Path(output).write_text(markdown)
        click.echo(f"Markdown analysis written to: {output}")
    else:
        click.echo(markdown)


if __name__ == '__main__':
    cli()
