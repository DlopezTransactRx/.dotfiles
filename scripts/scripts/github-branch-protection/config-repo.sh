#!/bin/bash

# config-repo script to configure branch protection for Development and Production branches
# Usage: ./config-repo.sh <owner> <repo>

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <owner> <repo>"
    echo ""
    echo "Example: $0 myorg myrepo"
    echo ""
    echo "This will configure branch protection for both Development and Production branches."
    exit 1
fi

OWNER="$1"
REPO="$2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if branch protection script exists
if [ ! -f "$SCRIPT_DIR/enable-branch-protection.sh" ]; then
    echo "Error: enable-branch-protection.sh not found in the same directory."
    exit 1
fi

# Make sure enable-branch-protection.sh is executable
chmod +x "$SCRIPT_DIR/enable-branch-protection.sh"

echo "=========================================================="
echo "Setting up branch protection for $OWNER/$REPO"
echo "=========================================================="
echo ""

# Apply Development branch protection if it exists
echo "Checking Development branch..."
if gh api repos/$OWNER/$REPO/branches/Development --silent &> /dev/null; then
    echo "Step 1: Applying protection to Development branch..."
    "$SCRIPT_DIR/enable-branch-protection.sh" "$OWNER" "$REPO" "Development"
    echo "Development branch protected."
    echo ""
else
    echo "Development branch not found, skipping."
    echo ""
fi

# Apply Production branch protection if it exists
echo "Checking Production branch..."
if gh api repos/$OWNER/$REPO/branches/Production --silent &> /dev/null; then
    echo "Step 2: Applying protection to Production branch..."
    "$SCRIPT_DIR/enable-branch-protection.sh" "$OWNER" "$REPO" "Production"
    echo "Production branch protected."
    echo ""
else
    echo "Production branch not found, skipping."
    echo ""
fi

echo "=========================================================="
echo "✅ Branch protection setup complete!"
echo "=========================================================="
echo ""
echo "You can verify these settings at:"
echo "https://github.com/$OWNER/$REPO/settings/branches"