# Flamegraph Analyzer

Convert SVG flamegraphs and Python profile data to readable markdown descriptions with hot paths analysis.

## Installation

```bash
cd flamegraph-analyzer
uv venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
uv pip install -e .
```

## Usage

```bash
# Analyze SVG flamegraph
flamegraph-analyzer flamegraph.svg

# Save to file
flamegraph-analyzer flamegraph.svg -o analysis.md

# Analyze Python profile data with hot paths
flamegraph-analyzer profile.prof -o profile-analysis.md

# Customize top N functions and hotspot threshold
flamegraph-analyzer profile.prof -n 100 -t 0.5 -o detailed-analysis.md

# Use directly as Python module (no installation required)
python flamegraph_analyzer/main.py profile.prof -o analysis.md
```

## Options

- `-o, --output PATH`: Output markdown file (default: stdout)
- `-n, --top-n N`: Number of top functions to display (default: 50)
- `-t, --threshold PCT`: Hotspot threshold percentage (default: 1.0)

## Features

- **SVG Flamegraph parsing**: Extracts function names, time percentages, and sample counts
- **Python profile support**: Parses .profile and .prof files from cProfile/profile modules
- **Hot paths analysis**: Identifies performance bottlenecks and critical paths
- **Markdown output**: Generates readable reports with:
  - Summary statistics
  - Top N time-consuming functions table with locations
  - Performance distribution visualization
  - Hotspot analysis with visual bars
  - Optimization recommendations

## Example Output

The tool generates markdown with:
- Ranked function performance tables with file locations
- ASCII bar charts for time distribution
- Detailed breakdowns of performance hotspots (functions >threshold%)
- Per-call timing statistics
- Top optimization recommendations