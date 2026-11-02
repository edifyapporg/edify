# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) and any other LLM coding
assistant working in this repository. `AGENTS.md` is a symlink to this file, so tools that
read that name get the same instructions.

## Project basics

- Rails app on PostgreSQL. Ruby and Node versions are pinned in `.tool-versions`; the Rails
  version is in `Gemfile.lock`. Local setup is in `README.md`; production operations are in
  `OPERATIONS.md`.
- Run the test suite with `bin/rspec`. New or changed logic needs specs.
- Run the linter with `bundle exec rubocop -a`. CI lints **every file the PR touches**, not just
  the changed lines, so fix all offenses in each file you modify, including ones that were
  already there.
- CI also runs `bin/brakeman -q -w2` and `bin/bundle-audit check --update`.

## Pull request discipline

**These rules are mandatory. Run through them BEFORE opening any pull request** — before
running `gh pr create`, before pushing a branch intended for review, and before telling the
developer the work is ready. If the pending work violates any rule below, say so and propose
how to split it *first*; do not open the PR and apologize afterwards.

The goal behind every rule here is the same: **make it as easy as possible for the reviewer
to see what is going on.** A reviewer who has to reconstruct your intent from the diff is a
reviewer who will miss bugs.

### 1. No huge PRs

Large changes must be broken up into a sequence of smaller, independently reviewable PRs.

- Aim for **under ~500 changed lines**, not counting lockfiles, `db/schema.rb`, and data or
  seed files. This is a soft target, not a hard cap, but a PR well past it needs a reason.
- If the change is getting large, stop and find the seams: scaffolding first, then behavior;
  one model/feature per PR; refactor-only PRs separate from behavior-change PRs.
- Pure mechanical churn (renames, formatting, generated files, dependency bumps) goes in its
  own PR so it never hides a real change inside a wall of noise.
- If a change genuinely cannot be split, say why explicitly in the PR description so the
  reviewer knows it was a deliberate decision and not an accident.

### 2. Every PR needs an associated issue

Every PR must reference an issue so the reviewer knows what you are trying to do and why.

- Link it in the PR description (`Closes #123`, or `Refs #123` for one PR in a series).
- If no issue exists yet, draft one (a short statement of the problem and the intended
  outcome is enough) and create it once the developer confirms. Don't open issues without
  asking.
- When a large change is split into several PRs, they can share a tracking issue; each PR
  says which slice of that issue it delivers.

### 3. Database changes get their own PR

All database changes — migrations, schema changes, new tables/columns, indexes, data
backfills — go in a **separate PR from code changes**. This keeps review focused and makes
rollback possible without reverting unrelated application code.

Deploy order depends on the direction of the change:

- **Additive changes** (new table, new nullable column, new index, widening a column): ship
  the migration PR first, merge and deploy it, then ship the code that uses it.
- **Destructive changes** (dropping or renaming a column or table, adding `NOT NULL`,
  narrowing a type): ship the code first. That PR stops reading and writing the column and
  adds it to the model's `self.ignored_columns`. Once that is deployed, ship the migration
  that drops or changes it. Dropping a column the running code still knows about causes
  errors, because Rails caches the column list at boot.

In every case:

- Write migrations so they are safe to run against the existing production schema and safe to
  roll back on their own (e.g. give `remove_column` the column type so it is reversible).
- Note in the migration PR whether it is backward-compatible with the currently deployed code
  (it should be).
- **Allowed exception:** a migration PR may carry the small code change that is tied directly
  to it and to nothing else, such as regenerated `db/schema.rb` or removing the
  `ignored_columns` entry for the column being dropped. Anything with its own behavior goes
  in its own PR.

### 4. Code changes get their own PR

Application code changes live in their own PR, separate from migrations (apart from the
exception above) and separate from unrelated concerns. One PR, one purpose.

### 5. Make the reviewer's job easy

Every PR description should state, briefly:

- **What** changed and **why** (link the issue).
- **How to verify it** — the test to run, the screen to click through, the query to check.
- **Anything risky** — data migrations, behavior changes for existing users, anything that
  needs to ship in a particular order.

Keep commits within the PR meaningful, keep the diff free of unrelated drive-by edits, and
add screenshots for user-visible UI changes.

### Pre-PR checklist

Before opening a PR, check each item below. Report any item that fails, along with how you
propose to fix it; if everything passes, say so in one line.

- [ ] Diff is under the size target (or the description explains why not); otherwise it has
      been split.
- [ ] An issue exists and is linked in the description.
- [ ] Database/migration changes are isolated in their own PR, in the right deploy order for
      an additive or destructive change.
- [ ] Code changes are isolated from schema changes and from unrelated work.
- [ ] Description covers what, why, how to verify, and risk.
- [ ] Rubocop is clean on every touched file, and specs pass.
- [ ] No unrelated files, formatting churn, or stray debug code in the diff.
