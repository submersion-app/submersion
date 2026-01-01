# Contributing

Thank you for your interest in contributing to Submersion! This guide will help you get started.

## Ways to Contribute

### Report Bugs

Found a bug? [Open an issue](https://github.com/submersion-app/submersion/issues) with:
- Clear title and description
- Steps to reproduce
- Expected vs actual behavior
- Platform and version info
- Screenshots if applicable

### Suggest Features

Have an idea? Check the [roadmap](contributing/roadmap.md) first, then [open a discussion](https://github.com/submersion-app/submersion/discussions).

### Submit Code

Ready to code? Follow these steps:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Write tests
5. Submit a pull request

## Getting Started

### Prerequisites

| Software | Version |
|----------|---------|
| Flutter SDK | 3.5+ |
| Dart SDK | 3.5+ |
| Git | Any |

### Setup

```bash
# Fork and clone
git clone https://github.com/YOUR_USERNAME/submersion.git
cd submersion

# Add upstream remote
git remote add upstream https://github.com/submersion-app/submersion.git

# Install dependencies
flutter pub get

# Generate code
dart run build_runner build --delete-conflicting-outputs

# Run tests to verify setup
flutter test
```

### Create a Branch

```bash
# Sync with upstream
git fetch upstream
git checkout main
git merge upstream/main

# Create feature branch
git checkout -b feature/your-feature-name
```

## Development Workflow

### 1. Make Changes

Follow the [code style guide](contributing/code-style.md).

### 2. Write Tests

- Unit tests for new logic
- Widget tests for new UI
- Update integration tests if workflows change

### 3. Verify Changes

```bash
# Run tests
flutter test

# Check code style
flutter analyze

# Format code
dart format lib/
```

### 4. Commit

Write clear, descriptive commit messages:

```
feat: add nitrox calculator to tools page

- Add NitroxCalculatorPage with MOD and best-mix inputs
- Add calculator logic to GasMix entity
- Add unit tests for calculations
```

Follow [conventional commits](https://www.conventionalcommits.org/):
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation
- `test:` - Adding tests
- `refactor:` - Code refactoring
- `chore:` - Maintenance

### 5. Submit PR

See [Pull Request Guidelines](contributing/pull-requests.md).

## Project Structure

```
lib/
├── core/              # Shared infrastructure
│   ├── database/      # Drift ORM schema
│   ├── deco/          # Decompression algorithms
│   ├── router/        # Navigation
│   ├── services/      # Business services
│   └── theme/         # Material 3 theme
├── features/          # Feature modules
│   ├── dive_log/
│   ├── dive_sites/
│   ├── equipment/
│   └── ...
└── shared/            # Shared widgets
```

Each feature follows:

```
feature_name/
├── data/
│   ├── models/
│   └── repositories/
├── domain/
│   └── entities/
└── presentation/
    ├── pages/
    ├── widgets/
    └── providers/
```

## Key Technologies

| Layer | Technology |
|-------|------------|
| State | Riverpod |
| Database | Drift (SQLite) |
| Navigation | go_router |
| Charts | fl_chart |
| Maps | flutter_map |

## Testing

### Run Tests

```bash
# All tests
flutter test

# Specific file
flutter test test/features/dive_log/dive_repository_test.dart

# With coverage
flutter test --coverage
```

### Test Structure

```
test/
├── features/          # Feature unit tests
├── widget/            # Widget tests
├── integration/       # Integration tests
├── performance/       # Performance tests
└── helpers/           # Test utilities
```

## Documentation

When adding features:

1. Update relevant docs in `docs/`
2. Add code comments for complex logic
3. Update FEATURE_ROADMAP.md if applicable

## Code Review

All PRs are reviewed for:

- [ ] Code quality and style
- [ ] Test coverage
- [ ] Documentation updates
- [ ] No security vulnerabilities
- [ ] Performance considerations

## Community

- **GitHub Issues**: Bug reports
- **GitHub Discussions**: Questions, ideas
- **Pull Requests**: Code contributions

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.

## Questions?

Open a [discussion](https://github.com/submersion-app/submersion/discussions) or check existing issues.

Thank you for helping make Submersion better!

