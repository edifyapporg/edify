# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) and any other LLM coding
assistant working in this repository.

## Pull request discipline

**These rules are mandatory. Run through them BEFORE opening any pull request** — before
running `gh pr create`, before pushing a branch intended for review, and before telling the
developer the work is ready. If the pending work violates any rule below, say so and propose
how to split it *first*; do not open the PR and apologize afterwards.

The goal behind every rule here is the same: **make it as easy as possible for the reviewer
to see what is going on.** A reviewer who has to reconstruct your intent from the diff is a
reviewer who will miss bugs.

### 1. No huge PRs

Do not submit 2,000-line PRs. Large changes must be broken up into a sequence of smaller,
independently reviewable PRs.

- Aim for a PR a reviewer can read carefully in one sitting.
- If the change is getting large, stop and find the seams: scaffolding first, then behavior;
  one model/feature per PR; refactor-only PRs separate from behavior-change PRs.
- Pure mechanical churn (renames, formatting, generated files, dependency bumps) goes in its
  own PR so it never hides a real change inside a wall of noise.
- If a change genuinely cannot be split, say why explicitly in the PR description so the
  reviewer knows it was a deliberate decision and not an accident.

### 2. Every PR needs an associated issue

Every PR must reference an issue so the reviewer knows what you are trying to do and why.

- Link it in the PR description (`Closes #123`, or `Refs #123` for one PR in a series).
- If no issue exists yet, create one before opening the PR — a short statement of the problem
  and the intended outcome is enough.
- When a large change is split into several PRs, they can share a tracking issue; each PR
  says which slice of that issue it delivers.

### 3. Database changes get their own PR

All database changes — migrations, schema changes, new tables/columns, indexes, data
backfills — go in a **separate PR from code changes**. This keeps review focused and makes
rollback possible without reverting unrelated application code.

- Ship the migration PR first, merge and deploy it, then ship the code that uses it.
- Write migrations so they are safe to run against the existing production schema and safe to
  roll back on their own.
- Note in the migration PR whether it is backward-compatible with the currently deployed code
  (it should be).

### 4. Code changes get their own PR

Application code changes live in their own PR, separate from migrations and separate from
unrelated concerns. One PR, one purpose.

### 5. Make the reviewer's job easy

Every PR description should state, briefly:

- **What** changed and **why** (link the issue).
- **How to verify it** — the test to run, the screen to click through, the query to check.
- **Anything risky** — data migrations, behavior changes for existing users, anything that
  needs to ship in a particular order.

Keep commits within the PR meaningful, keep the diff free of unrelated drive-by edits, and
add screenshots for user-visible UI changes.

### Pre-PR checklist

Before opening a PR, confirm and report each of these to the developer:

- [ ] Diff is small enough to review in one sitting; if not, it has been split.
- [ ] An issue exists and is linked in the description.
- [ ] Database/migration changes are isolated in their own PR.
- [ ] Code changes are isolated from schema changes and from unrelated work.
- [ ] Description covers what, why, how to verify, and risk.
- [ ] No unrelated files, formatting churn, or stray debug code in the diff.
