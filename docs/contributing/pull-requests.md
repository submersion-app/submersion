# Pull Request Guidelines

This guide explains how to submit effective pull requests.

## Before You Start

### Check Existing Work

1. Search [existing issues](https://github.com/submersion-app/submersion/issues)
2. Check [open PRs](https://github.com/submersion-app/submersion/pulls)
3. Review the [roadmap](contributing/roadmap.md)

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

```markdown
## Description

Brief description of what this PR does.

## Type of Change

- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation

## Changes Made

- Added X
- Modified Y
- Removed Z

## Testing

- [ ] Unit tests added/updated
- [ ] Widget tests added/updated
- [ ] Manual testing performed

## Checklist

- [ ] Code follows style guidelines
- [ ] Tests pass locally
- [ ] Documentation updated
- [ ] No new warnings from `flutter analyze`

## Screenshots

(If applicable)

## Related Issues

Fixes #123
Related to #456
```

## PR Best Practices

### Keep PRs Small

- Focus on one thing
- Easier to review
- Faster to merge

### Write Good Descriptions

- Explain what and why
- Include context
- Link related issues

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

