# Neovim setup agent

This is the repeatable bootstrap path for a fresh Linux, WSL, Git Bash, or Windows machine.

## Run it

- Windows PowerShell: `pwsh -File .\subagent\nvim-setup-agent.ps1`
- Linux/WSL/macOS: `bash ./subagent/nvim-setup-agent.sh`

The agent:

1. Uses `nvim/` as the single canonical config directory.
2. Backs up an existing config before linking it.
3. Installs/synchronizes Lazy plugins and Tree-sitter parsers.
4. Makes `vi` invoke Neovim on Windows through `~/bin/vi.cmd`.
5. Enables the optional local `text-generator-nvim` plugin when it exists.
6. Runs a headless startup/health check and leaves actionable warnings instead of hiding errors.

To clone the optional text generator automatically, set `TEXT_GENERATOR_NVIM_REPO` before running the agent. Optionally set `TEXT_GENERATOR_NVIM_DIR` to choose its checkout path.
