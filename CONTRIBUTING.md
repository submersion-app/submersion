# Contributing to Submersion

Thank you for your interest in contributing to Submersion — a free, open-source
dive log for scuba divers. Contributions of all kinds are welcome: bug reports,
feature ideas, documentation, translations, and code.

By participating in this project, you agree to abide by our
[Code of Conduct](CODE_OF_CONDUCT.md).

## Ways to Contribute

- **Report a bug** — [open an issue](https://github.com/submersion-app/submersion/issues/new/choose)
  with clear steps to reproduce, expected vs. actual behavior, and your platform
  and app version.
- **Suggest a feature** — check the [roadmap](docs/contributing/roadmap.md)
  first, then [start a discussion](https://github.com/submersion-app/submersion/discussions).
- **Improve documentation** — the `docs/` directory powers the developer guide
  and the published site.
- **Report a security issue** — please do *not* open a public issue. Follow the
  [Security Policy](SECURITY.md) instead.
- **Submit code** — see the workflow below.

## Development Setup

Submersion is a Flutter application targeting iOS, Android, macOS, Windows, and
Linux. You will need the [Flutter SDK](https://docs.flutter.dev/get-started/install)
(3.x) installed.

```bash
# Fork on GitHub, then clone your fork
git clone https://github.com/YOUR_USERNAME/submersion.git
cd submersion

# First-time setup: installs deps, configures git hooks, runs code generation
./scripts/setup.sh
```

The setup script is equivalent to running these steps manually:

```bash
git submodule update --init --recursive   # libdivecomputer and other submodules
flutter pub get
git config core.hooksPath hooks           # enables the pre-push checks
dart run build_runner build --delete-conflicting-outputs
```

For a deeper walkthrough of the architecture, database, state management, and
platform builds, see the [developer docs](docs/developer/README.md).

## Making Changes

1. **Create a feature branch** off `main`:
   ```bash
   git checkout -b feature/short-description
   ```
2. **Write tests first.** Submersion follows a test-driven workflow. Add or
   update tests alongside your change.
3. **Regenerate code when needed.** Drift ORM and Riverpod rely on generated
   files. Run `dart run build_runner build --delete-conflicting-outputs` (or
   `watch` during development) after touching database tables, entities, or
   providers.
4. **Respect the diver's unit settings.** Anything that displays a measurement
   (depth, temperature, pressure, volume) must honor the active diver's unit
   preferences rather than hard-coding metric or imperial.

## Before You Push

The pre-push hook runs the same checks as CI. Run them locally first to avoid
surprises:

```bash
dart format .                  # formatting must produce no changes
flutter analyze                # no analyzer warnings or infos
flutter test                   # all tests must pass
```

Formatting is enforced project-wide — always run `dart format .` (not just the
files you touched) before committing.

## Submitting a Pull Request

1. Push your branch and open a pull request against `main`.
2. Fill out the [pull request template](.github/PULL_REQUEST_TEMPLATE.md),
   describing what changed and why.
3. **Link the issue the PR relates to.** Every PR must relate to an issue, and
   the "PR Issue Link" check blocks the merge until the description links one:
   - `Closes #123` (or `Fixes` / `Resolves`) when the PR fully resolves the
     issue. GitHub closes the issue on merge only when the keyword sits
     directly before the number in the description; a number in the title does
     nothing. Give each issue its own keyword: `Closes #1, closes #2`.
   - `Refs #123`, `Part of #123` or `Related to #123` when the PR relates to an
     issue without resolving it, so the issue stays open.

   If no issue exists yet, open one first.
4. Keep PRs focused and reasonably small: one logical change per PR is easier
   to review and merge.
5. Ensure CI passes. Maintainers may request changes; discussion is part of the
   process.

For detailed conventions, see:

- [Code Style](docs/contributing/code-style.md) — imports, naming, formatting
- [Pull Request Guidelines](docs/contributing/pull-requests.md) — branching,
  commit hygiene, review flow
- [Full Contributing Guide](docs/contributing/README.md)

## License

Submersion is licensed under the [GNU GPL v3.0](LICENSE). By contributing, you
agree that your contributions will be licensed under the same terms.
