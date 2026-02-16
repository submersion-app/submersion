# Changelog

All notable changes to Submersion are documented in this file.


## 1.1.1 (2026-02-16)

### Features

- add unified release script
- add changelog generation from conventional commits

### Bug Fixes

- skip Claude code review for Dependabot PRs
- disable Codecov fail_ci_if_error until repo is configured
- allow Dependabot bot in Claude code review workflow
- add Codecov token and graceful fallback
- include build-ios in appcast job dependencies
- match analyze strictness between CI and release preflight

### Documentation

- add PR template with test plan checklist
- add CI/CD pipeline overhaul implementation plan
- add CI/CD pipeline overhaul design

### CI/CD

- bump actions/download-artifact from 4 to 7 (#17)
- bump actions/checkout from 4 to 6 (#19)
- bump actions/setup-java from 4 to 5 (#20)
- bump actions/upload-artifact from 4 to 6 (#15)
- bump actions/setup-python from 5 to 6 (#18)
- bump codecov/codecov-action from 4 to 5 (#16)
- add integration tests on macOS for pull requests
- enforce coverage threshold via Codecov
- add weekly performance benchmark workflow
- add Dependabot for GitHub Actions, pub, and Bundler
- use changelog for release notes and add post-release validation
- add retry logic for notarization and Fastlane uploads
- pin Flutter version via shared config file

### Chores

- bump version to 1.1.1+38

### Other

- Updates section in Settings/About should not show on iOS or Android

Format follows [Keep a Changelog](https://keepachangelog.com/).
