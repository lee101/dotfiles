# Developer Tools Collection

A collection of AI-powered developer tools for code quality, testing, and performance optimization.

## Tools Overview

### 🧪 cldtest - AI-Powered Test Runner
Automatically detects your test framework and runs tests with AI-powered analysis and fixes.

**Features:**
- Auto-detects test frameworks (Go, Python, Bun, Node.js, Rust, Java)
- AI-powered test failure analysis and auto-fixing
- Test quality and coverage insights
- Unit and integration test filtering

**Usage:**
```bash
cldtest                 # Run all tests
cldtest --fix           # Run tests and auto-fix failures
cldtest --analyze       # Run tests and get analysis
cldtest --unit          # Run unit tests only
```

### ⚡ cldperf - Performance Profiling Tool
AI-powered performance analysis and optimization for your codebase.

**Commands:**
```bash
cldperf profile [path]   # Profile code and identify bottlenecks
cldperf optimize [path]  # Get optimization suggestions (--fix to apply)
cldperf benchmark        # Run and analyze benchmarks
cldperf memory           # Analyze memory usage and leaks
cldperf native -- <cmd>  # Run callgrind + massif and emit a Markdown native report
cldperf gpu -- <cmd>     # Run Nsight Systems and emit a Markdown CUDA report
cldperf cuda -- <cmd>    # Alias for gpu
```

**Features:**
- Language-specific profiling strategies
- Algorithmic complexity analysis
- Memory leak detection
- Performance optimization suggestions
- Benchmark analysis

### 🔍 jscheck - JavaScript Error Checker
Loads web pages in Chrome and collects JavaScript errors for debugging.

**Features:**
- Detects console errors, runtime errors, and unhandled promises
- Chrome profile support via environment variables
- Clean, formatted error output

**Usage:**
```bash
jscheck <url>                          # Check a URL for JS errors
export CHROME_PROFILE_PATH="/path"     # Use specific Chrome profile
jscheck https://example.com
```

### 🧠 pymem-report - Python Memory Report (Markdown + Flamegraph)
Runs a Python command under memray and emits a markdown summary plus optional flamegraph.

**Usage:**
```bash
pymem-report -- python -m your_module --args
pymem-report --out report.md --flame report.html -- python script.py
```

### 🛰️ cuda-prof-report - CUDA/Nsight Markdown Report
Runs a command under Nsight Systems and emits a Markdown report with CUDA API hotspots,
kernel summaries, transfer breakdowns, NVTX range tables, bottleneck ranking, simple USE-style heuristics,
and next-step recommendations.

**Usage:**
```bash
cuda-prof-report -- ./build/bitbankc_forecast_bench --context 512 --horizon 24
cuda-prof-report --top 10 -- ./build/bitbankc_forecast_bench --context 512 --horizon 24
cuda-prof-report --report api -- ./build/app
cuda-prof-report --report kernels --report transfers -- ./build/app
cuda-prof-report --timeout 30 --stats-timeout 10 -- ./build/app
cuda-prof-report --require-kernels --max-api-time-pct cudaMalloc=20 -- ./build/app
cuda-prof-report --out cuda-report.md --prefix /tmp/bench_cuda -- ./app
cuda-prof-report --out cuda-report.md --latest-link latest-cuda.md -- ./app
cldperf gpu -- ./build/app
cldperf cuda -- ./build/app
```

If you pass `--out` and omit `--prefix`, the profiler artifacts default to the same path stem as the markdown file.
If you pass `--latest-link`, the tool also updates sibling `.nsys-rep` and `.sqlite` latest pointers.
Use `--report api|kernels|transfers` to limit which sections are collected and rendered; policy flags automatically pull in the sections they need.
Use `--timeout` and `--stats-timeout` to keep stuck profile or summary runs from hanging forever.
If you already have saved profiler artifacts, use `profile-md` from `profiling/bin/` to turn `.nsys-rep`, `.ncu-rep`, or `trtexec` logs into markdown without rerunning the workload.

### 🧵 native-prof-report - Native CPU/Heap Markdown Report
Runs a native command under `callgrind` and `massif`, then emits a compact Markdown report with:
- top CPU hotspots by instruction count
- peak heap consumers by allocation stack
- optional line-level CPU attribution for selected source files

**Usage:**
```bash
native-prof-report -- ./build/app --flag value
native-prof-report --source-file src/foo.cpp -- ./build/app
native-prof-report --out native-report.md --prefix /tmp/native-run -- ./build/app
cldperf native -- ./build/app
```

Notes:
- line-level CPU attribution requires debug info, so prefer a `RelWithDebInfo` or dedicated profiling build
- exact per-line heap attribution is not available here; use the reported peak allocation stacks instead

### 🤖 cldpr - Pull Request Creator
Creates well-structured pull requests with AI-generated summaries.

**Usage:**
```bash
cldpr                   # Create PR from current branch
```

### 🔧 cldfix - Code Fixer
AI-powered code fixing tool for common issues.

**Usage:**
```bash
cldfix                  # Fix issues in current directory
```

### 📝 cldcmt - Commit Helper
Creates well-formatted git commits with AI-generated messages.

**Usage:**
```bash
cldcmt                  # Create commit with AI message
```

### 🚀 cldgcmep - Git Add, Commit & Push
Full git workflow with Claude-powered cleanup and fixes.

**Features:**
- Adds all changes (git add -A)
- Runs Claude cleanup and fixes
- Commits with your message
- Pushes to remote

**Usage:**
```bash
cldgcmep "commit message"        # Full workflow
cldgcmep -n "wip: refactoring"  # Skip push
cldgcmep --no-fix "quick fix"   # Skip Claude cleanup
cldgcmep -f "force update"       # Force push
```

### 🔍 claude-review - Code Review Tool
AI-powered code review for your changes.

**Usage:**
```bash
claude-review           # Review current changes
```

### 🎯 cldrvcmt - Review & Commit Tool
Intelligent git workflow that reviews changes, fixes issues, and creates atomic commits.

**Features:**
- Reviews all changes for code quality
- Automatically fixes linting/formatting issues
- Groups related changes into logical commits
- Creates atomic commits with clear messages
- Uses conventional commit format

**Usage:**
```bash
cldrvcmt                # Review, fix, and commit all changes
```

**Example workflow:**
- Reviews all unstaged/staged changes
- Fixes any code issues found
- Groups changes (e.g., API changes, tests, docs)
- Creates separate commits for each group

## Installation

All tools are already in this directory. To use them system-wide:

1. Add this directory to your PATH:
   ```bash
   export PATH="$PATH:/home/lee/code/dotfiles/tools"
   ```

2. Or create symlinks:
   ```bash
   ln -s /home/lee/code/dotfiles/tools/cldtest ~/.local/bin/cldtest
   ln -s /home/lee/code/dotfiles/tools/cldperf ~/.local/bin/cldperf
   # etc...
   ```

## Common Features

- **AI-Powered**: All tools use Claude for intelligent analysis
- **Auto-Detection**: Tools automatically detect languages and frameworks
- **Actionable Insights**: Get specific, implementable suggestions
- **Multi-Language**: Support for Go, Python, JavaScript, Rust, Java, and more

## Requirements

- Claude CLI (`cld` command) installed
- Language-specific tools (e.g., go, python, node, cargo)
- Chrome browser (for jscheck)

## Other Utilities

### Chrome Profile Management
- `export_chrome_profile.sh` - Export Chrome profiles
- `setup_chrome_profile.sh` - Setup Chrome profiles
- `simple_chrome_backup.sh` - Simple Chrome backup utility

### :globe_with_meridians: webvitals - Core Web Vitals Measurement
Measures Core Web Vitals (LCP, CLS, INP, FCP, TTFB) using Playwright + Chrome DevTools Protocol.

**Usage:**
```bash
webvitals <url>                    # Measure web vitals
webvitals https://example.com --runs=3    # Average over 3 runs
webvitals https://example.com --mobile    # Simulate mobile viewport
webvitals https://example.com --json      # Output raw JSON
```

**Features:**
- Largest Contentful Paint (LCP) with element identification
- Cumulative Layout Shift (CLS) with source detection
- Interaction to Next Paint (INP) measurement
- Resource waterfall and long task analysis
- Connection timing breakdown (DNS, TCP, SSL)
- Multi-run averaging and statistics

**Requirements:** `playwright` Python package + Chromium

### :link: blc - Broken Link Checker
Crawls a website and reports broken links with clean markdown output.

**Usage:**
```bash
blc <url>                          # Check for broken links (depth 2)
blc https://example.com --depth=3  # Crawl deeper
blc https://example.com --external # Also check external links
blc https://example.com --json     # Output raw JSON
```

**Features:**
- Concurrent link checking with configurable workers
- Internal and external link checking
- Grouped results by status code
- Pages-with-most-broken-links summary
- Works with stdlib only (optional requests/beautifulsoup4 for speed)

### Additional Tools
- `dustg` - Git-aware disk usage analyzer (respects .gitignore)
- `curls` - Simple curl wrapper

## JavaScript Error Checker Setup

For the JavaScript error checker specifically:
```bash
./setup_js_checker.sh   # Install Python dependencies
```

## Troubleshooting

### Command Not Found
Ensure the tools directory is in your PATH or create symlinks as shown above.

### Claude CLI Missing
Install Claude CLI from: https://claude.ai/cli

### Permission Denied
Make tools executable:
```bash
chmod +x cld*
chmod +x jscheck
```
