# flowrs

Config generator for [flowrs](https://github.com/jvanbuel/flowrs), a terminal UI for
Apache Airflow. It sets flowrs up to show every Amazon MWAA (Airflow) environment
across several AWS accounts in one window, both Airflow 2 and Airflow 3.

`config.toml` is **generated, never committed**. It holds account-level details
(environment names and hosts), so it is built from AWS on demand instead of being
stored in this repo.

## Install the flowrs CLI

flowrs is a Homebrew formula (homebrew-core), not part of this repo:

```zsh
brew install flowrs
```

Update it with `brew upgrade flowrs`. It is a standalone app; it does not need
the Airflow CLI (`airflowctl`) or any Python package.

## What gets stowed

`stow flowrs` links these into `~/.config/flowrs/`, the folder flowrs reads its
config from:

| File | What it does |
|------|--------------|
| `aws-profiles` | The AWS profile names to search, one per line. The only input the generator needs. |
| `flowrs-config.sh` | Finds the MWAA environments in each listed AWS profile and writes `~/.config/flowrs/config.toml`. |
| `mwaa-token.sh` | Logs in to one MWAA environment and prints the credential flowrs needs. flowrs calls it from each server entry. |

## Choosing the AWS profiles

List the profiles (from `~/.aws/config`) in `aws-profiles`, one per line. Lines
starting with `#` are ignored. Profile names are safe to commit; the account
details behind them stay in `~/.aws/config`.

```
BATCH-DEV
BATCH-PROD
```

To use a different list for one run, pass profiles as arguments
(`flowrs-config.sh BATCH-DEV`) or set `FLOWRS_AWS_PROFILES`. The generator picks
the first of these it finds: arguments, then `FLOWRS_AWS_PROFILES`, then the
`aws-profiles` file.

## Environment variables

None are required when `aws-profiles` is filled in.

| Variable | Required | Example | Purpose |
|----------|----------|---------|---------|
| `FLOWRS_AWS_PROFILES` | No | `"BATCH-DEV BATCH-PROD"` | Space-separated profiles that override the `aws-profiles` file. Leave unset normally, or it silently wins over the file. |
| `XDG_CONFIG_HOME` | No | `~/.config` | Base config folder. Defaults to `~/.config`, so everything lives in `~/.config/flowrs/`. |
| `AWS_REGION` | No | `us-east-1` | Overrides the region set on each profile, if your environments live elsewhere. |

## Setup

```zsh
brew install flowrs                        # the flowrs CLI (see above)
mkdir -p ~/.config/flowrs                  # see Notes: avoids stow linking the whole folder
cd ~/.dotfiles && stow flowrs              # link the scripts and aws-profiles into ~/.config/flowrs
aws sso login --profile BATCH-DEV          # sign in to every profile in aws-profiles
aws sso login --profile BATCH-PROD
~/.config/flowrs/flowrs-config.sh          # write config.toml
flowrs
```

Run `flowrs-config.sh` again whenever an environment is added or rebuilt, or after
editing `aws-profiles`.

## Requirements

- flowrs, installed with `brew install flowrs`.
- AWS CLI v2 with an SSO session for each profile.
- IAM permissions: `airflow:ListEnvironments`, `airflow:GetEnvironment`, and
  `airflow:CreateWebLoginToken`.
- `curl` and `zsh` (both ship with macOS).

## How the login works

flowrs cannot use an AWS profile directly for a saved server. Each server entry
runs `mwaa-token.sh`, which:

1. Calls `aws mwaa create-web-login-token` with the profile (a 60-second token).
2. Trades it at the Airflow server for a session credential (lasts 12 hours):
   - Airflow 3: a bearer token, from `/pluginsv2/aws_mwaa/login`
   - Airflow 2: a session cookie, from `/aws_mwaa/login`
3. Caches it for 11 hours in `~/.cache/mwaa-token/` (readable only by you), because
   flowrs reruns the command every 60 seconds.

When your SSO session expires, servers stop refreshing until you run
`aws sso login` again.

## Notes

- If `~/.config/flowrs` does not exist when you stow, stow links the whole folder
  back into this repo. `config.toml` would then be written inside the repo. The
  root `.gitignore` excludes it, but creating the folder first avoids the problem:
  `mkdir -p ~/.config/flowrs && stow flowrs`.
- `flowrs-config.sh` replaces the config each run and saves the previous one as
  `config.toml.bak`. flowrs's own saved settings, like the last server you
  opened, are reset.
