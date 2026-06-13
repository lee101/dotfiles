# Flamegraph Analyzer

Convert flamegraphs, Go `pprof` data, Python profile data, Perfetto traces, Nsight-style exports, and perf CSV logs to readable markdown summaries.

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

# Analyze Go pprof directly
flamegraph-analyzer cpu.pprof -o cpu-analysis.md

# Analyze harness perf CSV
flamegraph-analyzer perf.csv -o perf-analysis.md

# Analyze Perfetto or Chrome trace JSON
flamegraph-analyzer trace.json -o trace-analysis.md

# Analyze binary Perfetto traces when trace_processor_shell is installed
TRACE_PROCESSOR_BIN=trace_processor_shell flamegraph-analyzer capture.perfetto-trace -o trace-analysis.md

# Analyze exported Nsight CSV
flamegraph-analyzer nsight.csv -o nsight-analysis.md

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

- **SVG flamegraph parsing**: Extracts function names and timings from classic flamegraphs and Graphviz SVG emitted by `go tool pprof -svg`
- **Go pprof support**: Parses raw `.pprof` files via `go tool pprof -top`
- **Python profile support**: Parses .profile and .prof files from cProfile/profile modules
- **Perfetto trace support**: Parses exported Perfetto or Chrome trace JSON, and can optionally query binary Perfetto traces through `trace_processor_shell`
- **Nsight-style CSV support**: Parses exported CSV summaries, classifies compute/memcpy/memset/sync activity, and surfaces kernel occupancy/bandwidth metrics when present
- **Perf CSV support**: Summarizes FPS, frame spikes, draw/update maxima, and heap ranges from benchmark logs
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
- Trace-level summaries of device work, host work, transfer-heavy operations, and aggregate transfer bandwidth
- ASCII bar charts for time distribution
- Detailed breakdowns of performance hotspots (functions >threshold%)
- Per-call timing statistics
- Top optimization recommendations
