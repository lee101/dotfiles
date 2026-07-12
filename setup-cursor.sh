#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The `cursor` on PATH is the Cursor AGENT CLI, which does NOT support
# --install-extension. We need the Cursor IDE (VS Code fork) CLI wrapper
# (bin/cursor), which lives inside the install or the AppImage.
CURSOR_BIN=""
for cand in \
  "/usr/share/cursor/bin/cursor" \
  "/opt/cursor/bin/cursor" \
  "/opt/Cursor/bin/cursor" \
  "${HOME}/programs/cursor-extracted/usr/share/cursor/bin/cursor"; do
  if [ -x "${cand}" ]; then
    CURSOR_BIN="${cand}"
    break
  fi
done

# Fall back to extracting the AppImage and using its bundled bin/cursor.
if [ -z "${CURSOR_BIN}" ]; then
  APPIMAGE="$(ls -1 "${HOME}/programs"/Cursor-*.AppImage 2>/dev/null | head -n1 || true)"
  if [ -n "${APPIMAGE}" ]; then
    EXTRACT_DIR="${HOME}/programs/cursor-extracted"
    if [ ! -x "${EXTRACT_DIR}/usr/share/cursor/bin/cursor" ]; then
      echo "Extracting ${APPIMAGE} ..."
      rm -rf "${HOME}/programs/squashfs-root" "${EXTRACT_DIR}"
      (cd "${HOME}/programs" && "${APPIMAGE}" --appimage-extract >/dev/null)
      mv "${HOME}/programs/squashfs-root" "${EXTRACT_DIR}"
    fi
    CURSOR_BIN="${EXTRACT_DIR}/usr/share/cursor/bin/cursor"
  fi
fi

if [ -z "${CURSOR_BIN}" ] || [ ! -x "${CURSOR_BIN}" ]; then
  echo "Cursor IDE CLI not found (note: 'cursor' on PATH is the agent, not the IDE)." >&2
  echo "Install Cursor or drop the AppImage in ~/programs, then re-run." >&2
  exit 1
fi

# NODE_OPTIONS / ELECTRON_RUN_AS_NODE in the parent env break the Electron CLI.
cursor_cli() { env -u NODE_OPTIONS -u ELECTRON_RUN_AS_NODE "${CURSOR_BIN}" "$@"; }

(cd "${SCRIPT_DIR}" && python3 "${SCRIPT_DIR}/linkdotfiles.py")

while IFS= read -r extension; do
  case "${extension}" in
    ""|\#*) continue ;;
  esac
  cursor_cli --install-extension "${extension}" --force
done < "${SCRIPT_DIR}/cursor-extensions.txt"

cursor_cli --version
