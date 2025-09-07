#!/usr/bin/env python3
"""
Flame Graph Agent - Analyzes flame graphs and provides optimization suggestions
Integrates with Claude for advanced code analysis
"""

import os
import sys
import subprocess
import json
import argparse
import tempfile
from pathlib import Path
from typing import Dict, List, Optional

class FlameAgent:
    """Agent for analyzing flame graphs and providing optimizations"""
    
    def __init__(self, claude_path: str = "claude"):
        self.claude_path = claude_path
        self.autoflame_path = Path(__file__).parent / "autoflame.py"
        
    def profile_and_analyze(self, target: str, language: str = None) -> Dict:
        """Profile a target and analyze with Claude"""
        
        # Generate flame graph
        print(f"Generating flame graph for {target}...")
        csv_file = self._generate_flamegraph(target, language)
        
        # Convert to markdown analysis
        print("Analyzing flame graph...")
        analysis = self._analyze_flamegraph(csv_file)
        
        # Get optimization suggestions from Claude
        print("Getting optimization suggestions...")
        suggestions = self._get_claude_suggestions(target, analysis)
        
        return {
            'target': target,
            'language': language,
            'csv_file': csv_file,
            'analysis': analysis,
            'suggestions': suggestions
        }
    
    def _generate_flamegraph(self, target: str, language: str = None) -> str:
        """Generate flame graph using autoflame"""
        cmd = ['python', str(self.autoflame_path), target]
        if language:
            cmd.extend(['-l', language])
        cmd.extend(['-a'])  # Include analysis
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            raise RuntimeError(f"Failed to generate flame graph: {result.stderr}")
        
        # Extract CSV file path from output
        for line in result.stdout.split('\n'):
            if 'Flame graph generated:' in line:
                return line.split(': ')[1].strip()
        
        raise RuntimeError("Could not find generated flame graph file")
    
    def _analyze_flamegraph(self, csv_file: str) -> str:
        """Analyze flame graph and convert to markdown"""
        # Read the analysis file that autoflame creates
        analysis_file = csv_file.replace('.csv', '_analysis.md')
        if os.path.exists(analysis_file):
            with open(analysis_file) as f:
                return f.read()
        
        # Fallback: generate analysis
        cmd = ['python', str(self.autoflame_path), csv_file, '-a']
        result = subprocess.run(cmd, capture_output=True, text=True)
        return result.stdout
    
    def _get_claude_suggestions(self, target: str, analysis: str) -> str:
        """Get optimization suggestions from Claude"""
        
        # Read the target file
        target_content = ""
        if os.path.exists(target):
            with open(target) as f:
                target_content = f.read()
        
        # Create prompt
        prompt = f"""I have profiled the following code and generated a flame graph analysis. 
Please analyze the performance bottlenecks and provide specific optimization suggestions.

## Target File: {target}

```
{target_content[:5000]}  # Limit to first 5000 chars
```

## Flame Graph Analysis:

{analysis}

Please provide:
1. Identification of the top 3 performance bottlenecks based on the flame graph
2. Specific code optimizations for each bottleneck
3. Example refactored code snippets
4. Estimated performance improvements
5. Any architectural changes that could help

Focus on practical, implementable solutions."""
        
        # Call Claude with the prompt
        with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
            f.write(prompt)
            prompt_file = f.name
        
        try:
            # Use dangerous skip permissions for agent mode
            cmd = [
                self.claude_path,
                '--dangerously-skip-permissions',
                '-m', prompt_file
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
            
            if result.returncode == 0:
                return result.stdout
            else:
                return f"Claude analysis failed: {result.stderr}"
                
        finally:
            os.remove(prompt_file)
    
    def optimize_code(self, target: str, suggestions: str) -> str:
        """Apply optimization suggestions to code"""
        
        prompt = f"""Based on these optimization suggestions, please generate the optimized version of the code:

Original file: {target}

Suggestions:
{suggestions}

Please provide the complete optimized code that implements the suggested improvements.
"""
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
            f.write(prompt)
            prompt_file = f.name
        
        try:
            cmd = [
                self.claude_path,
                '--dangerously-skip-permissions',
                '-m', prompt_file
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
            
            if result.returncode == 0:
                # Save optimized code
                optimized_file = target.replace('.', '_optimized.')
                with open(optimized_file, 'w') as f:
                    f.write(result.stdout)
                return optimized_file
            else:
                raise RuntimeError(f"Failed to optimize code: {result.stderr}")
                
        finally:
            os.remove(prompt_file)
    
    def compare_performance(self, original: str, optimized: str) -> Dict:
        """Compare performance between original and optimized code"""
        
        print("Profiling original code...")
        original_csv = self._generate_flamegraph(original)
        
        print("Profiling optimized code...")
        optimized_csv = self._generate_flamegraph(optimized)
        
        # Compare metrics
        original_stats = self._get_stats(original_csv)
        optimized_stats = self._get_stats(optimized_csv)
        
        improvement = {
            'total_time_reduction': (
                (original_stats['total'] - optimized_stats['total']) / 
                original_stats['total'] * 100
            ),
            'hot_functions_reduced': (
                len(original_stats['hot_functions']) - 
                len(optimized_stats['hot_functions'])
            ),
            'original_stats': original_stats,
            'optimized_stats': optimized_stats
        }
        
        return improvement
    
    def _get_stats(self, csv_file: str) -> Dict:
        """Extract statistics from CSV flame graph"""
        import csv
        
        total = 0
        hot_functions = []
        
        with open(csv_file) as f:
            reader = csv.DictReader(f)
            for row in reader:
                samples = float(row.get('samples', row.get('count', 0)))
                total += samples
                if samples > total * 0.05:  # Functions taking >5% time
                    hot_functions.append(row.get('function', 'unknown'))
        
        return {
            'total': total,
            'hot_functions': hot_functions
        }

def main():
    parser = argparse.ArgumentParser(description='Flame Graph Agent')
    parser.add_argument('target', help='Target file or command to profile')
    parser.add_argument('-l', '--language', help='Programming language')
    parser.add_argument('-o', '--optimize', action='store_true', 
                       help='Generate optimized code')
    parser.add_argument('-c', '--compare', action='store_true',
                       help='Compare performance after optimization')
    parser.add_argument('--claude-path', default='claude',
                       help='Path to Claude CLI')
    
    args = parser.parse_args()
    
    agent = FlameAgent(args.claude_path)
    
    try:
        # Profile and analyze
        result = agent.profile_and_analyze(args.target, args.language)
        
        print("\n" + "="*60)
        print("FLAME GRAPH ANALYSIS COMPLETE")
        print("="*60)
        print(f"\nTarget: {result['target']}")
        print(f"CSV File: {result['csv_file']}")
        print("\n--- Analysis ---")
        print(result['analysis'][:500] + "...")
        print("\n--- Suggestions ---")
        print(result['suggestions'][:1000] + "...")
        
        if args.optimize:
            print("\n" + "="*60)
            print("GENERATING OPTIMIZED CODE")
            print("="*60)
            optimized_file = agent.optimize_code(
                args.target, 
                result['suggestions']
            )
            print(f"Optimized code saved to: {optimized_file}")
            
            if args.compare:
                print("\n" + "="*60)
                print("PERFORMANCE COMPARISON")
                print("="*60)
                comparison = agent.compare_performance(
                    args.target,
                    optimized_file
                )
                print(f"Performance improvement: {comparison['total_time_reduction']:.2f}%")
                print(f"Hot functions reduced by: {comparison['hot_functions_reduced']}")
        
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()