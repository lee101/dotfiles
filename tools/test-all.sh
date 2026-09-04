#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if command -v shellcheck >/dev/null 2>&1; then
	shellcheck --shell=bash --severity=error \
		"$repo_dir/lib/common_shell" \
		"$repo_dir/bashrc" \
		"$repo_dir/bash_profile" \
		"$repo_dir/tools/test-all.sh" \
		"$repo_dir/tools/test-shell-config.sh" \
		"$repo_dir/setup-developer.sh"
else
	echo "WARN: shellcheck is not installed; skipping shell lint" >&2
fi

"$repo_dir/tools/test-shell-config.sh"

if python3 -m pytest --version >/dev/null 2>&1; then
	python3 -m pytest -q "$repo_dir/tools/tests" "$repo_dir/profiling/tests"
else
	echo "WARN: pytest is not installed; running unittest tests only" >&2
	python3 -m unittest discover -s "$repo_dir/tools/tests" -p 'test_*.py'
fi

if command -v nvim >/dev/null 2>&1 && command -v rg >/dev/null 2>&1; then
	"$repo_dir/test_nvim_config.sh"
else
	echo "WARN: skipping Neovim config test (requires nvim and rg)" >&2
fi

echo "PASS: all available repository tests"
