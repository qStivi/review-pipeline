# Runner-side setup — work order for the host running the review agent

One host can serve multiple GitHub accounts and multiple repos. The fence and env file are shared; runner registration is per repo. Written as a maintenance-agent work order (the same shape that built the CT 143 fence).

## Preconditions (verify; STOP and report if missing)
- Registration token for the target repo, provided by the operator in a file (from the repo's Settings → Actions → Runners → New runner; operator-only, expires ~1h)
- `vibe` ≥ 3.x supports `-p --output text` (verify: `vibe --version`; 3.0.2 verified)
- `gh` on the runner service PATH (e.g. /usr/bin or /usr/local/bin — NOT ~/.local/bin; root services don't inherit $HOME)
- An existing runner on the host (if any) is healthy and MUST NOT be touched

## Steps
1. Register a runner instance for the target repo — separate work dir + service per repo:
   mkdir -p /opt/actions-runner-<repo-slug> && cd /opt/actions-runner-<repo-slug>
   # download/extract the same runner version as any existing instance, then:
   ./config.sh --url https://github.com/<owner>/<repo> --token $(cat <token-file>) \
     --name <repo-slug>-runner --unattended      # default 'self-hosted' label is required by the workflow
   sudo ./svc.sh install && sudo ./svc.sh start
2. Install the shared fence (once per host):
   mkdir -p /opt/review-agent/vibe-home
   install -m 600 config.toml.template /opt/review-agent/vibe-home/config.toml
3. Create the key env file (once per Mistral account):
   install -m 600 /dev/null /opt/review-agent/review.env
   # operator adds: MISTRAL_API_KEY=<key>  — never print, log, or transmit it
   # For a second Mistral account: /opt/review-agent/review.env-<account>, and
   # adjust the source line in that repo's review.yml accordingly.
4. If /opt/review-agent/vibe-home or review.env already exist (host already serves
   another repo): SKIP steps 2–3 — the shared fence and env are the design.

## Verification (all must pass; all live, no --auto-approve)
- Runner shows Idle in the target repo's Actions → Runners settings
- Any pre-existing runner on the host: unchanged and active
- Fence test matrix (vibe with VIBE_HOME=/opt/review-agent/vibe-home):
  - flat /tmp/pr-file.txt read: allowed
  - /tmp/pr-diag/sample.txt (real subdir): allowed
  - review.env, /etc/hostname, bash id: denied instantly, no hang
  - symlink /tmp/pr-evil → /etc/hostname: denied (symlink resolution)
- /opt/review-agent/review.env: root-owned, mode 600

## Do NOT
- Touch, restart, or reconfigure any other runner on the host
- Print, log, or transmit tokens or the API key
- Add extra labels, register for other repos, or widen the fence allowlist
- Use --auto-approve anywhere near the fenced home (bypasses the read_file denylist on 3.0.2 — verified live)

## Report back
- Runner version, service name, verification matrix results, any failed precondition
