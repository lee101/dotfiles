# Flamegraph Analyzer

Convert SVG flamegraphs and Python profile data to readable markdown descriptions.

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

# Analyze Python profile data
flamegraph-analyzer profile.prof -o profile-analysis.md
```

## Features

- **SVG Flamegraph parsing**: Extracts function names, time percentages, and sample counts
- **Python profile support**: Parses .profile and .prof files from cProfile/profile modules
- **Markdown output**: Generates readable reports with:
  - Summary statistics
  - Top time-consuming functions table
  - Performance distribution visualization
  - Hotspot analysis

## Example Output

The tool generates markdown with:
- Function performance tables
- ASCII bar charts for time distribution
- Detailed breakdowns of performance hotspots
- Call count and timing statistics