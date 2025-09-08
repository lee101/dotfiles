#!/bin/bash
# Flame graph aliases and helper functions

# Set paths
FLAME_TOOLS_DIR="$(dirname "${BASH_SOURCE[0]}")"
AUTOFLAME="$FLAME_TOOLS_DIR/autoflame.py"
FLAME_AGENT="$FLAME_TOOLS_DIR/flame_agent.py"

# Basic flame graph generation
alias flame='python $AUTOFLAME'
alias flamepy='python $AUTOFLAME -l python'
alias flamego='python $AUTOFLAME -l golang'
alias flamers='python $AUTOFLAME -l rust'
alias flamejs='python $AUTOFLAME -l javascript'

# Flame graph with analysis
alias flamea='python $AUTOFLAME -a'
alias flamepa='python $AUTOFLAME -l python -a'
alias flamega='python $AUTOFLAME -l golang -a'
alias flamersa='python $AUTOFLAME -l rust -a'
alias flamejsa='python $AUTOFLAME -l javascript -a'

# Flame agent commands
alias flameagent='python $FLAME_AGENT'
alias flameopt='python $FLAME_AGENT -o'  # With optimization
alias flamecmp='python $FLAME_AGENT -o -c'  # With comparison

# Helper functions

# Quick flame graph for current Python script
flamepycurrent() {
    local script="${1:-*.py}"
    python $AUTOFLAME $script -l python -a --top 10
}

# Profile Python module
flamepymod() {
    local module="$1"
    shift
    python $AUTOFLAME -m "$module" "$@" -l python -a
}

# Profile Go test
flamegotest() {
    local test="${1:-.}"
    python $AUTOFLAME "$test" -l golang -t -a
}

# Profile and optimize with agent
flameoptimize() {
    local file="$1"
    local lang="${2:-auto}"
    
    echo "🔥 Profiling $file..."
    python $FLAME_AGENT "$file" -l "$lang" -o
    
    echo "📊 Optimization complete!"
}

# Interactive flame graph analyzer
flameinteractive() {
    local file="$1"
    
    # Generate flame graph
    local csv_file=$(python $AUTOFLAME "$file" -a 2>&1 | grep "Flame graph generated:" | cut -d: -f2 | tr -d ' ')
    
    if [ -z "$csv_file" ]; then
        echo "Failed to generate flame graph"
        return 1
    fi
    
    # Generate analysis
    local analysis_file="${csv_file%.csv}_analysis.md"
    local prompt_file="${csv_file%.csv}_prompt.txt"
    
    echo "📊 Flame graph: $csv_file"
    echo "📝 Analysis: $analysis_file"
    
    # Open in editor if available
    if command -v code &> /dev/null; then
        code "$analysis_file"
    elif command -v vim &> /dev/null; then
        vim "$analysis_file"
    else
        cat "$analysis_file"
    fi
    
    # Ask if user wants to optimize
    read -p "Run optimization with Claude? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        claude --dangerously-skip-permissions < "$prompt_file"
    fi
}

# Batch profiling
flamebatch() {
    local pattern="${1:-*.py}"
    local output_dir="${2:-flame_reports}"
    
    mkdir -p "$output_dir"
    
    for file in $pattern; do
        if [ -f "$file" ]; then
            echo "Profiling $file..."
            local basename=$(basename "$file" | sed 's/\.[^.]*$//')
            python $AUTOFLAME "$file" -a -o "$output_dir" > "$output_dir/${basename}_report.txt" 2>&1
        fi
    done
    
    echo "Reports saved in $output_dir/"
}

# Compare two implementations
flamecompare() {
    local file1="$1"
    local file2="$2"
    
    echo "🔥 Profiling $file1..."
    local csv1=$(python $AUTOFLAME "$file1" -a 2>&1 | grep "Flame graph generated:" | cut -d: -f2 | tr -d ' ')
    
    echo "🔥 Profiling $file2..."
    local csv2=$(python $AUTOFLAME "$file2" -a 2>&1 | grep "Flame graph generated:" | cut -d: -f2 | tr -d ' ')
    
    echo "📊 Comparison:"
    echo "File 1: $file1 -> $csv1"
    echo "File 2: $file2 -> $csv2"
    
    # Simple comparison of total samples
    local total1=$(tail -n +2 "$csv1" | awk -F',' '{sum+=$2} END {print sum}')
    local total2=$(tail -n +2 "$csv2" | awk -F',' '{sum+=$2} END {print sum}')
    
    echo "Total samples: $total1 vs $total2"
    
    if (( $(echo "$total1 > $total2" | bc -l) )); then
        echo "✅ $file2 is faster by $(echo "scale=2; ($total1-$total2)/$total1*100" | bc)%"
    else
        echo "✅ $file1 is faster by $(echo "scale=2; ($total2-$total1)/$total2*100" | bc)%"
    fi
}

# Live profiling with watch
flamewatch() {
    local file="$1"
    local interval="${2:-5}"
    
    watch -n "$interval" "python $AUTOFLAME '$file' -a --top 5 2>&1 | head -30"
}

# Profile with memory tracking
flamemem() {
    local file="$1"
    
    if command -v /usr/bin/time &> /dev/null; then
        /usr/bin/time -v python "$file" 2>&1 | tee /tmp/flame_mem_$$.txt
        echo "Memory profile saved to /tmp/flame_mem_$$.txt"
    else
        echo "GNU time not found. Install with: sudo apt-get install time"
    fi
    
    # Also generate CPU flame graph
    python $AUTOFLAME "$file" -a
}

# Helper to install dependencies
flameinstall() {
    echo "Installing flame graph dependencies..."
    
    # Python dependencies
    pip install py-spy || uv pip install py-spy
    
    # System dependencies
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt-get update
        sudo apt-get install -y linux-tools-common linux-tools-generic linux-tools-$(uname -r)
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install rust
        cargo install flamegraph
    fi
    
    echo "✅ Dependencies installed"
}

# Quick help
flamehelp() {
    cat << EOF
🔥 Flame Graph Tools Help

Basic Commands:
  flame <file>           - Generate flame graph
  flamepy <file>         - Profile Python file
  flamego <file>         - Profile Go file
  flamers <file>         - Profile Rust file
  flamejs <file>         - Profile JavaScript file

Analysis Commands:
  flamea <file>          - Generate with analysis
  flameagent <file>      - Use AI agent for analysis
  flameopt <file>        - Optimize with AI
  flamecmp <file>        - Optimize and compare

Helper Functions:
  flameoptimize <file>   - Interactive optimization
  flamecompare <f1> <f2> - Compare two implementations
  flamebatch <pattern>   - Batch profiling
  flamewatch <file>      - Live profiling
  flamemem <file>        - Memory + CPU profiling
  flameinstall           - Install dependencies

Examples:
  flame myapp.py -a --top 10
  flameopt slow_function.py
  flamecompare old.py new.py
  flamebatch "*.py" reports/

EOF
}

# Export functions for use in subshells
export -f flamepycurrent flamepymod flamegotest flameoptimize
export -f flameinteractive flamebatch flamecompare flamewatch
export -f flamemem flameinstall flamehelp