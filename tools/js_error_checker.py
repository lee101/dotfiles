#!/usr/bin/env python3
import os
import sys

# Ensure local package is importable when running as a script
TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
PKG_DIR = os.path.join(TOOLS_DIR, 'js_error_checker')
if os.path.isdir(PKG_DIR):
    sys.path.insert(0, PKG_DIR)

try:
    from js_error_checker.main import main as _main
except Exception:
    # Fallback to the simple checker if the package import fails
    simple = os.path.join(TOOLS_DIR, 'jscheck_simple.py')
    os.execvp(sys.executable, [sys.executable, simple] + sys.argv[1:])
else:
    if __name__ == "__main__":
        _main()
