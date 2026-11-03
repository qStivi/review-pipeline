# review-pipeline

A portable solo code-review pipeline: a fresh vibe-cli session reviews every non-draft PR on a self-hosted runner, behind a read-only tool fence. Built and hardened on [qStivi/qCalendar](https://github.com/qStivi/qCalendar) (7 PRs of fire-drilling; see REGRESSION_LOG.seed for the scars).

Two machines, two lanes:
- **Repo lane** — everything in this repo: workflows, templates, docs. Adopted per repo by `install.sh`.
- **Runner lane** — the host running the review agent: fenced `VIBE_HOME`, `review.env` (Mistral key), runner registration. Setup once per host/account per `runner/setup.md`.

## Adopt into a repo (repo lane)

```bash
cd /path/to/target-repo
bash /path/to/review-pipeline/install.sh
# review the generated files, adjust CRITICAL_PATHS.md paths + REVIEW.md failure modes,
# commit, push
```

`install.sh` copies the workflow templates with the critical-path list substituted, seeds the regression log with the two universal vibe-CLI incidents, never overwrites existing files, and prints the remaining manual steps.

Per-repo authoring (the parts that can't be templated — this is where the value lives):
- `REVIEW.md` — *this repo's* failure modes; a generic one is noise
- `CRITICAL_PATHS.md` — *this repo's* high-risk paths
- `AGENTS.md` — repo invariants checklist

## Set up a host / GitHub account (runner lane)

See `runner/setup.md` — written as a maintenance-agent work order. Summary:
1. Register a self-hosted runner for the target repo (`self-hosted` label)
2. Install the shared fence once per host: `/opt/review-agent/vibe-home` (template in `runner/config.toml.template`)
3. Create `/opt/review-agent/review.env` (root-owned, 0600) with the Mistral account's key — one per Mistral account; shared by all repos on that host
4. `gh` and `vibe` ≥ 3.x on the runner service PATH

Multiple GitHub accounts on one host: register one runner per repo (registration tokens are per-repo); the fence and env file are shared. Multiple Mistral accounts: one `review.env` each; point the workflow's source line at the right file.

## Design invariants (do not "simplify" these away)

Each one closes a hole found in the field:
- **No `--auto-approve`** — on vibe 3.0.2 it bypasses the read_file denylist (verified live). Without it, denied reads fail instantly without hanging.
- **Review criteria checked out from the PR's base** — a PR must not control the rules it is judged against; its changes reach the reviewer only via the diff.
- **Base dir via `mktemp` + `GITHUB_ENV` + `__BASE_DIR__` sed** — quoted heredocs don't expand variables; one variable shared by preflight/prompt/cleanup.
- **Unified `**Review (round` anchor** across counter, output guard, and prompt — so failure diagnostics and cap notices never count as review rounds.
- **Round cap enforced by step gates** (`count < 3`), not by `exit 0` (which only ends its own step).
- **`--paginate`** on all comment/commit API calls — the default 30-item pages silently undercount on long PRs.
- **Drafts are never reviewed** (job-level `if: draft == false`); created-ready PRs are reviewed via the `opened` trigger.
- **Failures post a diagnostic PR comment** — a red review check means "reviewer broken," and says so; it must never masquerade as a code finding.
- **Fence allowlist globs don't cross `/`** — depth levels are enumerated explicitly.
- **The key never lives in GitHub** — `review.env` is sourced on the runner; repo secrets are readable by PR-supplied workflow code, a local file is not.
