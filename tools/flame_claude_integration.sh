#!/bin/bash
# Claude integration for flame graph analysis
# This script provides seamless integration between flame graphs and Claude AI

FLAME_TOOLS_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Main Claude flame graph analysis function
claude_flame() {
    local file="$1"
    local mode="${2:-analyze}"  # analyze, optimize, fix
    
    # Generate flame graph and analysis
    echo "🔥 Generating flame graph for $file..."
    local output=$(python "$FLAME_TOOLS_DIR/autoflame.py" "$file" -a -p 2>&1)
    
    # Extract file paths
    local csv_file=$(echo "$output" | grep "Flame graph generated:" | cut -d: -f2 | tr -d ' ')
    local analysis_file="${csv_file%.csv}_analysis.md"
    local prompt_file="${csv_file%.csv}_prompt.txt"
    
    if [ ! -f "$prompt_file" ]; then
        echo "Error: Could not generate flame graph analysis"
        return 1
    fi
    
    case "$mode" in
        analyze)
            # Just analyze the performance
            echo "📊 Sending analysis to Claude..."
            claude --dangerously-skip-permissions < "$prompt_file"
            ;;
            
        optimize)
            # Get optimization suggestions and apply them
            echo "🚀 Getting optimization suggestions from Claude..."
            
            # Create enhanced prompt for optimization
            cat > /tmp/flame_optimize_$$.txt << EOF
Based on the flame graph analysis below, please provide:

1. Optimized version of the code
2. Specific changes made and why
3. Expected performance improvements
4. Any trade-offs to consider

Original file: $file

$(cat "$file")

$(cat "$prompt_file")

Please provide the complete optimized code that can replace the original file.
EOF
            
            # Get optimized code from Claude
            local optimized_file="${file%.py}_optimized.py"
            claude --dangerously-skip-permissions < /tmp/flame_optimize_$$.txt > "$optimized_file"
            
            echo "✅ Optimized code saved to: $optimized_file"
            
            # Clean up
            rm /tmp/flame_optimize_$$.txt
            
            # Compare performance
            echo "📊 Comparing performance..."
            python "$FLAME_TOOLS_DIR/autoflame.py" "$optimized_file" -a
            ;;
            
        fix)
            # Fix specific performance issues
            echo "🔧 Fixing performance bottlenecks with Claude..."
            
            cat > /tmp/flame_fix_$$.txt << EOF
The following code has performance issues identified in the flame graph analysis.
Please fix the specific bottlenecks while maintaining functionality.

Focus on:
- Reducing time in hot functions
- Optimizing loops and data structures
- Removing unnecessary computations
- Improving algorithm complexity

Original file: $file

$(cat "$file")

Flame graph analysis:
$(cat "$analysis_file")

Provide the fixed code with comments explaining each optimization.
EOF
            
            local fixed_file="${file%.py}_fixed.py"
            claude --dangerously-skip-permissions < /tmp/flame_fix_$$.txt > "$fixed_file"
            
            echo "✅ Fixed code saved to: $fixed_file"
            rm /tmp/flame_fix_$$.txt
            ;;
            
        *)
            echo "Unknown mode: $mode"
            echo "Use: analyze, optimize, or fix"
            return 1
            ;;
    esac
}

# Multi-file flame graph analysis
claude_flame_project() {
    local pattern="${1:-*.py}"
    local output_dir="flame_analysis_$(date +%Y%m%d_%H%M%S)"
    
    mkdir -p "$output_dir"
    
    echo "🔍 Analyzing project performance..."
    
    # Collect all flame graphs
    for file in $pattern; do
        if [ -f "$file" ]; then
            echo "Processing $file..."
            python "$FLAME_TOOLS_DIR/autoflame.py" "$file" -a -o "$output_dir" > /dev/null 2>&1
        fi
    done
    
    # Create combined analysis prompt
    cat > "$output_dir/project_analysis.txt" << EOF
Project-wide Performance Analysis

I've profiled multiple files in this project. Please analyze the overall performance characteristics and provide:

1. System-wide bottlenecks
2. Common performance patterns across files
3. Architectural improvements
4. Priority list of optimizations
5. Estimated overall performance gain

Individual file analyses:
EOF
    
    # Append all analyses
    for analysis in "$output_dir"/*_analysis.md; do
        if [ -f "$analysis" ]; then
            echo -e "\n---\n$(basename "$analysis"):\n" >> "$output_dir/project_analysis.txt"
            cat "$analysis" >> "$output_dir/project_analysis.txt"
        fi
    done
    
    echo "📊 Sending project analysis to Claude..."
    claude --dangerously-skip-permissions < "$output_dir/project_analysis.txt" > "$output_dir/recommendations.md"
    
    echo "✅ Analysis complete! Results in: $output_dir/"
    echo "   - Individual analyses: *_analysis.md"
    echo "   - Recommendations: recommendations.md"
}

# Interactive flame graph optimization session
claude_flame_interactive() {
    local file="$1"
    
    echo "🎯 Starting interactive optimization session for $file"
    
    # Initial profiling
    claude_flame "$file" "analyze"
    
    while true; do
        echo -e "\n📋 Options:"
        echo "1) Optimize code"
        echo "2) Fix bottlenecks"
        echo "3) Re-profile"
        echo "4) Compare versions"
        echo "5) Exit"
        
        read -p "Choose action: " choice
        
        case $choice in
            1)
                claude_flame "$file" "optimize"
                ;;
            2)
                claude_flame "$file" "fix"
                ;;
            3)
                python "$FLAME_TOOLS_DIR/autoflame.py" "$file" -a
                ;;
            4)
                if [ -f "${file%.py}_optimized.py" ]; then
                    echo "Comparing original vs optimized..."
                    python "$FLAME_TOOLS_DIR/flame_agent.py" "$file" -c
                else
                    echo "No optimized version found"
                fi
                ;;
            5)
                echo "👋 Exiting optimization session"
                break
                ;;
            *)
                echo "Invalid choice"
                ;;
        esac
    done
}

# Continuous performance monitoring with Claude
claude_flame_monitor() {
    local target="$1"
    local interval="${2:-300}"  # Default 5 minutes
    local threshold="${3:-10}"  # Performance degradation threshold (%)
    
    echo "📡 Starting performance monitoring for $target"
    echo "   Interval: ${interval}s"
    echo "   Threshold: ${threshold}%"
    
    local baseline_file="/tmp/flame_baseline_$$.csv"
    
    # Create baseline
    echo "Creating performance baseline..."
    python "$FLAME_TOOLS_DIR/autoflame.py" "$target" > /dev/null 2>&1
    cp "$(ls -t /tmp/flame_*.csv | head -1)" "$baseline_file"
    
    while true; do
        sleep "$interval"
        
        echo -e "\n[$(date)] Checking performance..."
        
        # Generate new profile
        python "$FLAME_TOOLS_DIR/autoflame.py" "$target" > /dev/null 2>&1
        local current_file="$(ls -t /tmp/flame_*.csv | head -1)"
        
        # Compare with baseline
        local baseline_total=$(tail -n +2 "$baseline_file" | awk -F',' '{sum+=$2} END {print sum}')
        local current_total=$(tail -n +2 "$current_file" | awk -F',' '{sum+=$2} END {print sum}')
        
        local degradation=$(echo "scale=2; ($current_total-$baseline_total)/$baseline_total*100" | bc)
        
        echo "Performance change: ${degradation}%"
        
        if (( $(echo "$degradation > $threshold" | bc -l) )); then
            echo "⚠️ Performance degradation detected!"
            
            # Get Claude's analysis
            cat > /tmp/flame_alert_$$.txt << EOF
Performance degradation detected in $target

Baseline total: $baseline_total
Current total: $current_total
Degradation: ${degradation}%

Please analyze what might have caused this performance regression and suggest fixes.

Current flame graph data:
$(head -20 "$current_file")
EOF
            
            claude --dangerously-skip-permissions < /tmp/flame_alert_$$.txt
            
            # Update baseline if user confirms
            read -p "Update baseline? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                cp "$current_file" "$baseline_file"
                echo "Baseline updated"
            fi
        fi
    done
}

# Flame graph CI/CD integration
claude_flame_ci() {
    local target="$1"
    local max_time="${2:-1000}"  # Maximum acceptable time
    
    echo "🔍 Running performance check for CI/CD..."
    
    # Generate flame graph
    python "$FLAME_TOOLS_DIR/autoflame.py" "$target" -a > /tmp/ci_flame_$$.txt 2>&1
    
    # Extract total time
    local csv_file=$(grep "Flame graph generated:" /tmp/ci_flame_$$.txt | cut -d: -f2 | tr -d ' ')
    local total_time=$(tail -n +2 "$csv_file" | awk -F',' '{sum+=$2} END {print sum}')
    
    echo "Total execution time: $total_time"
    echo "Maximum allowed: $max_time"
    
    if (( $(echo "$total_time > $max_time" | bc -l) )); then
        echo "❌ Performance check FAILED"
        
        # Get optimization suggestions from Claude
        echo "Getting optimization suggestions..."
        cat "${csv_file%.csv}_prompt.txt" | claude --dangerously-skip-permissions > /tmp/ci_suggestions_$$.md
        
        echo -e "\n📋 Optimization suggestions:"
        cat /tmp/ci_suggestions_$$.md
        
        exit 1
    else
        echo "✅ Performance check PASSED"
        exit 0
    fi
}

# Aliases for quick access
alias cflame='claude_flame'
alias cflameo='claude_flame $1 optimize'
alias cflamef='claude_flame $1 fix'
alias cflameproject='claude_flame_project'
alias cflamei='claude_flame_interactive'
alias cflamemon='claude_flame_monitor'
alias cflameci='claude_flame_ci'

# Help function
claude_flame_help() {
    cat << EOF
🔥 Claude Flame Graph Integration

Commands:
  claude_flame <file> [mode]     - Analyze file with Claude
    Modes: analyze (default), optimize, fix
  
  claude_flame_project [pattern] - Analyze entire project
  
  claude_flame_interactive <file> - Interactive optimization
  
  claude_flame_monitor <file> [interval] [threshold]
    Monitor performance over time
  
  claude_flame_ci <file> [max_time]
    CI/CD performance check

Aliases:
  cflame <file>      - Quick analysis
  cflameo <file>     - Optimize code
  cflamef <file>     - Fix bottlenecks
  cflameproject      - Project analysis
  cflamei <file>     - Interactive mode
  cflamemon <file>   - Monitor mode
  cflameci <file>    - CI check

Examples:
  claude_flame app.py analyze
  claude_flame_project "src/*.py"
  claude_flame_monitor server.py 60 5
  claude_flame_ci test.py 500

Environment Variables:
  CLAUDE_FLAME_OUTPUT_DIR - Output directory (default: /tmp)
  CLAUDE_FLAME_TOP_N     - Top N functions to analyze (default: 20)

EOF
}

# Export functions
export -f claude_flame claude_flame_project claude_flame_interactive
export -f claude_flame_monitor claude_flame_ci claude_flame_help