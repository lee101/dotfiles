# Developer Tools Tutorial

This guide covers the essential command-line tools, utilities, and configurations that make up a modern, efficient development environment. These tools are automatically installed via the `linux-setup.sh` script and configured in `bashrc`.

## Core Text Processing & Search Tools

### ripgrep (rg)
**What it is**: Ultrafast grep alternative with smart defaults
**Why it's essential**: 10x faster than grep, respects .gitignore, better output formatting

```bash
# Basic search
rg "function" --type js
rg "TODO|FIXME" --type py

# Search with context
rg -C 3 "error handling"

# Search specific directories
rg "import" src/ --type ts
```

### fd
**What it is**: Simple, fast alternative to find
**Why it's essential**: Respects .gitignore, colorized output, intuitive syntax

```bash
# Find files by name
fd config
fd "\.js$"

# Find directories only
fd --type d node_modules

# Execute commands on results
fd "\.py$" --exec wc -l
```

### bat
**What it is**: cat with syntax highlighting and Git integration
**Why it's essential**: Better code reading, automatic paging, line numbers

```bash
# View file with syntax highlighting
bat src/main.js

# View specific lines
bat --line-range 40:60 package.json

# Use as pager for other commands
git diff | bat
```

### exa/eza
**What it is**: Modern ls replacement with colors and Git status
**Why it's essential**: Better file information display, Git integration

```bash
# Basic usage (aliased to ls in bashrc)
eza --long --git --icons
eza --tree --level=2

# Show Git status in listing
eza -l --git
```

## Git Workflow Tools

### lazygit (lg)
**What it is**: Terminal UI for Git operations
**Why it's essential**: Visual Git workflow, stage hunks easily, branch management

```bash
# Open lazygit in current repo
lg

# Key bindings inside lazygit:
# - Space: stage/unstage files
# - c: commit
# - P: push
# - p: pull
# - +/-: stage/unstage hunks
```

### delta
**What it is**: Syntax-highlighting pager for git diff
**Why it's essential**: Better diff readability, side-by-side comparisons

Automatically configured in `.gitconfig`:
```bash
# Git diff now uses delta automatically
git diff
git log -p
```

### difftastic (difft)
**What it is**: Structural diff tool that understands code syntax
**Why it's essential**: Shows meaningful diffs based on code structure

```bash
# Compare files structurally
difft file1.js file2.js

# Use with git (alias: gdft)
git difftool --tool difft
```

### tig
**What it is**: Text-mode interface for Git
**Why it's essential**: Browse Git history, blame, and refs efficiently

```bash
# Browse repository (alias: tg)
tig

# Show file history
tig path/to/file.js

# Browse specific branch
tig feature-branch
```

## File Navigation & Management

### fzf (Fuzzy Finder)
**What it is**: General-purpose command-line fuzzy finder
**Why it's essential**: Quick file/command finding, integrates with many tools

Pre-configured functions in bashrc:
```bash
# Fuzzy find and edit files
fe pattern

# Fuzzy find with preview
fo pattern

# Fuzzy directory navigation
fd

# Git branch switching with fzf
gcof
```

### zoxide (z)
**What it is**: Smart directory jumper that learns your habits
**Why it's essential**: Jump to frequently-used directories with minimal typing

```bash
# Jump to directory containing "dotfiles"
z dotfiles

# Jump to most frequent directory matching pattern
z proj

# List scored directories
z -l
```

### broot (br)
**What it is**: Tree view with navigation and search
**Why it's essential**: Navigate large directory structures efficiently

```bash
# Open broot in current directory
br

# Inside broot:
# - Type to search
# - Alt+Enter to cd
# - :q to quit
```

## System Monitoring & Info

### btop
**What it is**: Modern system resource monitor
**Why it's essential**: Beautiful, detailed system monitoring with mouse support

```bash
# Launch system monitor
btop

# Key features:
# - CPU, memory, disk, network graphs
# - Process management
# - Mouse support
# - Customizable themes
```

### dust
**What it is**: Intuitive du alternative with tree visualization
**Why it's essential**: Quickly identify large directories and files

```bash
# Show disk usage tree
dust

# Limit depth and number of entries
dust -d 3 -n 20

# Show file sizes, not just directories
dust -f
```

### procs
**What it is**: Modern ps replacement with colored output
**Why it's essential**: Better process information display

```bash
# List all processes
procs

# Search processes
procs nginx
procs --tree
```

## Development Utilities

### httpie (http)
**What it is**: Human-friendly HTTP client
**Why it's essential**: API testing and debugging made simple

```bash
# GET request
http GET api.github.com/users/octocat

# POST with JSON
http POST api.example.com/users name=john age:=30

# Custom headers
http GET api.example.com Authorization:"Bearer token"
```

### jq
**What it is**: Command-line JSON processor
**Why it's essential**: Parse, filter, and manipulate JSON data

```bash
# Pretty print JSON
curl api.github.com/users/octocat | jq '.'

# Extract specific fields
jq '.name, .login' user.json

# Filter arrays
jq '.[] | select(.active == true)'
```

### yq
**What it is**: YAML processor (jq for YAML)
**Why it's essential**: Work with YAML configuration files

```bash
# Read YAML values
yq '.database.host' config.yml

# Update YAML in place
yq -i '.version = "2.0"' docker-compose.yml
```

## Container & Cloud Tools

### dive
**What it is**: Tool for exploring Docker image layers
**Why it's essential**: Optimize Docker images, understand layer composition

```bash
# Analyze Docker image
dive nginx:latest

# Analyze local image
dive my-app:latest
```

### k9s
**What it is**: Terminal UI for Kubernetes
**Why it's essential**: Manage Kubernetes clusters interactively

```bash
# Launch k9s
k9s

# Navigate with:
# - : for command mode
# - / for search
# - d for describe
# - l for logs
```

### stern
**What it is**: Multi-pod log tailing for Kubernetes
**Why it's essential**: View logs from multiple pods simultaneously

```bash
# Tail logs from all pods matching pattern
stern app-

# Tail with container selection
stern --container nginx app-
```

## Text Editing & IDE Tools

### helix (hx)
**What it is**: Modern text editor with vim-like keybindings
**Why it's essential**: Built-in LSP, tree-sitter, multiple selections

```bash
# Edit file
hx file.js

# Key features:
# - Built-in language servers
# - Multiple cursors
# - Tree-sitter syntax highlighting
# - No configuration needed
```

### neovim with modern plugins
Enhanced configuration in `init.lua`:

**Essential plugins included**:
- Telescope (fuzzy finder)
- nvim-tree (file explorer)
- GitHub Copilot
- Treesitter (syntax highlighting)
- LSP support

## Shell & Terminal Enhancements

### starship
**What it is**: Customizable shell prompt
**Why it's essential**: Fast, informative prompt with Git status, language versions

Automatically shows:
- Git branch and status
- Language versions (Node, Python, etc.)
- Kubernetes context
- Command execution time

### tmux + modern config
Session management with sensible defaults:

```bash
# Create new session
tmux new -s work

# Attach to session
tmux attach -t work

# List sessions
tmux ls
```

### aliases and functions (from bashrc)
Your bashrc includes hundreds of productivity aliases:

**Git workflow**:
```bash
# Commit and push
gcmep "commit message"

# Interactive rebase
grbi

# Branch switching with fzf
gcof
```

**Navigation**:
```bash
# Quick directory jumps
c      # cd ~/code
u      # cd ..
d      # cd (same as cd)
```

**Docker shortcuts**:
```bash
dps    # docker ps
dklall # stop and remove all containers
```

## Tool Integration Examples

### Combined Workflows

**Code exploration**:
```bash
# Find files, preview with bat, edit with nvim
fd "\.js$" | fzf --preview 'bat --color=always {}' | xargs nvim
```

**Git workflow with multiple tools**:
```bash
# Review changes with delta, stage with lazygit, push
git diff  # (uses delta automatically)
lg        # (stage changes interactively)
gpsh      # (push with upstream tracking)
```

**System analysis**:
```bash
# Find large files and directories
dust | head -20
fd "\.log$" --exec dust
```

**API development**:
```bash
# Test API and format response
http GET api.example.com/users | jq '.data[] | {name, email}'
```

## Installation & Configuration

All tools are installed via:
```bash
./linux-setup.sh
```

Key configuration files:
- `bashrc` - Aliases, functions, tool configurations
- `init.lua` - Neovim setup with modern plugins
- `.gitconfig` - Git configuration with delta integration
- `tools/` - Custom scripts and utilities

## Productivity Tips

1. **Use tool combinations**: Many tools work better together (fzf + fd, git + delta, etc.)

2. **Learn incremental adoption**: Start with a few tools, gradually add more to your workflow

3. **Customize aliases**: Add your own shortcuts to `bashrc` using the `ali` and `alis` functions

4. **Leverage built-in integrations**: Many tools auto-detect and enhance each other

5. **Practice keyboard shortcuts**: Tools like lazygit, k9s, and broot are keyboard-driven for speed

This toolset transforms the command line into a powerful, modern development environment that rivals any GUI-based IDE while maintaining the flexibility and speed of terminal-based workflows.