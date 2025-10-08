#!/bin/bash
# CUDA auto-detection with caching for fast startup
# Silent operation - no output unless DEBUG_CUDA=1

CACHE_FILE="$HOME/.cache/cuda_env_cache"
CACHE_TTL=86400  # 24 hours

# Check cache validity
if [ -f "$CACHE_FILE" ]; then
    CACHE_AGE=$(($(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)))
    if [ $CACHE_AGE -lt $CACHE_TTL ]; then
        source "$CACHE_FILE"
        return 0 2>/dev/null || exit 0
    fi
fi

# Detect CUDA
if command -v nvidia-smi &>/dev/null; then
    CUDA_VERSION=$(nvidia-smi 2>/dev/null | grep -oP 'CUDA Version: \K[0-9]+\.[0-9]+' | head -1)
    if [ -n "$CUDA_VERSION" ]; then
        CUDA_MAJOR=${CUDA_VERSION%%.*}
        CUDA_MINOR=${CUDA_VERSION#*.}
        CUDA_MINOR=${CUDA_MINOR%%.*}

        # Find CUDA installation
        for path in "/usr/local/cuda-${CUDA_MAJOR}.${CUDA_MINOR}" \
                   "/usr/local/cuda-${CUDA_MAJOR}" \
                   "/usr/local/cuda"; do
            if [ -d "$path" ]; then
                CUDA_PATH="$path"
                break
            fi
        done

        # Select GCC version
        if [ "$CUDA_MAJOR" = "12" ]; then
            if [ "$CUDA_MINOR" -ge "3" ] && command -v gcc-13 &>/dev/null; then
                CUDA_GCC="gcc-13"
                CUDA_GXX="g++-13"
            elif command -v gcc-12 &>/dev/null; then
                CUDA_GCC="gcc-12"
                CUDA_GXX="g++-12"
            else
                CUDA_GCC="gcc"
                CUDA_GXX="g++"
            fi
        elif [ "$CUDA_MAJOR" = "11" ] && command -v gcc-11 &>/dev/null; then
            CUDA_GCC="gcc-11"
            CUDA_GXX="g++-11"
        else
            CUDA_GCC="gcc"
            CUDA_GXX="g++"
        fi
    fi
fi

# Set defaults if no CUDA
CUDA_PATH="${CUDA_PATH:-}"
CUDA_GCC="${CUDA_GCC:-gcc}"
CUDA_GXX="${CUDA_GXX:-g++}"
CUDA_VERSION="${CUDA_VERSION:-}"

# Write cache
mkdir -p "$(dirname "$CACHE_FILE")"
cat > "$CACHE_FILE" <<EOF
export CUDA_VERSION="$CUDA_VERSION"
export CUDA_PATH="$CUDA_PATH"
export CUDA_GCC="$CUDA_GCC"
export CUDA_GXX="$CUDA_GXX"
EOF

if [ -n "$CUDA_PATH" ]; then
    cat >> "$CACHE_FILE" <<EOF
export PATH="$CUDA_PATH/bin:\$PATH"
export LD_LIBRARY_PATH="$CUDA_PATH/lib64:\${LD_LIBRARY_PATH}"
export CGO_CFLAGS="-I$CUDA_PATH/include"
export CGO_LDFLAGS="-L$CUDA_PATH/lib64 -lcudart -lcublas -lcublasLt"
export USE_GPU=true
export CUDA_ENABLED=true
export GPU_ENABLED=true
EOF
else
    cat >> "$CACHE_FILE" <<EOF
export USE_GPU=false
export CUDA_ENABLED=false
export GPU_ENABLED=false
EOF
fi

# Source the cache
source "$CACHE_FILE"