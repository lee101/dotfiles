#!/bin/bash

# Generate tags for project and store in centralized location
PROJECT_DIR="${1:-$(pwd)}"
PROJECT_NAME=$(basename "$PROJECT_DIR")
TAGS_DIR="$HOME/.tags"
TAGS_FILE="$TAGS_DIR/${PROJECT_NAME}.tags"

# Create tags directory if it doesn't exist
mkdir -p "$TAGS_DIR"

echo "Generating tags for: $PROJECT_DIR"
echo "Output file: $TAGS_FILE"

# Detect project type
if [ -f "$PROJECT_DIR/requirements.txt" ] || [ -f "$PROJECT_DIR/setup.py" ] || [ -f "$PROJECT_DIR/pyproject.toml" ]; then
    LANG_FLAGS="--languages=python --python-kinds=-i"
    echo "Detected Python project"
elif [ -f "$PROJECT_DIR/package.json" ]; then
    LANG_FLAGS="--languages=javascript,typescript"
    echo "Detected JavaScript/TypeScript project"
elif [ -f "$PROJECT_DIR/Cargo.toml" ]; then
    LANG_FLAGS="--languages=rust"
    echo "Detected Rust project"
elif [ -f "$PROJECT_DIR/go.mod" ]; then
    LANG_FLAGS="--languages=go"
    echo "Detected Go project"
else
    LANG_FLAGS=""
    echo "Generating tags for all languages"
fi

# Check if universal-ctags is available
if command -v ctags >/dev/null 2>&1; then
    # Generate tags
    cd "$PROJECT_DIR"
    ctags -R $LANG_FLAGS \
        --exclude=.git \
        --exclude=__pycache__ \
        --exclude="*.pyc" \
        --exclude=venv \
        --exclude=.venv \
        --exclude=node_modules \
        --exclude=target \
        --exclude=dist \
        --exclude=build \
        -f "$TAGS_FILE" \
        .
    
    # Also create a local symlink for convenience
    ln -sf "$TAGS_FILE" "$PROJECT_DIR/tags"
    
    echo "Tags file generated successfully!"
    echo "  - Central location: $TAGS_FILE"
    echo "  - Local symlink: $PROJECT_DIR/tags"
else
    echo "ctags not found. Please install universal-ctags:"
    echo "  Ubuntu/Debian: sudo apt-get install universal-ctags"
    echo "  macOS: brew install universal-ctags"
    echo "  Fedora: sudo dnf install ctags"
    exit 1
fi