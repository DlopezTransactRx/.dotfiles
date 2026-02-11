# GitHub Repository Protection Scripts

This repository contains scripts to automate GitHub branch protection setup and enforce code quality standards through branch protection rules.

## Scripts Overview

1. **enable-branch-protection.sh** - Configure branch protection for a single branch
2. **config-repo.sh** - One-command setup for both Development and Production branches

## Prerequisites

- **GitHub CLI (gh)** installed and configured
- Authenticated GitHub account with admin permissions
- Repository admin access

### Installation

If you don't have GitHub CLI installed:
```bash
brew install gh
```

Authenticate with GitHub:
```bash
gh auth login
```

Make scripts executable:
```bash
chmod +x enable-branch-protection.sh config-repo.sh
```

## Quick Setup (Recommended)

For most repositories, use the `config-repo.sh` script to configure both Development and Production branches in one command:

```bash
./config-repo.sh myorg myrepo
```

This will:
1. Configure repository settings (auto-delete branches, merge strategy)
2. Set Development as the default branch (if it exists)
3. Set up Development branch protection (PR required, no force push)
4. Set up Production branch protection with required status checks
5. **Automatically create** the required "check-branch" workflow if it doesn't exist

You can also set a GitHub token for automatic workflow creation:
```bash
GITHUB_TOKEN=ghp_your_token_here ./config-repo.sh myorg myrepo
```

## Manual Setup

For more granular control, use the `enable-branch-protection.sh` script directly:

```bash
./enable-branch-protection.sh <owner> <repo> <branch-pattern>
```

### Arguments

- `<owner>`: GitHub organization or user name
- `<repo>`: Repository name
- `<branch-pattern>`: Branch name to protect (e.g., `main`, `Development`, `Production`)

### Examples

Protect the Development branch:
```bash
./enable-branch-protection.sh myorg myrepo Development
```

Protect the Production branch (adds status check requirements):
```bash
./enable-branch-protection.sh myorg myrepo Production
```

## Features

### Standard Branch Protection (All Branches)

When you protect any branch, the script enables:

- **Pull Request Requirement**: All changes must go through a pull request
- **Force Push Prevention**: Prevents accidental history rewrites
- **Deletion Prevention**: Branch cannot be deleted
- **Admin Enforcement**: Protection rules apply to all users, including admins

### Production Branch Special Handling

When protecting the "Production" branch, the script additionally enables:

- **Required Status Checks**: The `check-branch` workflow must pass before merging
- **Strict Mode**: Branches must be up to date with the base branch before merging

This ensures only properly validated changes can be merged to Production.

## Workflow Example

### Complete Repository Setup

1. Create a new repository on GitHub
2. Clone it locally and set up your Development/Production branches
3. Run the config script:
   ```bash
   ./config-repo.sh myorg my-new-repo
   ```
4. Create a GitHub Actions workflow that includes a job named "check-branch"

### Branch Protection Workflow

```
feature-branch
     │
     │ PR (can merge to Development)
     ▼
Development Branch
     │
     │ PR (check-branch validates source is Development)
     ▼
Production Branch
```

With this setup:
1. Feature branches can be merged to Development with PR
2. Only Development can be merged to Production (enforced by check-branch)
3. The Production branch is protected by our required status check

### The Required GitHub Action

The `config-repo.sh` script will **automatically create** this workflow if it doesn't exist:

```yaml
name: Branch Validation

on:
  pull_request:
    branches:
      - Production

jobs:
  check-branch:
    name: check-branch
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Verify source branch
        run: |
          # Only allow merges from Development to Production
          if [[ "${{ github.head_ref }}" == "Development" ]]; then
            echo "✅ Merging from approved branch: Development"
            exit 0
          else
            echo "❌ ERROR: Only Development branch can be merged to Production"
            echo "Current source branch: ${{ github.head_ref }}"
            exit 1
          fi
```

This action will:
1. Run when a PR targets the Production branch
2. Pass if the source branch is Development
3. Fail if anyone tries to merge from another branch
4. The "check-branch" name matches what our script requires

If you prefer to create this workflow manually, you can create it at `.github/workflows/check-branch.yml` in your repository.

## Repository Settings

The scripts also configure repository-wide settings:

- **Default Branch**: Sets Development as the default branch (if it exists)
- **Auto-delete head branches**: Clean up after PR merges
- **Merge strategy**: Allow merge commits only
- **Features enabled**: Projects, Issues, Wikis, and Forking

Setting Development as the default branch ensures:
1. New pull requests target Development by default
2. Contributors clone with Development as their base branch
3. GitHub UI displays Development branch content by default
4. Any workflow updates get pushed to Development first

## Debugging

To see detailed API requests and responses, run with `DEBUG=1`:

```bash
DEBUG=1 ./enable-branch-protection.sh owner repo branch-name
```

## Verification

After running the script, verify settings at:

- **Branch Protection**: `https://github.com/<owner>/<repo>/settings/branches`
- **Repository Settings**: `https://github.com/<owner>/<repo>/settings`

## Troubleshooting

**Error: "Branch does not exist"**
- Create the required branches first or use different branch names
- When using `config-repo.sh`, you can choose to continue for branches that do exist

**Error: "Not authenticated with GitHub"**
- Run `gh auth login` to authenticate

**Error: "GitHub CLI is not installed"**
- Install with `brew install gh`

**Status Check Never Passes**
- Ensure your GitHub Actions workflow has a job named exactly "check-branch"
- Check the workflow logs for any errors
