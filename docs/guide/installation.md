# Installation

Submersion runs on iOS, Android, macOS, Windows, and Linux. Choose your platform below.

## Requirements

| Platform | Minimum Version |
|----------|-----------------|
| iOS | iOS 15+ |
| Android | Android 7+ (API 24) |
| macOS | macOS 12+ (Monterey) |
| Windows | Windows 10+ |
| Linux | Modern desktop distro |

### Development Requirements

To build from source, you'll need:

- **Flutter SDK** 3.5.0 or later
- **Dart SDK** 3.5.0 or later
- **Xcode** (for iOS/macOS builds)
- **Android Studio** (for Android builds)
- **Visual Studio** with C++ tools (for Windows builds)

## Install from Source

### 1. Clone the Repository

```bash
git clone https://github.com/submersion-app/submersion.git
cd submersion
```text
### 2. Install Dependencies

```bash
flutter pub get
```dart
### 3. Generate Code

Submersion uses code generation for the database (Drift) and state management (Riverpod). Run:

```bash
dart run build_runner build --delete-conflicting-outputs
```xml
<div class="tip">
<strong>Tip:</strong> During development, use <code>dart run build_runner watch</code> to automatically regenerate code when files change.
</div>

### 4. Run the App

<!-- tabs:start -->

#### **macOS**

```bash
flutter run -d macos
```text
#### **iOS Simulator**

```bash
flutter run -d ios
```text
For a physical iOS device:

```bash
open ios/Runner.xcworkspace
# Configure signing in Xcode, then:
flutter run -d ios
```text
#### **Android**

```bash
flutter run -d android
```text
#### **Windows**

```bash
flutter run -d windows
```text
#### **Linux**

```bash
flutter run -d linux
```text
<!-- tabs:end -->

## Build for Release

### iOS

```bash
flutter build ios --release
```text
Then archive and distribute via Xcode.

### Android

```bash
# APK
flutter build apk --release

# App Bundle (for Play Store)
flutter build appbundle --release
```text
### macOS

```bash
flutter build macos --release
```text
### Windows

```bash
flutter build windows --release
```text
### Linux

```bash
flutter build linux --release
```text
## Troubleshooting

### Code Generation Fails

If `build_runner` fails, try:

```bash
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```sql
### iOS Signing Issues

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the Runner project
3. Go to "Signing & Capabilities"
4. Select your development team
5. Ensure "Automatically manage signing" is checked

### Android SDK Issues

Make sure your Android SDK is properly configured:

```bash
flutter doctor
```text
Follow any recommendations to resolve issues.

### Missing Platform Dependencies

```bash
# macOS
xcode-select --install

# Linux (Ubuntu/Debian)
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev

# Windows
# Install Visual Studio with "Desktop development with C++"
```

## Next Steps

Once installed, proceed to [Your First Dive](guide/first-dive.md) to log your first dive entry.
