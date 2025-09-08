#!/usr/bin/env python3
"""
AutoFlame - Multi-language flame graph generator with automatic language detection
"""

import os
import sys
import subprocess
import tempfile
import json
import argparse
import time
import csv
from pathlib import Path
from typing import Optional, Dict, List, Tuple

class LanguageDetector:
    """Detect programming language from file extension and content"""
    
    EXTENSIONS = {
        '.py': 'python',
        '.go': 'golang',
        '.rs': 'rust',
        '.js': 'javascript',
        '.ts': 'typescript',
        '.java': 'java',
        '.c': 'c',
        '.cpp': 'cpp',
        '.rb': 'ruby',
        '.php': 'php',
        '.swift': 'swift',
        '.kt': 'kotlin',
        '.scala': 'scala',
        '.jl': 'julia',
        '.r': 'r',
        '.R': 'r'
    }
    
    @classmethod
    def detect(cls, filepath: str) -> Optional[str]:
        """Detect language from file"""
        path = Path(filepath)
        
        # Check extension
        if path.suffix in cls.EXTENSIONS:
            return cls.EXTENSIONS[path.suffix]
        
        # Check shebang
        if path.exists():
            try:
                with open(path, 'r') as f:
                    first_line = f.readline().strip()
                    if first_line.startswith('#!'):
                        if 'python' in first_line:
                            return 'python'
                        elif 'node' in first_line:
                            return 'javascript'
                        elif 'ruby' in first_line:
                            return 'ruby'
                        elif 'php' in first_line:
                            return 'php'
            except:
                pass
        
        return None

class FlameGraphGenerator:
    """Generate flame graphs for different languages"""
    
    def __init__(self, output_dir: str = None):
        self.output_dir = output_dir or tempfile.gettempdir()
        self.timestamp = int(time.time())
        
    def generate_python(self, script: str, args: List[str] = None) -> str:
        """Generate flame graph for Python script"""
        output_file = f"{self.output_dir}/flame_python_{self.timestamp}.csv"
        
        # Use py-spy for Python profiling
        cmd = ['py-spy', 'record', '-f', 'raw', '-o', output_file, '--', 'python', script]
        if args:
            cmd.extend(args)
        
        try:
            subprocess.run(cmd, check=True, capture_output=True, text=True)
        except subprocess.CalledProcessError:
            # Fallback to cProfile if py-spy not available
            return self._python_cprofile_fallback(script, args)
        except FileNotFoundError:
            # py-spy not installed, use cProfile
            return self._python_cprofile_fallback(script, args)
        
        return self._convert_to_csv(output_file)
    
    def _python_cprofile_fallback(self, script: str, args: List[str] = None) -> str:
        """Fallback to cProfile for Python profiling"""
        import cProfile
        import pstats
        import io
        
        output_file = f"{self.output_dir}/flame_python_{self.timestamp}.csv"
        profile_file = f"{self.output_dir}/profile_{self.timestamp}.prof"
        
        # Run with cProfile
        cmd = ['python', '-m', 'cProfile', '-o', profile_file, script]
        if args:
            cmd.extend(args)
        
        subprocess.run(cmd, check=True)
        
        # Convert to CSV format
        stats = pstats.Stats(profile_file)
        
        with open(output_file, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(['function', 'calls', 'total_time', 'cumulative_time', 'stack'])
            
            for func, (cc, nc, tt, ct, callers) in stats.stats.items():
                filename, line, name = func
                stack = f"{filename}:{line}:{name}"
                writer.writerow([name, nc, tt, ct, stack])
        
        os.remove(profile_file)
        return output_file
    
    def generate_golang(self, file: str, test: bool = False) -> str:
        """Generate flame graph for Go program"""
        output_file = f"{self.output_dir}/flame_go_{self.timestamp}.csv"
        profile_file = f"{self.output_dir}/cpu_{self.timestamp}.prof"
        
        if test:
            # Run go test with profiling
            cmd = ['go', 'test', '-cpuprofile', profile_file, file]
        else:
            # Build and run with profiling
            binary = f"{self.output_dir}/go_binary_{self.timestamp}"
            subprocess.run(['go', 'build', '-o', binary, file], check=True)
            
            # Run with pprof
            cmd = [binary]
            # Note: Go programs need to be instrumented with pprof
            # This assumes the program has pprof support built-in
        
        subprocess.run(cmd, check=True)
        
        # Convert pprof to CSV
        return self._convert_pprof_to_csv(profile_file, output_file)
    
    def _convert_pprof_to_csv(self, profile_file: str, output_file: str) -> str:
        """Convert Go pprof profile to CSV"""
        # Use go tool pprof to export data
        cmd = ['go', 'tool', 'pprof', '-raw', profile_file]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        
        with open(output_file, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(['function', 'samples', 'percentage', 'stack'])
            
            # Parse pprof output (simplified)
            lines = result.stdout.strip().split('\n')
            for line in lines:
                if line and not line.startswith('#'):
                    parts = line.split()
                    if len(parts) >= 2:
                        writer.writerow(parts)
        
        return output_file
    
    def generate_rust(self, file: str) -> str:
        """Generate flame graph for Rust program"""
        output_file = f"{self.output_dir}/flame_rust_{self.timestamp}.csv"
        
        # Build with release mode
        subprocess.run(['cargo', 'build', '--release'], check=True, cwd=os.path.dirname(file))
        
        # Use cargo-flamegraph if available
        try:
            cmd = ['cargo', 'flamegraph', '--output', output_file]
            subprocess.run(cmd, check=True, cwd=os.path.dirname(file))
        except:
            # Fallback to perf on Linux
            binary = self._find_rust_binary(file)
            return self._generate_perf_flamegraph(binary, output_file)
        
        return output_file
    
    def _find_rust_binary(self, file: str) -> str:
        """Find the compiled Rust binary"""
        project_dir = Path(file).parent
        while project_dir != project_dir.parent:
            cargo_toml = project_dir / 'Cargo.toml'
            if cargo_toml.exists():
                # Parse Cargo.toml to get binary name
                with open(cargo_toml) as f:
                    for line in f:
                        if 'name' in line and '=' in line:
                            name = line.split('=')[1].strip().strip('"')
                            binary = project_dir / 'target' / 'release' / name
                            if binary.exists():
                                return str(binary)
                break
            project_dir = project_dir.parent
        return None
    
    def _generate_perf_flamegraph(self, binary: str, output_file: str) -> str:
        """Generate flame graph using perf (Linux)"""
        perf_data = f"{self.output_dir}/perf_{self.timestamp}.data"
        
        # Record with perf
        subprocess.run(['perf', 'record', '-F', '99', '-g', '--', binary], check=True)
        
        # Convert to flame graph format
        subprocess.run(['perf', 'script'], stdout=open(perf_data, 'w'), check=True)
        
        # Convert to CSV
        with open(perf_data) as f, open(output_file, 'w', newline='') as out:
            writer = csv.writer(out)
            writer.writerow(['function', 'samples', 'stack'])
            
            # Parse perf script output (simplified)
            for line in f:
                if line.strip() and not line.startswith('#'):
                    parts = line.strip().split()
                    if parts:
                        writer.writerow(parts[:3])
        
        return output_file
    
    def generate_javascript(self, file: str) -> str:
        """Generate flame graph for JavaScript/Node.js"""
        output_file = f"{self.output_dir}/flame_js_{self.timestamp}.csv"
        
        # Use node --prof
        prof_file = f"isolate-{self.timestamp}.log"
        subprocess.run(['node', '--prof', file], check=True)
        
        # Process the prof log
        subprocess.run(['node', '--prof-process', prof_file], 
                      stdout=open(output_file, 'w'), check=True)
        
        # Clean up
        if os.path.exists(prof_file):
            os.remove(prof_file)
        
        return self._convert_node_prof_to_csv(output_file)
    
    def _convert_node_prof_to_csv(self, prof_output: str) -> str:
        """Convert Node.js prof output to CSV"""
        csv_file = prof_output.replace('.txt', '.csv')
        
        with open(prof_output) as f, open(csv_file, 'w', newline='') as out:
            writer = csv.writer(out)
            writer.writerow(['function', 'ticks', 'percentage', 'type'])
            
            in_summary = False
            for line in f:
                if '[Summary]' in line:
                    in_summary = True
                elif in_summary and line.strip():
                    parts = line.strip().split()
                    if len(parts) >= 3:
                        writer.writerow(parts)
        
        return csv_file
    
    def _convert_to_csv(self, raw_file: str) -> str:
        """Convert raw flame graph data to CSV"""
        # This is a generic converter, specific formats need specific handling
        csv_file = raw_file.replace('.raw', '.csv').replace('.txt', '.csv')
        
        if csv_file == raw_file:
            csv_file = f"{raw_file}.csv"
        
        with open(raw_file) as f, open(csv_file, 'w', newline='') as out:
            writer = csv.writer(out)
            writer.writerow(['stack', 'count'])
            
            for line in f:
                if line.strip():
                    # Assume format: stack_trace count
                    parts = line.rsplit(' ', 1)
                    if len(parts) == 2:
                        writer.writerow(parts)
        
        return csv_file
    
    def generate(self, filepath: str, language: str = None, **kwargs) -> str:
        """Generate flame graph for given file"""
        if not language:
            language = LanguageDetector.detect(filepath)
        
        if not language:
            raise ValueError(f"Could not detect language for {filepath}")
        
        generators = {
            'python': self.generate_python,
            'golang': self.generate_golang,
            'go': self.generate_golang,
            'rust': self.generate_rust,
            'javascript': self.generate_javascript,
            'js': self.generate_javascript,
            'typescript': self.generate_javascript,
            'ts': self.generate_javascript,
        }
        
        generator = generators.get(language)
        if not generator:
            raise ValueError(f"No flame graph generator for {language}")
        
        return generator(filepath, **kwargs)

class FlameGraphAnalyzer:
    """Analyze flame graphs and convert to readable format"""
    
    @staticmethod
    def csv_to_markdown(csv_file: str, top_n: int = 20) -> str:
        """Convert CSV flame graph to markdown analysis"""
        analysis = []
        analysis.append("# Flame Graph Analysis\n")
        
        # Read CSV
        data = []
        with open(csv_file, 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                data.append(row)
        
        if not data:
            return "No profiling data found"
        
        # Sort by time/samples
        sort_key = 'samples' if 'samples' in data[0] else 'count'
        if sort_key in data[0]:
            try:
                data.sort(key=lambda x: float(x.get(sort_key, 0)), reverse=True)
            except:
                pass
        
        # Top functions
        analysis.append("## Top Hot Functions\n")
        analysis.append("| Function | Samples/Time | Stack |\n")
        analysis.append("|----------|-------------|-------|\n")
        
        for i, row in enumerate(data[:top_n]):
            func = row.get('function', row.get('stack', 'unknown'))
            samples = row.get(sort_key, row.get('total_time', '0'))
            stack = row.get('stack', '')
            
            # Truncate long names
            if len(func) > 50:
                func = func[:47] + "..."
            if len(stack) > 60:
                stack = "..." + stack[-57:]
            
            analysis.append(f"| {func} | {samples} | {stack} |\n")
        
        # Summary statistics
        analysis.append("\n## Summary Statistics\n")
        total_samples = sum(float(row.get(sort_key, 0)) for row in data if row.get(sort_key))
        analysis.append(f"- Total functions: {len(data)}\n")
        analysis.append(f"- Total samples: {total_samples:.0f}\n")
        
        # Hot paths
        analysis.append("\n## Hot Code Paths\n")
        stacks = {}
        for row in data:
            stack = row.get('stack', '')
            if stack:
                # Extract file:line patterns
                parts = stack.split(';')
                for part in parts:
                    if ':' in part:
                        file_line = part.rsplit(':', 1)[0]
                        stacks[file_line] = stacks.get(file_line, 0) + float(row.get(sort_key, 0))
        
        sorted_stacks = sorted(stacks.items(), key=lambda x: x[1], reverse=True)
        for path, count in sorted_stacks[:10]:
            analysis.append(f"- {path}: {count:.0f} samples\n")
        
        return ''.join(analysis)
    
    @staticmethod
    def generate_optimization_prompt(csv_file: str) -> str:
        """Generate a prompt for optimization based on flame graph"""
        analysis = FlameGraphAnalyzer.csv_to_markdown(csv_file)
        
        prompt = f"""Based on the following flame graph analysis, identify performance bottlenecks and suggest optimizations:

{analysis}

Please provide:
1. Top 3 performance bottlenecks
2. Specific optimization strategies for each bottleneck
3. Code examples or refactoring suggestions
4. Estimated performance improvement potential
"""
        return prompt

def main():
    parser = argparse.ArgumentParser(description='AutoFlame - Multi-language flame graph generator')
    parser.add_argument('file', help='File to profile')
    parser.add_argument('-l', '--language', help='Force language detection')
    parser.add_argument('-o', '--output', help='Output directory', default='/tmp')
    parser.add_argument('-t', '--test', action='store_true', help='Run as test (for Go)')
    parser.add_argument('-a', '--analyze', action='store_true', help='Analyze and convert to markdown')
    parser.add_argument('-p', '--prompt', action='store_true', help='Generate optimization prompt')
    parser.add_argument('--top', type=int, default=20, help='Top N functions to show')
    
    args = parser.parse_args()
    
    generator = FlameGraphGenerator(args.output)
    
    try:
        csv_file = generator.generate(args.file, args.language, test=args.test)
        print(f"Flame graph generated: {csv_file}")
        
        if args.analyze:
            analysis = FlameGraphAnalyzer.csv_to_markdown(csv_file, args.top)
            print("\n" + analysis)
            
            # Save analysis to file
            md_file = csv_file.replace('.csv', '_analysis.md')
            with open(md_file, 'w') as f:
                f.write(analysis)
            print(f"\nAnalysis saved to: {md_file}")
        
        if args.prompt:
            prompt = FlameGraphAnalyzer.generate_optimization_prompt(csv_file)
            prompt_file = csv_file.replace('.csv', '_prompt.txt')
            with open(prompt_file, 'w') as f:
                f.write(prompt)
            print(f"\nOptimization prompt saved to: {prompt_file}")
            
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()