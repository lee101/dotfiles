# Usage Examples

## Generate and Analyze Real Flamegraphs

### 1. Generate Profile Data
```bash
python example_profiler.py
```
This creates `example.prof` with sample performance data.

### 2. Convert Profile to Flamegraph
```bash
python -m flameprof example.prof -o real_flamegraph.svg
```
This generates an SVG flamegraph from the profile data.

### 3. Analyze the Flamegraph
```bash
flamegraph-analyzer real_flamegraph.svg
```

Example output shows the tool successfully identified:
- **main function**: 100% (entry point)
- **time.sleep calls**: ~90% (major bottleneck)
- **slow_function**: 53.13% (expected slow operation)
- **medium_function**: 45.41% (expected medium operation)
- **recursive_function**: 1.41% (minimal recursive overhead)

### 4. Save Analysis
```bash
flamegraph-analyzer real_flamegraph.svg -o analysis.md
```

## Compare Profile vs Flamegraph Analysis

Both formats provide complementary insights:

**Profile analysis (`example.prof`):**
- Function call counts
- Cumulative vs own time
- Exact timing measurements
- Call hierarchy information

**Flamegraph analysis (`real_flamegraph.svg`):**
- Visual time distribution
- Stack depth representation
- Easy identification of hot paths
- Percentage-based breakdown

The tool successfully handles both formats and provides readable markdown summaries for performance analysis.