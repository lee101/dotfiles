#!/usr/bin/env python3
"""Example script to generate a profile file for testing."""

import time
import cProfile
import random


def slow_function():
    """Simulate a slow function."""
    time.sleep(0.1)
    return sum(i for i in range(100000))


def medium_function():
    """Simulate a medium speed function."""
    time.sleep(0.05)
    return [i**2 for i in range(10000)]


def fast_function():
    """Simulate a fast function."""
    return random.randint(1, 100)


def recursive_function(n):
    """Simulate a recursive function."""
    if n <= 0:
        return 1
    time.sleep(0.001)
    return n * recursive_function(n - 1)


def main():
    """Main function that calls various functions."""
    results = []
    
    # Call functions multiple times
    for _ in range(5):
        results.append(slow_function())
    
    for _ in range(10):
        results.append(medium_function())
    
    for _ in range(100):
        results.append(fast_function())
    
    # Some recursive calls
    for i in range(1, 6):
        results.append(recursive_function(i))
    
    return results


if __name__ == '__main__':
    # Create a sample profile
    profiler = cProfile.Profile()
    profiler.enable()
    
    main()
    
    profiler.disable()
    profiler.dump_stats('example.prof')
    
    print("Profile saved to example.prof")
    print("Run: flamegraph-analyzer example.prof -o example-analysis.md")