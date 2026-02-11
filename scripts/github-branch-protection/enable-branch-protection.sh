#!/bin/bash

# Script to enable branch protection settings on GitHub repositories
# Usage: ./enable-branch-protection.sh <owner> <repo> <branch-pattern>

set -e

# Check required arguments
if [ $# -lt 3 ]; then
    echo "Usage: $0 <owner> <repo> <branch-pattern>"
    echo ""
    echo "Example: $0 owner reponame Development"
    exit 1
fi

OWNER="$1"
REPO="$2"
BRANCH_PATTERN="$3"

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed. Please install it first."
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "Error: Not authenticated with GitHub. Run 'gh auth login' first."
    exit 1
fi

echo "Enabling branch protection for: $OWNER/$REPO on branch pattern: $BRANCH_PATTERN"

# Check if the branch exists
BRANCH_CHECK=$(gh api repos/$OWNER/$REPO/branches/$BRANCH_PATTERN --silent 2>&1 || true)
if echo "$BRANCH_CHECK" | grep -q "not found"; then
    echo "Error: Branch '$BRANCH_PATTERN' does not exist in $OWNER/$REPO"
    echo "Available branches:"
    AVAILABLE_BRANCHES=$(gh api repos/$OWNER/$REPO/branches --jq '.[].name')
    echo "$AVAILABLE_BRANCHES"

    # Look for case-insensitive match to help diagnose capitalization issues
    for branch in $AVAILABLE_BRANCHES; do
        if [ "$(echo "$branch" | tr '[:upper:]' '[:lower:]')" = "$(echo "$BRANCH_PATTERN" | tr '[:upper:]' '[:lower:]')" ]; then
            echo "Note: You might have meant: '$branch' (case is important)"
        fi
    done

    exit 1
fi

echo "Creating branch protection rule..."
# Enable debugging
if [ -n "$DEBUG" ]; then
    set -x
fi

# Create branch protection rule using a curl request with correctly formatted JSON
# Check if branch is "Production" to add status checks requirement
if [ "$BRANCH_PATTERN" = "Production" ]; then
    echo "Detected 'Production' branch - enabling required status checks..."

    # Apply protection with status checks
    LEGACY_RESPONSE=$(gh api \
      --method PUT \
      "repos/$OWNER/$REPO/branches/$BRANCH_PATTERN/protection" \
      --input - << EOF
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["check-branch"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
      2>&1)
else
    # Standard protection for non-Production branches
    LEGACY_RESPONSE=$(gh api \
      --method PUT \
      "repos/$OWNER/$REPO/branches/$BRANCH_PATTERN/protection" \
      --input - << EOF
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
      2>&1)
fi

# Output the response for debugging
if [ -n "$DEBUG" ]; then
    echo "API Response: $LEGACY_RESPONSE"
fi

# Check for errors
if echo "$LEGACY_RESPONSE" | grep -q "\"message\":"; then
    echo "Error applying branch protection. GitHub API response:"
    echo "$LEGACY_RESPONSE"
    echo ""
    echo "Common issues:"
    echo "1. Permission errors - Need admin access to repository"
    echo "2. API limitations - Enterprise features might be required"
    echo "3. Branch naming - Make sure the branch exists with exact capitalization"
    echo ""
    echo "Try running with DEBUG=1 for more information:"
    echo "DEBUG=1 $0 $OWNER $REPO $BRANCH_PATTERN"
    exit 1
fi

echo ""
echo "Configuring general project settings..."

# Update repository settings
SETTINGS_RESPONSE=$(gh api \
  --method PATCH \
  "repos/$OWNER/$REPO" \
  -f delete_branch_on_merge=true \
  -f allow_merge_commit=true \
  -f allow_squash_merge=false \
  -f allow_rebase_merge=false \
  -f allow_auto_merge=false \
  -f allow_forking=true \
  -f has_projects=true \
  -f has_wiki=true \
  -f has_issues=true \
  2>&1)

# Output the response for debugging
if [ -n "$DEBUG" ]; then
    echo "Settings API Response: $SETTINGS_RESPONSE"
fi

# Check for errors
if echo "$SETTINGS_RESPONSE" | grep -q "\"message\":"; then
    echo "Warning: Some repository settings could not be applied:"
    echo "$SETTINGS_RESPONSE"
fi

# Configure wiki restriction if possible
WIKI_RESPONSE=$(gh api --method PATCH "repos/$OWNER/$REPO" \
  -f wiki_allow_everyone_to_create_pages=false \
  2>&1 || true)

if [ -n "$DEBUG" ] && echo "$WIKI_RESPONSE" | grep -q "\"message\":"; then
    echo "Note: Could not restrict wiki editing (may require Enterprise plan)"
fi

# Link PR closing with issues if possible
AUTOLINK_RESPONSE=$(gh api --method PUT "repos/$OWNER/$REPO/autolinks" \
  -f key_prefix="ISSUE-" \
  -f url_template="https://github.com/$OWNER/$REPO/issues/<num>" \
  2>&1 || true)

if [ -n "$DEBUG" ] && echo "$AUTOLINK_RESPONSE" | grep -q "\"message\":"; then
    echo "Note: Could not set up auto-linking (may require different permissions)"
fi

echo "✓ Configuration completed successfully"
echo ""
echo "Branch Protection Settings Applied to '$BRANCH_PATTERN' branch:"
echo "  - Require a pull request before merging"
echo "  - Lock branch (prevent force pushes and deletions)"
echo "  - Do not allow bypassing the above settings (enforce for administrators)"
if [ "$BRANCH_PATTERN" = "Production" ]; then
    echo "  - Require 'check-branch' status check to pass before merging"
    echo "  - Require branches to be up to date before merging"
fi
echo ""
echo "Repository Settings Applied to '$OWNER/$REPO':"
echo "  - Automatically delete head branches when PRs are merged"
echo "  - Allow merge commits"
echo "  - Projects enabled"
echo "  - Allow forking"
echo "  - Issues enabled"
echo "  - Wikis enabled"
echo ""
echo "You can verify these settings at: https://github.com/$OWNER/$REPO/settings/branches"
echo "and: https://github.com/$OWNER/$REPO/settings"
