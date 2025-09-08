# Testing Neovim Auto-reload Feature

## How to test:
1. Open this file in Neovim
2. Make changes to this file from another editor or terminal
3. The file should auto-reload if you haven't made local changes

## Test scenarios:

### Scenario 1: No local changes
- Open this file in Neovim
- Edit it externally (e.g., `echo "External change" >> test_autoreload.md`)
- Switch back to Neovim - file should auto-reload

### Scenario 2: With local changes
- Open this file in Neovim
- Make a change but don't save
- Edit it externally
- Switch back to Neovim - you'll get a prompt with options:
  - Load from disk (discard local changes)
  - Keep local changes
  - Show diff

### Commands:
- `:WatchTest` - Check file watching status
- `:checktime` - Manually check for file changes

Initial content - modify this line externally to test!