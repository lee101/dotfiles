# Performance Optimization Agents

## Performance Optimizer (`perf-optimize`)

An AI-powered performance analysis and optimization agent that uses system tracing to identify and fix bottlenecks in applications.

### Installation

```bash
# Make sure claude CLI is installed
npm install -g @anthropic/claude-cli

# Add agents directory to PATH
export PATH="$PATH:~/code/dotfiles/agents"
```

### Usage

```bash
# Analyze a running application
perf-optimize myapp

# Analyze specific PID
perf-optimize --pid 1234

# Find and analyze by name
perf-optimize --name firefox

# Start and analyze a command
perf-optimize --exec "npm start"

# Optimize codebase (static analysis)
perf-optimize --codebase ./src

# Auto-fix mode (dangerous - will modify code!)
perf-optimize --fix --name myapp

# Quick 5-second analysis
perf-optimize --quick myapp

# Deep 30-second analysis  
perf-optimize --deep myapp
```

### Features

The agent will:

1. **Profile** - Use strace, perf, dtrace to trace the application
2. **Analyze** - Identify CPU, I/O, memory, or concurrency bottlenecks
3. **Locate** - Find the problematic code in your codebase
4. **Optimize** - Implement fixes like caching, buffering, async I/O
5. **Verify** - Re-run traces to confirm improvements

### Common Optimizations

The agent can automatically implement:

- **Caching** - Add memoization and result caching
- **Buffering** - Buffer I/O operations to reduce syscalls
- **Pooling** - Connection and object pooling
- **Async** - Convert blocking I/O to async
- **Algorithms** - Replace O(n²) with O(n log n)
- **Batching** - Batch operations to reduce overhead
- **Indexes** - Add database indexes
- **Compression** - Enable gzip for network transfers

### Examples

```bash
# Optimize a Node.js app with memory issues
perf-optimize --fix --name node --codebase ./

# Quick CPU profiling of Python script
perf-optimize --quick --exec "python app.py"

# Deep analysis of running database
perf-optimize --deep --name postgres

# Generate performance report only
perf-optimize --report --pid 8080
```

### Safety

- Always backup code before using `--fix` mode
- The agent needs sudo for some tracing operations
- Review changes before committing
- Test thoroughly after optimizations

### Supported Platforms

- **Linux**: Full support with strace, perf, bpftrace
- **macOS**: Full support with dtrace, dtruss
- **WSL**: Limited support (no perf, some /proc limitations)

### Troubleshooting

If tracing tools are missing:

```bash
# Linux
sudo apt-get install strace perf-tools-unstable linux-tools-common

# macOS
# dtrace is built-in, may need to disable SIP for some operations

# Check what's available
perf-optimize --help
```