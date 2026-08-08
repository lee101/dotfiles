# Go tooling

Go-specific developer tools and performance guides. Companion to the broader
[tools collection](../README.md).

## go-line-profiler

Analyzes Go CPU profiles (`pprof`) with multiple views, filtering out stdlib and
vendor frames so you see *your* hot paths. Written for profiling 2D Go games
(Ebiten/BulletGo) but works on any Go `cpu.prof`.

### Build

It's a standalone Go module, built in place (the binary is gitignored):

```bash
cd tools/golang/go-line-profiler
go build -o go-line-profiler .      # or on Windows: go build -o go-line-profiler.exe .
```

Or run without building:

```bash
go run . -prof cpu.prof -root <your-module-name>
```

### Usage

```bash
go-line-profiler -prof cpu.prof -root bulletgo                    # top functions (default)
go-line-profiler -prof cpu.prof -root bulletgo -view tree         # call tree
go-line-profiler -prof cpu.prof -root bulletgo -view bottleneck   # where CPU actually spins (flat time)
go-line-profiler -prof cpu.prof -root bulletgo -view callers      # caller/callee context
go-line-profiler -prof cpu.prof -root bulletgo -view detail       # per-line CPU for hot functions
go-line-profiler -prof cpu.prof -root bulletgo -view detail -detail "QueryCircle"   # filter to one function
go-line-profiler -prof cpu.prof -root bulletgo -view all          # all views
go-line-profiler -prof cpu.prof -base old.prof -root bulletgo -view diff   # compare two profiles
go-line-profiler -prof cpu.prof -root bulletgo -html hotspots.html         # HTML report
```

- `-prof` — the CPU profile to analyze (required)
- `-root` — your module/package name; frames outside it are filtered out
- `-view` — `top` | `tree` | `bottleneck` | `callers` | `detail` | `all` | `diff`
- `-base` — baseline profile for `-view diff`
- `-detail` — substring filter for the `detail` view
- `-html` — write an HTML hotspot report instead of text

## Performance guides

Practical notes gathered while optimizing a 2D Go game (BulletGo, on Ebiten):

- **[go-game-perf-guide.md](go-game-perf-guide.md)** — how to profile and optimize
  2D Go games: pprof commands, common bottlenecks, and fixes.
- **[go-game-scaling-analysis.md](go-game-scaling-analysis.md)** — why performance
  degrades with entity count: spatial structures, collision, AI, rendering.
- **[go-game-particle-scaling.md](go-game-particle-scaling.md)** — why particle
  rendering doesn't scale linearly and what to do about it.
