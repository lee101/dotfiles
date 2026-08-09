#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Locate the Devin editor CLI (VS Code fork binary, supports --install-extension).
# The agent CLI on PATH is `devin`; the editor binary is `devin-desktop`.
DEVIN_BIN=""
for cand in \
  "$(command -v devin-desktop 2>/dev/null || true)" \
  "${HOME}/programs/Devin/bin/devin-desktop" \
  "/usr/share/devin/bin/devin-desktop" \
  "/opt/Devin/bin/devin-desktop"; do
  if [ -n "${cand}" ] && [ -x "${cand}" ]; then
    DEVIN_BIN="${cand}"
    break
  fi
done

if [ -z "${DEVIN_BIN}" ]; then
  echo "devin-desktop binary not found. Install Devin desktop first." >&2
  exit 1
fi

(cd "${SCRIPT_DIR}" && python3 "${SCRIPT_DIR}/linkdotfiles.py")

while IFS= read -r extension; do
  case "${extension}" in
    ""|\#*) continue ;;
  esac
  "${DEVIN_BIN}" --install-extension "${extension}" --force
done < "${SCRIPT_DIR}/devin-extensions.txt"

"${DEVIN_BIN}" --version
