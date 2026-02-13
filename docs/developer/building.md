# Building & Running

Instructions for building and running Submersion on all supported platforms.

## Prerequisites

### Required Software

| Software | Version | Download |
|----------|---------|----------|
| Flutter SDK | 3.5+ | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| Dart SDK | 3.5+ | Included with Flutter |
| Git | Any | [git-scm.com](https://git-scm.com/) |

### Platform-Specific Requirements

**macOS**
- Xcode 15+ (for iOS/macOS builds)
- CocoaPods (`sudo gem install cocoapods`)

**Windows**
- Visual Studio 2022+ with C++ workload
- Windows 10 SDK

**Linux**
- GCC, CMake, Ninja
- GTK 3.0+ development libraries
- libsqlite3-dev

**Android**
- Android Studio with SDK
- Android SDK 21+ (Lollipop)

**iOS**
- macOS only
- Xcode 15+
- Apple Developer account (for device testing)

## Quick Start

```bash
# Clone repository
git clone https://github.com/submersion-app/submersion.git
cd submersion

# Install dependencies
flutter pub get

# Generate code (required)
dart run build_runner build --delete-conflicting-outputs

# Run on connected device or emulator
flutter run
```

## Code Generation

Submersion uses code generation for:
- **Drift** - Database schema and queries
- **Freezed** - Immutable data classes
- **Riverpod Generator** - Provider generation

### Run Once

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Watch Mode

For active development, run in watch mode:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

### When to Regenerate

Regenerate code after:
- Changing database schema (`database.dart`)
- Modifying Freezed classes
- Updating Riverpod providers with annotations
- Pulling changes that modify generated files

## Running the App

### Desktop

```bash
# macOS
flutter run -d macos

# Windows
flutter run -d windows

# Linux
flutter run -d linux
```

### Mobile

```bash
# Android (device or emulator)
flutter run -d android

# iOS (macOS only, device or simulator)
flutter run -d ios
```

### List Available Devices

```bash
flutter devices
```

## Building for Release

### macOS

```bash
flutter build macos --release
```

Output: `build/macos/Build/Products/Release/Submersion.app`

### Windows

```bash
flutter build windows --release
```

Output: `build/windows/x64/runner/Release/`

### Linux

```bash
flutter build linux --release
```

Output: `build/linux/x64/release/bundle/`

### Android

```bash
# APK
flutter build apk --release

# App Bundle (for Play Store)
flutter build appbundle --release
```

Output:
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- Bundle: `build/app/outputs/bundle/release/app-release.aab`

### iOS

```bash
flutter build ios --release
```

Then open in Xcode for archive and distribution.

## Development Commands

### Code Analysis

```bash
flutter analyze
```

### Format Code

```bash
dart format lib/
```

### Run Tests

```bash
# All tests
flutter test

# With coverage
flutter test --coverage

# Specific test file
flutter test test/features/dive_log/dive_repository_test.dart
```

### Clean Build

```bash
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

## Dependencies

### Core Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| flutter_riverpod | ^2.5.1 | State management |
| drift | ^2.20.0 | Database ORM |
| go_router | ^14.3.0 | Navigation |

### UI Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| fl_chart | ^0.68.0 | Charts and graphs |
| flutter_map | ^7.0.2 | Map display |
| flutter_map_marker_cluster | ^1.3.6 | Map clustering |
| cached_network_image | ^3.4.1 | Image caching |
| photo_view | ^0.15.0 | Image viewer |

### Platform Integration

| Package | Version | Purpose |
|---------|---------|---------|
| flutter_blue_plus | ^1.32.12 | Bluetooth |
| dive_computer | ^0.1.0-dev.2 | libdivecomputer FFI |
| geolocator | ^13.0.2 | GPS location |
| flutter_contacts | ^1.1.9+2 | Contacts access |
| image_picker | ^1.1.2 | Camera/gallery |
| file_picker | ^10.3.8 | File selection |

### Cloud Integration

| Package | Version | Purpose |
|---------|---------|---------|
| google_sign_in | ^6.2.2 | Google auth |
| googleapis | ^13.2.0 | Google APIs |

### Data Handling

| Package | Version | Purpose |
|---------|---------|---------|
| xml | ^6.5.0 | UDDF import/export |
| pdf | ^3.11.1 | PDF export |
| csv | ^6.0.0 | CSV export |
| crypto | ^3.0.3 | Hashing |

### Dev Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| flutter_lints | ^4.0.0 | Linting rules |
| build_runner | ^2.4.12 | Code generation |
| drift_dev | ^2.20.1 | Drift codegen |
| freezed | ^2.5.7 | Immutable classes |
| mockito | ^5.4.4 | Test mocking |

## Project Structure

```
submersion/
├── lib/
│   ├── main.dart              # Entry point
│   ├── app.dart               # Root widget
│   ├── core/                  # Shared infrastructure
│   ├── features/              # Feature modules
│   └── shared/                # Shared widgets
├── test/                      # Test files
├── assets/                    # Static assets
├── docs/                      # Documentation
├── android/                   # Android config
├── ios/                       # iOS config
├── macos/                     # macOS config
├── windows/                   # Windows config
├── linux/                     # Linux config
└── pubspec.yaml               # Dependencies
```

## Environment Variables

No environment variables required for basic development.

For cloud features, configure API keys in the app's settings.

## Troubleshooting

### Code Generation Fails

```bash
# Clean and regenerate
flutter clean
flutter pub get
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

### Build Fails on macOS

```bash
cd macos
pod deintegrate
pod install
cd ..
flutter clean
flutter pub get
```

### Android SDK Issues

Ensure ANDROID_HOME is set:

```bash
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools
```

### iOS Signing Issues

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the Runner target
3. Set your development team
4. Let Xcode manage signing

### Windows Build Issues

Ensure Visual Studio C++ workload is installed:
1. Open Visual Studio Installer
2. Modify your installation
3. Add "Desktop development with C++"

## IDE Setup

### VS Code

Recommended extensions:
- Flutter
- Dart
- Drift (for syntax highlighting)

### Android Studio / IntelliJ

Install plugins:
- Flutter
- Dart

## Continuous Integration

The project is CI-ready with:
- No external dependencies for tests
- In-memory database for testing
- Deterministic test data
- Reasonable timeouts

Example GitHub Actions workflow:

```yaml
name: CI
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
      - run: flutter pub get
      - run: dart run build_runner build --delete-conflicting-outputs
      - run: flutter analyze
      - run: flutter test
```

## Release Checklist

Before releasing:

1. [ ] Run `flutter analyze` - no errors
2. [ ] Run `flutter test` - all passing
3. [ ] Update version in `pubspec.yaml`
4. [ ] Commit: `git commit -am "chore: bump version to X.Y.Z"`
5. [ ] Tag: `git tag vX.Y.Z`
6. [ ] Push: `git push origin main --tags`
7. [ ] Monitor the Release workflow in GitHub Actions
8. [ ] Verify all artifacts appear on the GitHub Release page
9. [ ] Verify iOS build appears in TestFlight
10. [ ] Verify macOS build appears in TestFlight

For beta releases, use tags like `v1.0.0-beta.1` (creates a pre-release).

