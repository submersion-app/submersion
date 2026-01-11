fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Capture App Store screenshots on iPhone and iPad simulators

### ios upload_screenshots

```sh
[bundle exec] fastlane ios upload_screenshots
```

Upload screenshots to App Store Connect

### ios capture_and_upload

```sh
[bundle exec] fastlane ios capture_and_upload
```

Capture screenshots and upload to App Store Connect

### ios clean_screenshots

```sh
[bundle exec] fastlane ios clean_screenshots
```

Clean up screenshot directories

### ios list_simulators

```sh
[bundle exec] fastlane ios list_simulators
```

List available simulators for screenshots

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
