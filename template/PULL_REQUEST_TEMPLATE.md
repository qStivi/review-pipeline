## Change note
- **What & why:** <1–2 sentences: what this change is and why it exists. If you can't answer "should this exist at all" in one sentence, the plan isn't ready (Layer 0).>
- **How tested:** <evidence — test output, command run, screenshot, dry-run. "Looks fine" is not evidence.>
- **How to undo:** <exact command / revert / snapshot. If this line cannot be filled in, the change is not ready.>
- **Risk tier:** low / medium / high
  - low: docs, comments, behind a flag, trivial refactor → agent checks only
  - medium: ordinary product change, caching, dependency bump → + author's read-through
  - high: critical paths (see CRITICAL_PATHS.md), auth, schema migrations, prod config → + independent review

## Reviewer notes (review agent + author)
- Every finding gets either a fix-commit or a **written clear-with-reason backed by evidence**. Reasons feed REVIEW.md.
- Review rounds are capped at 3. Round 4 means: stop, rethink the approach.
- Re-reviews cover **only the new commits**, not the whole diff again.
