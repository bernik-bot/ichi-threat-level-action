# ICHI Internet Cyber Health Level — GitHub Action

[![Follow @ICHI_Global on X](https://img.shields.io/badge/follow-%40ICHI__Global-000000?logo=x&logoColor=white)](https://x.com/ICHI_Global)

[![Internet cyber health](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fichi.global%2Fapi%2Fcurrent-index&query=%24.current.band&label=Internet%20cyber%20health)](https://ichi.global)
[![self-test](https://github.com/bernik-bot/ichi-threat-level-action/actions/workflows/test.yml/badge.svg)](https://github.com/bernik-bot/ichi-threat-level-action/actions/workflows/test.yml)

A small composite GitHub Action (bash + curl + jq, no secrets) that reads the
current [ICHI](https://ichi.global) score and band and exposes them as step
outputs, writes a short job summary, and can optionally warn or fail when the
ambient band is at or above a threshold you choose.

## What ICHI is (and is not)

ICHI — the Internet Cyber Health Index — is a free, publicly accessible,
source-transparent daily barometer of internet-wide cyber threat conditions,
created by Joe Bernik. It is an **outside-in directional signal**. It is
**not** an organization-specific risk score, not a deterministic forecast, and
not a substitute for your own internal telemetry. ICHI's methodology treats the
band as the operative read and moves within a band as noise; see the
[methodology](https://ichi.global/methodology).

Use this action for situational context (summaries, notifications, gating
optional or high-risk jobs such as a Friday production change), not as a
security control.

This repository is maintained by/for ICHI's creator.

## Usage

```yaml
name: ichi
on:
  schedule:
    - cron: "0 13 * * *"
  workflow_dispatch:

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - id: ichi
        uses: bernik-bot/ichi-threat-level-action@v1
        with:
          fail-on-band: HIGH   # optional
          mode: warn           # warn (default) | fail

      - run: echo "ICHI is ${{ steps.ichi.outputs.band }} (${{ steps.ichi.outputs.score }}) as of ${{ steps.ichi.outputs.evaluated_at }}"
```

Gate a deploy job when the ambient band is CRITICAL:

```yaml
      - uses: bernik-bot/ichi-threat-level-action@v1
        with:
          fail-on-band: CRITICAL
          mode: fail
```

## Inputs

| Input | Default | Description |
|---|---|---|
| `fail-on-band` | _(empty)_ | `NORMAL`, `GUARDED`, `ELEVATED`, `HIGH` or `CRITICAL`. When the current band is at or above it, the step warns or fails. Empty disables the check. Invalid values are ignored with a warning. |
| `mode` | `warn` | `warn` emits a workflow warning; `fail` fails the step. |
| `strict` | `false` | If `true`, fail the step when the index cannot be fetched/parsed. Otherwise warn, leave outputs empty, and continue. |
| `api-url` | `https://ichi.global/api/current-index` | Endpoint override (testing). |
| `timeout-seconds` | `15` | curl timeout per attempt (2 retries). |
| `summary` | `true` | Write a job summary to `$GITHUB_STEP_SUMMARY`. |

## Outputs

| Output | Example | Notes |
|---|---|---|
| `score` | `65.01` | 0–100. Empty if unavailable. |
| `band` | `ELEVATED` | Empty if unavailable. |
| `evaluated_at` | `2026-10-31T13:20:26.513Z` | When the current evaluation completed. |
| `rounded` | `65` | Integer score as published. |
| `headline_state` | `LIVE` | ICHI's own freshness state. |
| `threshold_met` | `false` | `true` only if `fail-on-band` was set and met. |
| `available` | `true` | `false` when the API could not be read. |

Bands (from the methodology): NORMAL 0–24, GUARDED 25–49, ELEVATED 50–69,
HIGH 70–84, CRITICAL 85–100.

## Graceful degradation

If the API is unreachable, returns non-JSON, or lacks `current.score` /
`current.band`, the action emits a warning, sets empty outputs with
`available=false`, and the step **succeeds** — unless `strict: true`.

## README badge

Dynamic badges served by shields.io straight from the public API:

```markdown
[![Internet cyber health](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fichi.global%2Fapi%2Fcurrent-index&query=%24.current.band&label=Internet%20cyber%20health)](https://ichi.global)
```

Score variant:

```markdown
[![ICHI score](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fichi.global%2Fapi%2Fcurrent-index&query=%24.current.rounded&label=ICHI%20score&suffix=%2F100&color=orange)](https://ichi.global)
```

shields.io caches responses, so badges may lag the live index by a few minutes.
Badge colour is static (shields' dynamic JSON badges don't colour by value).

## Requirements

`bash`, `curl` and `jq` — present on GitHub-hosted Ubuntu and macOS runners.
The self-test workflow runs on both.

## License

MIT

Daily ICHI readings and exploited-vulnerability alerts are posted on X by [@ICHI_Global](https://x.com/ICHI_Global) (automated, run by ICHI's creator).
