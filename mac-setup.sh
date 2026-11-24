#!/usr/bin/env bash
# mac-setup.sh - idempotent macOS bootstrap. Safe to re-run any time:
# every step checks whether it's already done before doing anything.
#
#   ./mac-setup.sh              full setup
#   ./mac-setup.sh --no-apps    skip GUI casks
#   ./mac-setup.sh --no-defaults  skip macOS `defaults` tweaks
#   ./mac-setup.sh --upgrade    also upgrade already-installed brew packages
set -uo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WITH_APPS=1 WITH_DEFAULTS=1 UPGRADE=0
for arg in "$@"; do
    case "$arg" in
        --no-apps) WITH_APPS=0 ;;
        --no-defaults) WITH_DEFAULTS=0 ;;
        --upgrade) UPGRADE=1 ;;
        -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

[[ "$OSTYPE" == darwin* ]] || { echo "macOS only" >&2; exit 1; }

FAILED=()
step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; FAILED+=("$*"); }
have() { command -v "$1" >/dev/null 2>&1; }
clone_once() { # clone_once <url> <dir>
    if [ -d "$2/.git" ]; then ok "$(basename "$2") present"
    else git clone --depth=1 "$1" "$2" && ok "cloned $(basename "$2")" || warn "clone failed: $1"; fi
}

# ── Xcode command line tools ─────────────────────────────────────────
step "Xcode Command Line Tools"
if xcode-select -p >/dev/null 2>&1; then ok "installed"
else
    xcode-select --install || true
    echo "  Finish the CLT installer dialog, then re-run this script."; exit 1
fi

# ── Homebrew ─────────────────────────────────────────────────────────
step "Homebrew"
if [ -x /opt/homebrew/bin/brew ]; then BREW=/opt/homebrew/bin/brew
elif [ -x /usr/local/bin/brew ]; then BREW=/usr/local/bin/brew
else
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    BREW=$( [ -x /opt/homebrew/bin/brew ] && echo /opt/homebrew/bin/brew || echo /usr/local/bin/brew )
fi
eval "$("$BREW" shellenv)"
ok "$(brew --version | head -1)"
# Login shells get brew via ~/.zprofile (cheap: static exports, no subprocess per shell)
if ! grep -qs 'brew shellenv' ~/.zprofile; then
    echo "eval \"\$($BREW shellenv)\"" >> ~/.zprofile && ok "added brew to ~/.zprofile"
fi
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1

# ── Packages ─────────────────────────────────────────────────────────
step "brew bundle (only installs what's missing)"
brew update --quiet >/dev/null 2>&1 || true
# Newer Homebrew refuses formulae from third-party taps until they're trusted.
# Trust every tap referenced as owner/tap/formula in the Brewfile.
if brew commands 2>/dev/null | grep -qx trust; then
    for tap in $(sed -nE 's#^(brew|cask) "([^/"]+/[^/"]+)/[^"]+".*#\2#p' "$DOTFILES/Brewfile" | sort -u); do
        grep -qs "\"$tap\"" ~/.homebrew/trust.json "${XDG_CONFIG_HOME:-/nonexistent}/homebrew/trust.json" \
            || brew trust "$tap" >/dev/null 2>&1 || warn "brew trust $tap failed"
    done
fi
BUNDLE_FILE="$DOTFILES/Brewfile"
if [ "$WITH_APPS" = 0 ]; then
    BUNDLE_FILE="$(mktemp)"; grep -v '^cask ' "$DOTFILES/Brewfile" > "$BUNDLE_FILE"
fi
if brew bundle check --file="$BUNDLE_FILE" >/dev/null 2>&1 && [ "$UPGRADE" = 0 ]; then
    ok "all Brewfile entries already installed"
else
    upflag=--no-upgrade; [ "$UPGRADE" = 1 ] && upflag=
    brew bundle --file="$BUNDLE_FILE" $upflag || warn "some brew bundle entries failed (re-run, or see output above; casks may need your sudo password)"
fi

# ── Shell: oh-my-zsh + plugins ───────────────────────────────────────
step "Zsh / oh-my-zsh"
if [ -f ~/.oh-my-zsh/oh-my-zsh.sh ]; then ok "oh-my-zsh present"
else
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
        && ok "installed oh-my-zsh" || warn "oh-my-zsh install failed"
fi
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
clone_once https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
clone_once https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
clone_once https://github.com/zsh-users/zsh-completions "$ZSH_CUSTOM/plugins/zsh-completions"
mkdir -p ~/.zsh/cache ~/.yarn/bin   # ~/.yarn/bin stops the omz yarn plugin running `yarn global bin` (~130ms) each shell
# Keep default login shell as zsh (macOS default); don't chsh to brew zsh (needs /etc/shells + sudo)
[ "$(dscl . -read ~/ UserShell 2>/dev/null | awk '{print $2}')" = /bin/zsh ] && ok "login shell is /bin/zsh"

# ── Dotfiles ─────────────────────────────────────────────────────────
step "Link dotfiles"
# Back up pre-existing real (non-symlink) rc files once, so linkdotfiles -f is safe
BACKUP="$HOME/.dotfiles-backup"
for f in .zshrc .bashrc .bash_profile .zshenv .vimrc .tmux.conf; do
    if [ -f "$HOME/$f" ] && [ ! -L "$HOME/$f" ]; then
        mkdir -p "$BACKUP" && mv "$HOME/$f" "$BACKUP/$f.$(date +%Y%m%d%H%M%S)" && ok "backed up ~/$f to $BACKUP"
    fi
done
python3 "$DOTFILES/linkdotfiles.py" -f -q && ok "dotfiles linked" || warn "linkdotfiles.py failed"

# Mac-specific git overrides (shared gitconfig uses Git Credential Manager, which
# isn't installed here). An empty helper resets the list inherited from the include.
if [ "$(git config --global --get-all credential.helper | tail -1)" != osxkeychain ]; then
    git config --global --unset-all credential.helper 2>/dev/null || true
    git config --global --add credential.helper ""
    git config --global --add credential.helper osxkeychain
    ok "git credential.helper -> osxkeychain"
else ok "git credential.helper already osxkeychain"; fi

# Terminfo for ghostty/kitty (so tmux/ssh behave)
for ti in "$DOTFILES"/terminfo/*.ti "$DOTFILES"/terminfo/*.terminfo; do
    [ -f "$ti" ] && tic -x -o "$HOME/.terminfo" "$ti" 2>/dev/null
done
ok "terminfo entries compiled"

# ── SSH ──────────────────────────────────────────────────────────────
step "SSH"
mkdir -p ~/.ssh && chmod 700 ~/.ssh
if ls ~/.ssh/id_* >/dev/null 2>&1; then ok "SSH key exists ($(ls ~/.ssh/id_*.pub 2>/dev/null | xargs -n1 basename | tr '\n' ' '))"
else
    ssh-keygen -t ed25519 -C "$(git config --get user.email || whoami)@$(hostname -s)" -f ~/.ssh/id_ed25519 -N "" \
        && pbcopy < ~/.ssh/id_ed25519.pub && ok "generated ~/.ssh/id_ed25519 (pubkey copied to clipboard)"
fi
if ! grep -qs 'UseKeychain' ~/.ssh/config; then
    printf 'Host *\n  AddKeysToAgent yes\n  UseKeychain yes\n  IgnoreUnknown UseKeychain\n\n' | cat - ~/.ssh/config 2>/dev/null > ~/.ssh/config.new
    mv ~/.ssh/config.new ~/.ssh/config && chmod 600 ~/.ssh/config && ok "ssh config: keychain enabled"
else ok "ssh config already uses keychain"; fi

# ── Languages ────────────────────────────────────────────────────────
step "Languages"
# Rust (brew rustup is keg-only)
RUSTUP="$(brew --prefix rustup 2>/dev/null)/bin/rustup"
if [ -x "$RUSTUP" ] && "$RUSTUP" toolchain list 2>/dev/null | grep -q '^stable'; then ok "rust stable present"
elif have rustc || [ -x ~/.cargo/bin/rustc ]; then ok "rust present"
elif [ -x "$RUSTUP" ]; then
    "$RUSTUP" default stable >/dev/null 2>&1 && ok "rust stable toolchain installed" || warn "rustup default stable failed"
fi
# Rust build acceleration: sccache (linker: default ld-prime on mac is already fast)
if [ ! -f ~/.cargo/config.toml ] && have sccache; then
    mkdir -p ~/.cargo
    printf '[build]\nrustc-wrapper = "sccache"\n' > ~/.cargo/config.toml && ok "cargo uses sccache"
fi

# Node: latest LTS via nvm (shell lazily puts newest nvm node on PATH)
export NVM_DIR="$HOME/.nvm"; mkdir -p "$NVM_DIR"
NVM_SH="$(brew --prefix nvm 2>/dev/null)/nvm.sh"
if ls -d "$NVM_DIR"/versions/node/v* >/dev/null 2>&1; then ok "nvm node present: $(ls "$NVM_DIR"/versions/node | tail -1)"
elif [ -s "$NVM_SH" ]; then
    # shellcheck disable=SC1090
    ( set +u; . "$NVM_SH"; nvm install --lts >/dev/null && nvm alias default 'lts/*' >/dev/null ) \
        && ok "installed node LTS via nvm" || warn "nvm install --lts failed"
fi
# ~/.nvm/nvm.sh shim so the shared shell config finds brew's nvm
[ -s "$NVM_SH" ] && [ ! -e "$NVM_DIR/nvm.sh" ] && ln -s "$NVM_SH" "$NVM_DIR/nvm.sh"

NPM_GLOBALS=(typescript typescript-language-server vscode-langservers-extracted prettier eslint diff-so-fancy pyright bash-language-server @openai/codex)
if have npm; then
    installed="$(npm ls -g --depth=0 --parseable 2>/dev/null)"
    missing=(); for p in "${NPM_GLOBALS[@]}"; do grep -q "/node_modules/$p\$" <<<"$installed" || missing+=("$p"); done
    if [ ${#missing[@]} -eq 0 ]; then ok "npm globals present"
    else npm install -g "${missing[@]}" >/dev/null 2>&1 && ok "npm -g ${missing[*]}" || warn "npm -g install failed: ${missing[*]}"; fi
fi

# Python: uv-managed tools (PEP 668 blocks pip --user on brew python)
if have uv; then
    for t in ruff black mypy ipython httpie pre-commit; do
        if uv tool list 2>/dev/null | grep -q "^$t "; then :; else uv tool install -q "$t" >/dev/null 2>&1 || warn "uv tool install $t failed"; fi
    done
    ok "uv tools: ruff black mypy ipython httpie pre-commit"
    # memray venv for tools/pymem-report
    if [ ! -x "$DOTFILES/tools/.venv/bin/python" ]; then
        uv venv -q "$DOTFILES/tools/.venv" && uv pip install -q --python "$DOTFILES/tools/.venv/bin/python" memray rich psutil \
            && ok "tools/.venv (memray)" || warn "tools/.venv setup failed"
    else ok "tools/.venv present"; fi
fi

# Go tools
if have go; then
    for pkg in golang.org/x/tools/gopls@latest; do
        bin="$(basename "${pkg%@*}")"; [ -x "$HOME/go/bin/$bin" ] || go install "$pkg" >/dev/null 2>&1 || warn "go install $pkg failed"
    done
    ok "go tools present"
fi

# ── Neovim plugins (lazy.nvim bootstraps itself) ─────────────────────
step "Neovim"
if have nvim; then
    if [ -d ~/.local/share/nvim/lazy/lazy.nvim ]; then ok "lazy.nvim plugins present"
    else nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1 && ok "nvim plugins installed" || warn "nvim plugin install failed (open nvim to finish)"; fi
fi

# ── Git hooks for this repo ──────────────────────────────────────────
[ -d "$DOTFILES/.githooks" ] && [ "$(git -C "$DOTFILES" config core.hooksPath)" != .githooks ] \
    && git -C "$DOTFILES" config core.hooksPath .githooks && ok "dotfiles git hooks enabled"

mkdir -p ~/code ~/Pictures/Screenshots ~/.config

# ── macOS defaults: make it feel snappy/Linux-like ───────────────────
if [ "$WITH_DEFAULTS" = 1 ]; then
    step "macOS defaults"
    d() { defaults write "$@"; }
    # Keyboard: fast repeat, no press-and-hold accent popup, no auto-"smart" text
    d -g KeyRepeat -int 2
    d -g InitialKeyRepeat -int 15
    d -g ApplePressAndHoldEnabled -bool false
    d -g NSAutomaticSpellingCorrectionEnabled -bool false
    d -g NSAutomaticCapitalizationEnabled -bool false
    d -g NSAutomaticQuoteSubstitutionEnabled -bool false
    d -g NSAutomaticDashSubstitutionEnabled -bool false
    d -g NSAutomaticPeriodSubstitutionEnabled -bool false
    d -g AppleKeyboardUIMode -int 2           # Tab through all controls
    # Faster UI animations
    d -g NSWindowResizeTime -float 0.001
    d -g NSAutomaticWindowAnimationsEnabled -bool false
    d -g AppleShowAllExtensions -bool true
    d -g NSDocumentSaveNewDocumentsToCloud -bool false
    d -g NSNavPanelExpandedStateForSaveMode -bool true
    # Trackpad: tap to click
    d com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
    d com.apple.AppleMultitouchTrackpad Clicking -bool true
    defaults -currentHost write -g com.apple.mouse.tapBehavior -int 1
    # Dock: autohide instantly, no recents, don't reorder Spaces
    d com.apple.dock autohide -bool true
    d com.apple.dock autohide-delay -float 0
    d com.apple.dock autohide-time-modifier -float 0.15
    d com.apple.dock show-recents -bool false
    d com.apple.dock mru-spaces -bool false
    d com.apple.dock expose-animation-duration -float 0.1
    d com.apple.dock launchanim -bool false
    # Finder: hidden files, path/status bars, list view, search current folder, no .DS_Store on network/USB
    d com.apple.finder AppleShowAllFiles -bool true
    d com.apple.finder ShowPathbar -bool true
    d com.apple.finder ShowStatusBar -bool true
    d com.apple.finder _FXShowPosixPathInTitle -bool true
    d com.apple.finder FXPreferredViewStyle -string Nlsv
    d com.apple.finder FXDefaultSearchScope -string SCcf
    d com.apple.finder FXEnableExtensionChangeWarning -bool false
    d com.apple.finder _FXSortFoldersFirst -bool true
    d com.apple.desktopservices DSDontWriteNetworkStores -bool true
    d com.apple.desktopservices DSDontWriteUSBStores -bool true
    # Screenshots
    d com.apple.screencapture location -string "$HOME/Pictures/Screenshots"
    d com.apple.screencapture disable-shadow -bool true
    # Rectangle: Spectacle keyboard shortcuts (false = Spectacle set), launch at login, no welcome
    d com.knollsoft.Rectangle alternateDefaultShortcuts -bool false
    d com.knollsoft.Rectangle launchOnLogin -bool true
    d com.knollsoft.Rectangle SUEnableAutomaticChecks -bool true
    # Chrome: no two-finger swipe back
    d com.google.Chrome AppleEnableSwipeNavigateWithScrolls -bool false
    killall Dock Finder SystemUIServer >/dev/null 2>&1 || true
    ok "defaults applied (key repeat takes effect after logout)"
fi

# ── Summary ──────────────────────────────────────────────────────────
step "Done"
if [ ${#FAILED[@]} -gt 0 ]; then
    printf '\033[33mSome steps need attention:\033[0m\n'; printf '  - %s\n' "${FAILED[@]}"
fi
cat <<'EOF'
Next:
  exec zsh                 # reload shell;  time zsh -i -c exit  to check startup
  gh auth login            # GitHub CLI
  ./setup-mac-root.sh --permissions   # sudo steps: Touch ID sudo, firewall, limits; then app permissions
  echo "export SSH_KEY_PW='...'" >> ~/.secretbashrc   # auto-unlock passphrase-protected ssh key
  open -a OrbStack         # finish docker setup
  Grant Rectangle / AltTab / Raycast accessibility permission when prompted.
EOF
