#!/usr/bin/env bash
# Symlink the mojo tools onto PATH and the skills into ~/.claude/skills.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="${1:-$HOME/.local/bin}"
SKILLS="${2:-$HOME/.claude/skills}"

mkdir -p "$BIN" "$SKILLS"

for t in mojoflame mojomem mojoasm mojolint mojobench mojogpu mojoffi mojoparity; do
    chmod +x "$HERE/bin/$t"
    ln -sfn "$HERE/bin/$t" "$BIN/$t"
    echo "bin  $BIN/$t"
done

for s in "$HERE"/skills/*/; do
    name="$(basename "$s")"
    ln -sfn "${s%/}" "$SKILLS/$name"
    echo "skill $SKILLS/$name"
done

case ":$PATH:" in
    *":$BIN:"*) ;;
    *) echo "note: $BIN is not on PATH" ;;
esac

command -v gcc      >/dev/null || echo "missing: gcc      (mojomem allocation shim)"
command -v gdb      >/dev/null || echo "missing: gdb      (mojoflame sampling)"
command -v addr2line>/dev/null || echo "missing: addr2line (binutils; mojomem symbolization)"
command -v objdump  >/dev/null || echo "missing: objdump  (binutils; mojoasm --bin)"
command -v nm       >/dev/null || echo "missing: nm       (binutils; mojoffi --check)"
python3 -c "import numpy" 2>/dev/null || echo "missing: numpy    (mojoparity)"
command -v valgrind >/dev/null || echo "optional: valgrind (mojomem --tool dhat|massif)"
