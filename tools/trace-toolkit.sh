#!/usr/bin/env bash
# Trace Toolkit - Comprehensive tracing utilities for Linux and macOS
# Author: System Tracing Utilities
# Description: Collection of tracing commands for system debugging and performance analysis

# Detect OS
OS="$(uname -s)"
ARCH="$(uname -m)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

trace_help() {
    cat << 'EOF'
TRACE TOOLKIT - System Tracing Utilities
=========================================

QUICK COMMANDS:
  trace-syscalls <pid>     - Trace system calls for a process
  trace-files <pid>        - Trace file operations for a process
  trace-network <pid>      - Trace network operations
  trace-exec <command>     - Trace execution of a new command
  proc-watch <pid>         - Watch process in /proc (Linux)
  proc-find <name>         - Find process by name and show details
  proc-tree <pid>          - Show process tree
  proc-files <pid>         - Show open files for process
  proc-memory <pid>        - Show memory maps
  proc-threads <pid>       - Show threads for process
  trace-cpu <pid>          - Trace CPU usage
  trace-io <pid>           - Trace I/O operations

EXAMPLES:
  trace-syscalls 1234                    # Trace syscalls for PID 1234
  trace-exec "curl https://example.com"  # Trace curl command
  proc-watch 5678                        # Watch process 5678 in /proc
  trace-files $(pgrep firefox)          # Trace Firefox file operations
  
Use 'trace-examples' for detailed examples
EOF
}

trace_examples() {
    cat << 'EOF'
DETAILED TRACING EXAMPLES
=========================

LINUX STRACE EXAMPLES:
----------------------
# Basic syscall tracing
strace -p 1234

# Trace with timestamps
strace -t -p 1234

# Trace only file operations
strace -e trace=file -p 1234

# Trace network operations
strace -e trace=network -p 1234

# Count syscalls
strace -c -p 1234

# Trace child processes
strace -f -p 1234

# Save output to file
strace -o trace.log -p 1234

# Trace specific syscalls
strace -e open,read,write -p 1234

# Trace with stack traces
strace -k -p 1234

LINUX LTRACE EXAMPLES:
----------------------
# Trace library calls
ltrace -p 1234

# Trace with timestamps
ltrace -t -p 1234

# Count library calls
ltrace -c -p 1234

# Trace specific libraries
ltrace -l /lib/x86_64-linux-gnu/libc.so.6 -p 1234

LINUX PERF EXAMPLES:
--------------------
# Record CPU samples
sudo perf record -p 1234

# Live CPU profiling
sudo perf top -p 1234

# Trace scheduler events
sudo perf sched record -p 1234

# System-wide profiling
sudo perf record -a -g

# Generate flame graph data
sudo perf record -F 99 -p 1234 -g -- sleep 10
sudo perf script > out.perf

LINUX FTRACE EXAMPLES:
----------------------
# Enable function tracing
echo function > /sys/kernel/debug/tracing/current_tracer

# Trace specific functions
echo 'do_sys_open' > /sys/kernel/debug/tracing/set_ftrace_filter

# View trace
cat /sys/kernel/debug/tracing/trace

LINUX BPF/BPFTRACE EXAMPLES:
----------------------------
# Trace file opens
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_open { printf("%s %s\n", comm, str(args->filename)); }'

# Count syscalls by program
sudo bpftrace -e 'tracepoint:raw_syscalls:sys_enter { @[comm] = count(); }'

# Trace TCP connections
sudo bpftrace -e 'kprobe:tcp_connect { printf("PID %d connecting\n", pid); }'

# Histogram of read sizes
sudo bpftrace -e 'tracepoint:syscalls:sys_exit_read { @bytes = hist(args->ret); }'

MACOS DTRACE EXAMPLES:
----------------------
# Trace system calls
sudo dtruss -p 1234

# Trace file operations
sudo dtrace -n 'syscall::open*:entry { printf("%s %s", execname, copyinstr(arg0)); }'

# Trace network operations
sudo dtrace -n 'syscall::connect*:entry { printf("%s pid:%d", execname, pid); }'

# CPU profiling
sudo dtrace -n 'profile-997 /pid == 1234/ { @[ustack()] = count(); }'

# Trace library calls
sudo dtrace -n 'pid$target::malloc:entry { @[probefunc] = count(); }' -p 1234

# File I/O latency
sudo dtrace -n 'syscall::read:entry { self->start = timestamp; } 
                syscall::read:return /self->start/ { 
                    @time[execname] = quantize(timestamp - self->start); 
                    self->start = 0; 
                }'

# Process creation
sudo dtrace -n 'proc:::create { printf("%s created %s", execname, args[0]->pr_fname); }'

# Memory allocations
sudo dtrace -n 'pid$target::malloc:entry { @bytes = quantize(arg0); }' -p 1234

/PROC FILESYSTEM EXAMPLES (LINUX):
-----------------------------------
# Watch process status
watch -n 1 cat /proc/1234/status

# Monitor file descriptors
ls -la /proc/1234/fd/

# View memory maps
cat /proc/1234/maps

# Check environment variables
cat /proc/1234/environ | tr '\0' '\n'

# View command line
cat /proc/1234/cmdline | tr '\0' ' '

# Monitor I/O statistics
cat /proc/1234/io

# Check process limits
cat /proc/1234/limits

# View network connections
cat /proc/1234/net/tcp

# Monitor stack usage
cat /proc/1234/stack

# Check namespace info
ls -la /proc/1234/ns/

PROCESS MONITORING PATTERNS:
----------------------------
# Follow process and children
strace -f -p $(pgrep parent_process)

# Monitor all threads
for tid in $(ls /proc/1234/task/); do
    echo "Thread $tid:"
    cat /proc/1234/task/$tid/status
done

# Track process CPU and memory
pidstat -u -r -p 1234 1

# Monitor file descriptor changes
watch -d ls -la /proc/1234/fd/

# Trace with filtering
strace -e trace=!futex,poll,select,nanosleep -p 1234

EOF
}

# ==============================================================================
# CROSS-PLATFORM SYSCALL TRACING
# ==============================================================================

trace-syscalls() {
    local pid=$1
    if [[ -z "$pid" ]]; then
        echo -e "${RED}Usage: trace-syscalls <pid>${NC}"
        return 1
    fi
    
    echo -e "${CYAN}Tracing syscalls for PID $pid...${NC}"
    if [[ "$OS" == "Linux" ]]; then
        if command -v strace &> /dev/null; then
            strace -f -t -p "$pid"
        else
            echo -e "${RED}strace not found. Install with: sudo apt-get install strace${NC}"
        fi
    elif [[ "$OS" == "Darwin" ]]; then
        sudo dtruss -f -t -p "$pid"
    fi
}

# ==============================================================================
# FILE OPERATION TRACING
# ==============================================================================

trace-files() {
    local pid=$1
    if [[ -z "$pid" ]]; then
        echo -e "${RED}Usage: trace-files <pid>${NC}"
        return 1
    fi
    
    echo -e "${CYAN}Tracing file operations for PID $pid...${NC}"
    if [[ "$OS" == "Linux" ]]; then
        if command -v strace &> /dev/null; then
            strace -e trace=file -f -t -p "$pid"
        else
            echo -e "${RED}strace not found${NC}"
        fi
    elif [[ "$OS" == "Darwin" ]]; then
        sudo dtrace -n "syscall::open*:entry /pid == $pid/ { printf(\"%s %s\", execname, copyinstr(arg0)); }"
    fi
}

# ==============================================================================
# NETWORK OPERATION TRACING
# ==============================================================================

trace-network() {
    local pid=$1
    if [[ -z "$pid" ]]; then
        echo -e "${RED}Usage: trace-network <pid>${NC}"
        return 1
    fi
    
    echo -e "${CYAN}Tracing network operations for PID $pid...${NC}"
    if [[ "$OS" == "Linux" ]]; then
        if command -v strace &> /dev/null; then
            strace -e trace=network -f -t -p "$pid"
        else
            echo -e "${RED}strace not found${NC}"
        fi
    elif [[ "$OS" == "Darwin" ]]; then
        sudo dtrace -n "syscall::connect*:entry,syscall::accept*:entry,syscall::send*:entry,syscall::recv*:entry /pid == $pid/ { printf(\"%s %s\", probefunc, execname); }"
    fi
}

# ==============================================================================
# TRACE COMMAND EXECUTION
# ==============================================================================

trace-exec() {
    local cmd=$1
    if [[ -z "$cmd" ]]; then
        echo -e "${RED}Usage: trace-exec <command>${NC}"
        return 1
    fi
    
    echo -e "${CYAN}Tracing execution: $cmd${NC}"
    if [[ "$OS" == "Linux" ]]; then
        if command -v strace &> /dev/null; then
            strace -f -t -e trace=all -o trace_output.log $cmd
            echo -e "${GREEN}Trace saved to trace_output.log${NC}"
        else
            echo -e "${RED}strace not found${NC}"
        fi
    elif [[ "$OS" == "Darwin" ]]; then
        sudo dtruss -f -t $cmd
    fi
}

# ==============================================================================
# PROCESS MONITORING IN /PROC (Linux only)
# ==============================================================================

proc-watch() {
    local pid=$1
    if [[ -z "$pid" ]]; then
        echo -e "${RED}Usage: proc-watch <pid>${NC}"
        return 1
    fi
    
    if [[ "$OS" != "Linux" ]]; then
        echo -e "${YELLOW}Warning: /proc monitoring is Linux-specific${NC}"
        echo -e "${CYAN}Using alternative process monitoring...${NC}"
        # Fall back to ps monitoring
        watch -n 1 "ps -p $pid -o pid,ppid,user,%cpu,%mem,vsz,rss,tty,stat,start,time,command"
        return
    fi
    
    if [[ ! -d "/proc/$pid" ]]; then
        echo -e "${RED}Process $pid not found in /proc${NC}"
        return 1
    fi
    
    echo -e "${CYAN}Watching /proc/$pid - Press Ctrl+C to stop${NC}"
    
    watch -n 1 -d "
        echo '=== STATUS ==='
        cat /proc/$pid/status | head -20
        echo
        echo '=== MEMORY ==='
        cat /proc/$pid/status | grep -E 'Vm|Rss'
        echo
        echo '=== IO ==='
        cat /proc/$pid/io 2>/dev/null || echo 'IO stats not available'
        echo
        echo '=== OPEN FILES ==='
        ls -la /proc/$pid/fd/ 2>/dev/null | head -10
        echo
        echo '=== CPU ==='
        cat /proc/$pid/stat | awk '{print \"User time: \" \$14/100 \"s, System time: \" \$15/100 \"s\"}'
    "
}

# ==============================================================================
# FIND PROCESS BY NAME
# ==============================================================================

proc-find() {
    local name=$1
    if [[ -z "$name" ]]; then
        echo -e "${RED}Usage: proc-find <process_name>${NC}"
        return 1
    fi
    
    echo -e "${CYAN}Searching for process: $name${NC}"
    
    local pids=$(pgrep -f "$name")
    if [[ -z "$pids" ]]; then
        echo -e "${YELLOW}No processes found matching: $name${NC}"
        return 1
    fi
    
    for pid in $pids; do
        echo -e "${GREEN}Found PID: $pid${NC}"
        if [[ "$OS" == "Linux" ]] && [[ -d "/proc/$pid" ]]; then
            echo "  Command: $(cat /proc/$pid/cmdline 2>/dev/null | tr '\0' ' ')"
            echo "  Status: $(cat /proc/$pid/status 2>/dev/null | grep State | head -1)"
            echo "  Memory: $(cat /proc/$pid/status 2>/dev/null | grep VmRSS)"
            echo "  Started: $(ps -p $pid -o lstart= 2>/dev/null)"
        else
            ps -p "$pid" -o pid,ppid,user,%cpu,%mem,command
        fi
        echo
    done
}

# ==============================================================================
# PROCESS TREE
# ==============================================================================

proc-tree() {
    local pid=$1
    if [[ -z "$pid" ]]; then
        echo -e "${RED}Usage: proc-tree <pid>${NC}"
        return 1
    fi
    
    echo -e "${CYAN}Process tree for PID $pid:${NC}"
    if command -v pstree &> /dev/null; then
        pstree -p "$pid"
    else
        # Fallback to ps
        ps -ejH | grep -E "^\s*$pid|PID" --color=always
    fi
}

# ==============================================================================
# SHOW OPEN FILES
# ==============================================================================

proc-files() {
    local pid=$1
    if [[ -z "$pid" ]]; then
        echo -e "${RED}Usage: proc-files <pid>${NC}"
        return 1
    fi
    
    echo -e "${CYAN}Open files for PID $pid:${NC}"
    if command -v lsof &> /dev/null; then
        lsof -p "$pid"
    elif [[ "$OS" == "Linux" ]] && [[ -d "/proc/$pid/fd" ]]; then
        echo -e "${YELLOW}Using /proc/fd (lsof not found):${NC}"
        ls -la "/proc/$pid/fd/" 2>/dev/null
        echo
        echo "File descriptors:"
        for fd in /proc/$pid/fd/*; do
            if [[ -e "$fd" ]]; then
                echo "  $(basename $fd) -> $(readlink $fd)"
            fi
        done
    else
        echo -e "${RED}lsof not found and /proc not available${NC}"
    fi
}

# ==============================================================================
# MEMORY MAPS
# ==============================================================================

proc-memory() {
    local pid=$1
    if [[ -z "$pid" ]]; then
        echo -e "${RED}Usage: proc-memory <pid>${NC}"
        return 1
    fi
    
    echo -e "${CYAN}Memory maps for PID $pid:${NC}"
    if [[ "$OS" == "Linux" ]] && [[ -f "/proc/$pid/maps" ]]; then
        cat "/proc/$pid/maps" | head -50
        echo "..."
        echo
        echo "Memory summary:"
        cat "/proc/$pid/status" | grep -E "Vm|Rss"
    elif [[ "$OS" == "Darwin" ]]; then
        vmmap "$pid" 2>/dev/null | head -50 || echo "vmmap failed - may need sudo"
    else
        echo -e "${RED}Memory maps not available${NC}"
    fi
}

# ==============================================================================
# SHOW THREADS
# ==============================================================================

proc-threads() {
    local pid=$1
    if [[ -z "$pid" ]]; then
        echo -e "${RED}Usage: proc-threads <pid>${NC}"
        return 1
    fi
    
    echo -e "${CYAN}Threads for PID $pid:${NC}"
    if [[ "$OS" == "Linux" ]] && [[ -d "/proc/$pid/task" ]]; then
        echo "Thread count: $(ls /proc/$pid/task | wc -l)"
        echo
        for tid in $(ls /proc/$pid/task); do
            if [[ "$tid" != "$pid" ]]; then
                echo "Thread $tid:"
                cat "/proc/$pid/task/$tid/status" 2>/dev/null | grep -E "Name|State|Tgid" | sed 's/^/  /'
            fi
        done
    else
        # Fallback to ps
        ps -T -p "$pid"
    fi
}

# ==============================================================================
# CPU TRACING
# ==============================================================================

trace-cpu() {
    local pid=$1
    if [[ -z "$pid" ]]; then
        echo -e "${RED}Usage: trace-cpu <pid>${NC}"
        return 1
    fi
    
    echo -e "${CYAN}Tracing CPU usage for PID $pid...${NC}"
    if [[ "$OS" == "Linux" ]]; then
        if command -v perf &> /dev/null; then
            echo "Recording CPU samples for 10 seconds..."
            sudo perf record -F 99 -p "$pid" -g -- sleep 10
            sudo perf report
        elif command -v pidstat &> /dev/null; then
            pidstat -u -p "$pid" 1
        else
            echo -e "${YELLOW}Using top (install perf or sysstat for better tracing)${NC}"
            top -p "$pid"
        fi
    elif [[ "$OS" == "Darwin" ]]; then
        sudo dtrace -n "profile-997 /pid == $pid/ { @[ustack()] = count(); } tick-10s { exit(0); }"
    fi
}

# ==============================================================================
# I/O TRACING
# ==============================================================================

trace-io() {
    local pid=$1
    if [[ -z "$pid" ]]; then
        echo -e "${RED}Usage: trace-io <pid>${NC}"
        return 1
    fi
    
    echo -e "${CYAN}Tracing I/O operations for PID $pid...${NC}"
    if [[ "$OS" == "Linux" ]]; then
        if command -v iotop &> /dev/null; then
            sudo iotop -p "$pid"
        elif command -v pidstat &> /dev/null; then
            pidstat -d -p "$pid" 1
        elif [[ -f "/proc/$pid/io" ]]; then
            echo "Watching /proc/$pid/io..."
            watch -n 1 cat "/proc/$pid/io"
        else
            echo -e "${RED}No I/O tracing tools available${NC}"
        fi
    elif [[ "$OS" == "Darwin" ]]; then
        sudo dtrace -n "syscall::read:entry,syscall::write:entry /pid == $pid/ { @[probefunc] = quantize(arg2); }"
    fi
}

# ==============================================================================
# ADVANCED DTRACE SCRIPTS (macOS)
# ==============================================================================

if [[ "$OS" == "Darwin" ]]; then
    dtrace-malloc() {
        local pid=$1
        if [[ -z "$pid" ]]; then
            echo -e "${RED}Usage: dtrace-malloc <pid>${NC}"
            return 1
        fi
        echo -e "${CYAN}Tracing malloc calls for PID $pid...${NC}"
        sudo dtrace -n "pid$pid::malloc:entry { @bytes = quantize(arg0); @calls = count(); } tick-5s { printa(@bytes); printa(\"Total calls: %@d\n\", @calls); clear(@bytes); clear(@calls); }"
    }
    
    dtrace-latency() {
        echo -e "${CYAN}Measuring system call latency...${NC}"
        sudo dtrace -n 'syscall:::entry { self->start = timestamp; } syscall:::return /self->start/ { @time[probefunc] = quantize(timestamp - self->start); self->start = 0; } tick-10s { exit(0); }'
    }
fi

# ==============================================================================
# ADVANCED LINUX TRACING
# ==============================================================================

if [[ "$OS" == "Linux" ]]; then
    trace-kernel() {
        local function=$1
        if [[ -z "$function" ]]; then
            echo -e "${RED}Usage: trace-kernel <kernel_function>${NC}"
            echo "Example: trace-kernel do_sys_open"
            return 1
        fi
        
        if [[ ! -d "/sys/kernel/debug/tracing" ]]; then
            echo -e "${RED}Kernel tracing not available (debugfs not mounted?)${NC}"
            return 1
        fi
        
        echo -e "${CYAN}Tracing kernel function: $function${NC}"
        echo "$function" | sudo tee /sys/kernel/debug/tracing/set_ftrace_filter
        echo function | sudo tee /sys/kernel/debug/tracing/current_tracer
        echo 1 | sudo tee /sys/kernel/debug/tracing/tracing_on
        
        echo "Tracing enabled. Reading trace buffer..."
        sleep 2
        sudo cat /sys/kernel/debug/tracing/trace | head -50
        
        echo 0 | sudo tee /sys/kernel/debug/tracing/tracing_on
        echo nop | sudo tee /sys/kernel/debug/tracing/current_tracer
    }
    
    trace-bpf() {
        if ! command -v bpftrace &> /dev/null; then
            echo -e "${RED}bpftrace not found. Install with: sudo apt-get install bpftrace${NC}"
            return 1
        fi
        
        echo -e "${CYAN}BPF Trace Quick Commands:${NC}"
        echo "1. Trace all syscalls: sudo bpftrace -e 'tracepoint:raw_syscalls:sys_enter { @[comm] = count(); }'"
        echo "2. Trace file opens: sudo bpftrace -e 'tracepoint:syscalls:sys_enter_open { printf(\"%s %s\\n\", comm, str(args->filename)); }'"
        echo "3. TCP connections: sudo bpftrace -e 'kprobe:tcp_connect { printf(\"PID %d connecting\\n\", pid); }'"
        echo "4. Process creation: sudo bpftrace -e 'tracepoint:sched:sched_process_fork { printf(\"PID %d created %d\\n\", pid, args->child_pid); }'"
    }
fi

# ==============================================================================
# MAIN COMMAND DISPATCHER
# ==============================================================================

# Export all functions for use in shell (bash only, not zsh)
if [ -n "$BASH_VERSION" ]; then
    export -f trace-syscalls
    export -f trace-files
    export -f trace-network
    export -f trace-exec
    export -f proc-watch
    export -f proc-find
    export -f proc-tree
    export -f proc-files
    export -f proc-memory
    export -f proc-threads
    export -f trace-cpu
    export -f trace-io
    export -f trace_help
    export -f trace_examples
    
    if [[ "$OS" == "Darwin" ]]; then
        export -f dtrace-malloc
        export -f dtrace-latency
    fi
fi

if [[ "$OS" == "Linux" ]] && [ -n "$BASH_VERSION" ]; then
    export -f trace-kernel
    export -f trace-bpf
fi

# Show help if sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    trace_help
fi
# Silent loading when sourced