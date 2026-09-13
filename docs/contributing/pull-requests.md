# Pull Request Guidelines

This guide explains how to submit effective pull requests.

## Before You Start

### Check Existing Work

1. Search [existing issues](https://github.com/submersion-app/submersion/issues)
2. Check [open PRs](https://github.com/submersion-app/submersion/pulls)
3. Review the [roadmap](contributing/roadmap.md)

Every PR must relate to an issue (see [Linking Issues](#linking-issues)). If
none exists for your change, open one before you open the PR.

### Discuss Large Changes

For significant changes:

1. Open an issue first
2. Discuss the approach
3. Get feedback before coding

## Creating a Pull Request

### 1. Fork and Branch

```bash
# Fork on GitHub, then clone
git clone https://github.com/YOUR_USERNAME/submersion.git
cd submersion

# Add upstream
git remote add upstream https://github.com/submersion-app/submersion.git

# Create branch
git checkout -b feature/your-feature
```

### 2. Make Changes

- Follow [code style](contributing/code-style.md)
- Write tests for new code
- Update documentation if needed

### 3. Commit

Use [conventional commits](https://www.conventionalcommits.org/):

```bash
git commit -m "feat: add nitrox calculator"
git commit -m "fix: correct MOD calculation for trimix"
git commit -m "docs: add calculator documentation"
git commit -m "test: add unit tests for gas calculations"
```

### 4. Push

```bash
git push origin feature/your-feature
```

### 5. Open PR

1. Go to your fork on GitHub
2. Click "Compare & pull request"
3. Fill out the template

## PR Template

GitHub pre-fills new PRs from
[`.github/PULL_REQUEST_TEMPLATE.md`](https://github.com/submersion-app/submersion/blob/main/.github/PULL_REQUEST_TEMPLATE.md).
A filled-out description looks like this:

```markdown
## Related Issue

Closes #123

## Summary

Fixes the MOD calculation for trimix, which used the O2 fraction of air.

## Changes

- Pass the mix's own O2 fraction into `calculateMod`
- Add unit tests for air, EAN32 and 18/45 trimix

## Test Plan

- [x] `flutter test` passes
- [x] `flutter analyze` passes
- [x] Manual testing on: macOS

## Screenshots

(Delete this section if not applicable.)
```

## Linking Issues

Every PR must relate to an issue. The **PR Issue Link** check blocks the merge
until the description links one, and re-runs whenever the description is
edited.

| The PR... | Write | On merge |
| --- | --- | --- |
| fully resolves the issue | `Closes #123` (or `Fixes` / `Resolves`) | the issue closes |
| is one step of a larger issue | `Part of #123` | the issue stays open |
| is related work or a follow-up | `Refs #123` or `Related to #123` | the issue stays open |

Things that trip people up:

- **Only the description counts.** GitHub closes an issue only when a closing
  keyword sits directly before the number in the PR description. A number in
  the PR title, or a passing mention like "builds on #123", links nothing.
- **One keyword per issue.** `Closes #1, closes #2` closes both;
  `Closes #1, #2` closes only #1.
- **Comments and code do not count.** A link inside an HTML comment
  (`<!-- -->`) or a code span is ignored, by GitHub and by the check. The
  template's examples live in a comment for that reason, so an unedited
  template fails.
- **Branch names are checked.** If the branch name contains an issue number
  (`issue-123-...`, `github-issue-123-...`, `feature-request-123-...`), the
  description must link that issue, with `Refs` if the PR does not resolve it.
- **No issue yet?** Open one first. Only bot-authored PRs (version bumps,
  Dependabot) are exempt.

## PR Best Practices

### Keep PRs Small

- Focus on one thing
- Easier to review
- Faster to merge

### Write Good Descriptions

- Explain what and why
- Include context
- Link the issue with `Closes #N` or `Refs #N` (see [Linking Issues](#linking-issues))

### Add Screenshots

For UI changes:

- Before and after
- Different screen sizes
- Light and dark mode

### Respond to Feedback

- Address all comments
- Ask for clarification if needed
- Make requested changes promptly

## Review Process

### What Reviewers Look For

| Area | Checks |
|------|--------|
| **Code Quality** | Clean, readable, follows conventions |
| **Testing** | Adequate coverage, tests pass |
| **Documentation** | Updated if needed |
| **Performance** | No obvious bottlenecks |
| **Security** | No vulnerabilities introduced |

### Review Timeline

- Initial review: 1-3 days
- Follow-up reviews: 1-2 days
- Complex PRs may take longer

### Addressing Feedback

```bash
# Make changes based on feedback
git add .
git commit -m "fix: address review feedback"
git push origin feature/your-feature
```

## After Merge

### Clean Up

```bash
# Switch to main
git checkout main

# Delete local branch
git branch -d feature/your-feature

# Update from upstream
git pull upstream main
```

### Celebrate

Your contribution is now part of Submersion!

## Types of PRs

### Bug Fixes

```markdown
## Related Issue
Closes #123

## Description
Fixes incorrect depth unit conversion when switching between metric and imperial.

## Root Cause
The conversion factor was inverted in `depth_converter.dart`.

## Solution
Corrected the conversion factor from 3.28084 to 0.3048 for feet to meters.

## Testing
- Added unit tests for both conversion directions
- Manually verified in settings page
```

### New Features

```markdown
## Related Issue
Closes #456

## Description
Adds a nitrox calculator to the tools section.

## Changes Made
- Created NitroxCalculatorPage widget
- Added calculateBestMix method to GasMix entity
- Added route in app_router.dart
- Added unit tests for calculations

## Screenshots
[Include screenshots of the new UI]

## Documentation
- Updated tools section in user guide
```

### Refactoring

```markdown
## Related Issue
Refs #789

## Description
Refactors dive repository to use a base repository class.

## Motivation
Reduces code duplication across repositories.

## Changes
- Created BaseRepository with common CRUD methods
- Updated DiveRepository to extend BaseRepository
- No functional changes

## Testing
All existing tests pass without modification.
```

## Common Issues

### Merge Conflicts

```bash
# Fetch latest from upstream
git fetch upstream

# Rebase on main
git rebase upstream/main

# Resolve conflicts, then continue
git add .
git rebase --continue

# Force push (only for your branch!)
git push origin feature/your-feature --force
```

### Failed CI Checks

1. Check the CI logs
2. Run tests locally: `flutter test`
3. Run analyzer: `flutter analyze`
4. Fix issues and push again

### Stale PRs

PRs inactive for 30+ days may be closed. To reopen:

1. Rebase on latest main
2. Resolve any conflicts
3. Comment that it's ready for review

## Special PRs

### Breaking Changes

- Clearly mark in PR title: `feat!: new dive format`
- Explain migration path
- Update all affected documentation

### Documentation Only

- Use `docs:` prefix
- No code changes required
- Can be merged quickly

### Dependency Updates

- Include changelog summary
- Note any breaking changes
- Test thoroughly

## Questions?

- Comment on the PR
- Ask in [discussions](https://github.com/submersion-app/submersion/discussions)
- Reference this guide

Thank you for contributing!
