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