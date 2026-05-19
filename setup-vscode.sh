#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEB_PATH="${1:-/home/lee/code/code_1.120.0-1778619059_amd64.deb}"

if ! command -v code >/dev/null 2>&1; then
  if [ ! -f "${DEB_PATH}" ]; then
    echo "VS Code is not installed and ${DEB_PATH} does not exist." >&2
    echo "Pass the downloaded .deb path as the first argument." >&2
    exit 1
  fi

  echo "code code/add-microsoft-repo boolean true" | sudo debconf-set-selections
  sudo apt install -y "${DEB_PATH}"
fi

(cd "${SCRIPT_DIR}" && python3 "${SCRIPT_DIR}/linkdotfiles.py")

while IFS= read -r extension; do
  case "${extension}" in
    ""|\#*) continue ;;
  esac
  code --install-extension "${extension}" --force
done < "${SCRIPT_DIR}/vscode-extensions.txt"

code --version
