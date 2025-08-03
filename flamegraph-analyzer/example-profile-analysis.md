# Profile Analysis: example.prof

## Summary

Total functions profiled: 16

Total execution time: 3.371 seconds

## Top Time-Consuming Functions

| Function | Cumulative Time | Own Time | Calls | Time % |
|----------|----------------|----------|-------|--------|
| main (example_profiler.py:34) | 1.114s | 0.000s | 1 | 33.0% |
| <built-in method time.sleep> (~:0) | 1.017s | 1.017s | 30 | 30.2% |
| slow_function (example_profiler.py:9) | 0.586s | 0.000s | 5 | 17.4% |
| medium_function (example_profiler.py:15) | 0.512s | 0.011s | 10 | 15.2% |
| <built-in method builtins.sum> (~:0) | 0.085s | 0.045s | 5 | 2.5% |
| <genexpr> (example_profiler.py:12) | 0.040s | 0.040s | 500005 | 1.2% |
| recursive_function (example_profiler.py:26) | 0.016s | 0.000s | 20 | 0.5% |
| fast_function (example_profiler.py:21) | 0.000s | 0.000s | 100 | 0.0% |
| randint (random.py:332) | 0.000s | 0.000s | 100 | 0.0% |
| randrange (random.py:291) | 0.000s | 0.000s | 100 | 0.0% |
| _randbelow_with_getrandbits (random.py:242) | 0.000s | 0.000s | 100 | 0.0% |
| <method 'append' of 'list' objects> (~:0) | 0.000s | 0.000s | 120 | 0.0% |
| <built-in method _operator.index> (~:0) | 0.000s | 0.000s | 300 | 0.0% |
| <method 'bit_length' of 'int' objects> (~:0) | 0.000s | 0.000s | 100 | 0.0% |
| <method 'disable' of '_lsprof.Profiler' objects... | 0.000s | 0.000s | 1 | 0.0% |
| <method 'getrandbits' of '_random.Random' objec... | 0.000s | 0.000s | 129 | 0.0% |

## Performance Hotspots

Functions consuming more than 5% of total time:

### main (example_profiler.py:34)
- **Cumulative time**: 1.114s (33.0%)
- **Own time**: 0.000s
- **Number of calls**: 1

### <built-in method time.sleep> (~:0)
- **Cumulative time**: 1.017s (30.2%)
- **Own time**: 1.017s
- **Number of calls**: 30

### slow_function (example_profiler.py:9)
- **Cumulative time**: 0.586s (17.4%)
- **Own time**: 0.000s
- **Number of calls**: 5

### medium_function (example_profiler.py:15)
- **Cumulative time**: 0.512s (15.2%)
- **Own time**: 0.011s
- **Number of calls**: 10
