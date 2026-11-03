#!/usr/bin/env bash
# Adopt the review pipeline into a repo. Run from the target repo's root:
#   bash /path/to/review-pipeline/install.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
T="$(cd "${1:-.}" && pwd)"

echo "== review-pipeline install into $T =="

# --- sanity ---
command -v gh >/dev/null || { echo "gh not found on PATH"; exit 1; }
[ -d "$T/.git" ] || { echo "$T is not a git repo"; exit 1; }

copy() {  # copy <src> <dst>: never overwrite
  local src="$1" dst="$T/$2"
  if [ -e "$dst" ]; then
    echo "  SKIP (exists): $2"
  else
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    echo "  created: $2"
  fi
}

# --- workflows ---
echo "-- workflows --"
copy "$HERE/template/review.yml" ".github/workflows/review.yml"
copy "$HERE/template/tier.yml"  ".github/workflows/tier.yml"

# --- PR template ---
echo "-- PR template --"
copy "$HERE/template/PULL_REQUEST_TEMPLATE.md" ".github/PULL_REQUEST_TEMPLATE.md"

# --- agent/reviewer docs (templates; authoring required, hence kept if present) --
echo "-- docs (author the marked sections!) --"
copy "$HERE/template/REVIEW.md.template"          "REVIEW.md"
copy "$HERE/template/CRITICAL_PATHS.md.template"   "CRITICAL_PATHS.md"
copy "$HERE/template/AGENTS.md.template"           "AGENTS.md"

# --- regression log: seed universal incidents if absent ---
if [ -e "$T/REGRESSION_LOG.md" ]; then
  echo "  SKIP (exists): REGRESSION_LOG.md"
else
  {
    cat "$HERE/template/REGRESSION_LOG.md.template" | grep -v '^__SEED_ROWS__$'
    cat "$HERE/REGRESSION_LOG.seed"
  } > "$T/REGRESSION_LOG.md"
  echo "  created: REGRESSION_LOG.md (seeded with universal vibe-CLI incidents 001-002)"
fi

# --- critical-path patterns: ask or derive ---
echo
echo "-- critical-path patterns for tier.yml --"
echo "Enter path patterns for CRITICAL_PATHS.md/tier.yml, one per line, Enter on empty line to finish."
echo "Suggested minimum for any repo: .github/workflows/*"
PATTERNS=()
while IFS= read -r line; do
  [ -z "$line" ] && break
  PATTERNS+=("$line")
done
if [ "${#PATTERNS[@]}" -eq 0 ]; then
  PATTERNS=(".github/workflows/*")
  echo "  (none given — defaulting to .github/workflows/*)"
fi
JOIN=$(printf '            "%s"\n' "${PATTERNS[@]}")
python3 - "$T/.github/workflows/tier.yml" <<PY
import sys
p = sys.argv[1]
w = open(p).read()
patterns = """$JOIN"""
w = w.replace('"__CRITICAL_PATTERNS__"\n', patterns.strip() + '\n')
if '__CRITICAL_PATTERNS__' in w:
    print("  ERROR: pattern substitution failed"); sys.exit(1)
open(p, 'w').write(w)
print("  tier.yml patterns set:", "${PATTERNS[*]}")
PY

# --- label ---
echo
echo "-- 'high risk' label --"
REPO="$(cd "$T" && git remote get-url origin | sed -E 's#.*github.com[:/]##; s#\.git$##')"
gh label list --repo "$REPO" 2>/dev/null | grep -q "high risk" \
  && echo "  label exists" \
  || { gh label create "high risk" --repo "$REPO" --color d93f0b --description "Diff touches a critical path; requires independent review" && echo "  label created"; }

cat <<'EOF'

== Done in the repo. Remaining manual steps ==
1. AUTHOR REVIEW.md failure modes + CRITICAL_PATHS.md paths + AGENTS.md invariants
   (the templates mark the sections — generic ones are noise)
2. Runner-side (see review-pipeline/runner/setup.md): register a self-hosted
   runner for this repo, install the shared fence + review.env on the host
3. Commit + push the new files; open a PR — the pipeline reviews its own
   adoption (fittingly)
EOF
