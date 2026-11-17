#!/bin/bash
# Setup SSH key-based auth between sus (this machine), lee3090ti, and daisy
# Run this interactively - it will prompt for passwords

set -e

PUBKEY="$(cat ~/.ssh/id_ed25519.pub)"
echo "=== SSH Mesh Setup for sus <-> lee3090ti <-> daisy ==="
echo ""
echo "Your public key: $PUBKEY"
echo ""

# Step 1: Copy key to lee3090ti (supports password auth)
echo "--- Step 1: Pushing key to lee3090ti (will ask for password) ---"
ssh-copy-id -i ~/.ssh/id_ed25519.pub lee@lee3090ti
echo "✓ Key copied to lee3090ti"
echo ""

# Verify
echo "--- Verifying passwordless access to lee3090ti ---"
ssh lee@lee3090ti "echo '✓ Passwordless SSH to lee3090ti works!'"
echo ""

# Step 2: From lee3090ti, push our key to daisy
# (daisy only accepts publickey, so lee3090ti must already have access)
echo "--- Step 2: Pushing key to daisy via lee3090ti ---"
ssh lee@lee3090ti "
  # Add sus's key to daisy's authorized_keys
  ssh lee@daisy 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo \"$PUBKEY\" >> ~/.ssh/authorized_keys && sort -u -o ~/.ssh/authorized_keys ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
  echo '✓ Key pushed to daisy via lee3090ti'
"
echo ""

# Verify direct access to daisy
echo "--- Verifying passwordless access to daisy ---"
ssh lee@daisy "echo '✓ Passwordless SSH to daisy works!'"
echo ""

# Step 3: Grab .secretbashrc from daisy
echo "--- Step 3: Fetching ~/.secretbashrc from daisy ---"
scp lee@daisy:~/.secretbashrc ~/.secretbashrc
echo "✓ .secretbashrc copied to ~/.secretbashrc"
echo ""

# Step 4: Also ensure daisy and lee3090ti can reach each other
# (generate keys on remote machines if needed and cross-authorize)
echo "--- Step 4: Cross-authorizing daisy <-> lee3090ti ---"

# Ensure lee3090ti has a key, push it to daisy
ssh lee@lee3090ti "
  if [ ! -f ~/.ssh/id_ed25519.pub ]; then
    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N '' -q
    echo 'Generated new key on lee3090ti'
  fi
  cat ~/.ssh/id_ed25519.pub
" | ssh lee@daisy "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && sort -u -o ~/.ssh/authorized_keys ~/.ssh/authorized_keys"
echo "✓ lee3090ti's key authorized on daisy"

# Ensure daisy has a key, push it to lee3090ti
ssh lee@daisy "
  if [ ! -f ~/.ssh/id_ed25519.pub ]; then
    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N '' -q
    echo 'Generated new key on daisy'
  fi
  cat ~/.ssh/id_ed25519.pub
" | ssh lee@lee3090ti "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && sort -u -o ~/.ssh/authorized_keys ~/.ssh/authorized_keys"
echo "✓ daisy's key authorized on lee3090ti"

# Push sus's key to lee3090ti from daisy side too (for reverse access)
ssh lee@daisy "
  if [ ! -f ~/.ssh/id_ed25519.pub ]; then
    echo 'daisy has no key - skipping reverse push to lee3090ti'
  fi
"

echo ""
echo "=== Summary ==="
echo "✓ sus -> lee3090ti  (passwordless)"
echo "✓ sus -> daisy      (passwordless)"
echo "✓ lee3090ti -> daisy (passwordless)"
echo "✓ daisy -> lee3090ti (passwordless)"
echo "✓ ~/.secretbashrc synced from daisy"
echo ""
echo "You can now run: source ~/.secretbashrc"
echo ""
echo "To deploy dotfiles + linux-setup.sh on a remote machine, run:"
echo "  ssh lee@daisy 'git clone https://github.com/lee101/dotfiles ~/code/dotfiles && ~/code/dotfiles/setup-linux.sh'"
