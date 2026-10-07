# Installation

Submersion runs on iOS, Android, macOS, Windows, and Linux. Download it from
your platform's store or from GitHub Releases, then open it and dive in.

## iOS

Install Submersion from the App Store:

**[Submersion Dive Log on the App Store](https://apps.apple.com/us/app/submersion-dive-log/id6757456915)**

Requires **iOS 15** or later. Once installed, the App Store keeps Submersion
up to date automatically.

## Android

Install Submersion from Google Play:

**[Submersion Dive Log on Google Play](https://play.google.com/store/apps/details?id=app.submersion)**

Requires **Android 8.0 (API 26)** or later. Once installed, Google Play keeps
Submersion up to date automatically.

### Installing the APK instead

If you would rather not use Google Play (on a device without Google services,
for example), download the latest APK from
**[GitHub Releases](https://github.com/submersion-app/submersion/releases)**.

> [!NOTE]
> Because the APK comes from outside the Play Store, Android will ask you to
> allow installation from unknown sources when you open the file. This is
> normal for sideloaded apps. Submersion's built-in updater will notify you
> when a new version is available so you can download and install it the same
> way.

## macOS

Download the latest **DMG** from
**[GitHub Releases](https://github.com/submersion-app/submersion/releases)**
(`Submersion-vX.Y.Z-macOS.dmg`).

Requires **macOS 12 Monterey** or later.

Open the DMG, drag Submersion to your Applications folder, and launch it.

> [!NOTE]
> **Gatekeeper on first open:** Because Submersion is distributed outside the
> Mac App Store, macOS Gatekeeper may block the first launch. If you see an
> "app can't be opened" message, right-click (or Control-click) the app icon
> and choose **Open**, then click **Open** in the dialog. You only need to do
> this once.

Submersion checks for updates automatically in the background using Sparkle.
You can also trigger a check manually from the **Submersion** menu >
**Check for Updates…** at any time.

<!-- screenshot: images/installation/check-for-updates.png: desktop Check for Updates dialog -->

## Windows

Download the latest **installer** from
**[GitHub Releases](https://github.com/submersion-app/submersion/releases)**
(`Submersion-vX.Y.Z-Windows-Setup.exe`).

Requires **Windows 10** or later (64-bit).

Run the installer. It creates a Start Menu shortcut and registers an
uninstaller in Add/Remove Programs. No manual extraction required.

> [!NOTE]
> **Windows SmartScreen:** Because the installer is not code-signed, Windows
> SmartScreen may show an "unrecognized app" warning the first time you run it.
> Click **More info**, then **Run anyway** to proceed.

Submersion checks for updates automatically in the background using
WinSparkle. You can also trigger a check from the window's system menu
(**Alt+Space** > **Check for Updates...**) or from **Settings > About >
Check for Updates**.

## Linux

> [!IMPORTANT]
> Submersion needs **glibc 2.38 or newer**: Ubuntu 24.04+, Debian 13+,
> Fedora 39+, Linux Mint 22+, Arch, or openSUSE Tumbleweed. On older
> distributions (Debian 12, Ubuntu 22.04, RHEL 9) the app installs but does
> not start, whichever download you use.

Every release on
**[GitHub Releases](https://github.com/submersion-app/submersion/releases)**
offers three Linux downloads. Use the package for your distribution if there
is one.

**Debian, Ubuntu, Mint and derivatives:** download
`Submersion-vX.Y.Z-Linux-amd64.deb`, then:

```bash
sudo apt install ./Submersion-*-Linux-amd64.deb
```

**Fedora and RHEL:** download `Submersion-vX.Y.Z-Linux-x86_64.rpm`, then
`sudo dnf install ./Submersion-*-Linux-x86_64.rpm`. On **openSUSE**, install
the same `.rpm` with `sudo zypper install`.

Both packages add a desktop entry, icons, and udev rules that let a dive
computer connected by USB be reached without joining any group.

**Everything else** (Arch, NixOS, or if you prefer not to install packages):
download `Submersion-vX.Y.Z-Linux.tar.gz`, unpack it, and run the installer
inside:

```bash
tar xzf Submersion-*-Linux.tar.gz
./install.sh
```

`install.sh` installs into your home folder (a desktop entry and icon in
`~/.local/share`, the app linked into `~/.local/bin`), tells you the exact
command for any shared library you are missing, and prints the command that
installs the USB udev rules, which needs root. `./uninstall.sh` removes the
app, its desktop entry and its icon, and never touches your dive log. It leaves
the udev rules in place and prints the commands (run with `sudo`) to remove
them.

> [!TIP]
> Compressing videos you attach to dives needs `ffmpeg`. It is optional: the
> packages recommend it but do not require it.

Submersion checks GitHub Releases for updates and shows a banner inside the
app when a new version is available.

## Keeping the app up to date

How updates reach you depends on the platform:

| Platform | Update mechanism |
|----------|-----------------|
| **iOS** | App Store handles updates automatically |
| **Android** | Google Play handles updates for Play installs; the APK checks GitHub Releases, and a banner appears in-app when a new version is ready to download |
| **macOS** | Sparkle checks on launch and every few hours; a dialog prompts you to install and restart |
| **Windows** | WinSparkle checks on launch and every few hours; an installer runs automatically on restart |
| **Linux** | Submersion checks GitHub Releases; a banner appears in-app when a new version is ready to download |

On all desktop platforms you can check immediately via **Settings > About >
Check for Updates** (or the platform menu item on macOS and Windows). The
automatic check runs with a short delay after launch so it does not slow
startup.

## Building from source

If you want to build Submersion yourself, to test a patch, contribute a fix,
or audit the code, the full build instructions are in the
**[repository README](https://github.com/submersion-app/submersion#getting-started)**
and `CONTRIBUTING.md`. In short, you need Flutter 3.47 or newer (the exact
version CI uses is in `.github/flutter-version.txt`), then:

```bash
git clone --recurse-submodules https://github.com/submersion-app/submersion.git
cd submersion
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d macos   # or: windows, linux, ios, android
```

Build-from-source instructions are developer-focused and not needed for
normal use.

## Want new features early?

Submersion also has a **beta channel**: builds published from every change,
on every platform. See [Update Channels](update-channels.md) for what that
means and how to join.

## See also

- [Your First Dive](first-dive.md)
- [Update Channels](update-channels.md)
- [Multi-Device Sync](multi-device-sync.md)
- [Backup and Restore](backup-and-restore.md)
- [Settings](settings.md)
