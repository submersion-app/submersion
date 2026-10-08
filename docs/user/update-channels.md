# Update Channels

Submersion ships on two channels:

- **Stable:** tested releases, published every few weeks. This is what you get
  by default, and the right choice for most divers.
- **Beta:** new builds published from every change. Betas are how fixes and
  features reach real divers early, and how problems get caught before a stable
  release. Every stable release is a beta build that proved itself first.

If you have ever wished a fix arrived sooner, or you enjoy trying features early
and reporting what you find, the beta channel is for you.

## What to expect on the beta channel

> [!IMPORTANT]
> Betas may upgrade your dive log's database **before** the stable release
> does. Three things follow from that:
>
> 1. **Switching back to stable is not a downgrade.** You keep your current
>    beta version until the next stable release is newer than it, then rejoin
>    stable automatically.
> 2. **Devices that sync together should use the same channel.** A device on an
>    older version holds back changes from a device on a newer version (with a
>    banner explaining why) until it updates.
> 3. **A backup is taken automatically** before any database upgrade, so your
>    dive log is protected either way.

Beta builds pass the full automated test suite before they are published: beta
means newest, not untested.

## Joining the beta

How you join depends on where you installed Submersion.

### Downloaded from GitHub (macOS, Windows, Linux, Android APK)

These builds update themselves. In **Settings > About**, under **Updates**,
tap **Update channel** and choose **Beta** ("New builds from every change,
ahead of stable"). Confirm **Receive beta updates?** with **Switch to Beta**,
and the app checks for a beta straight away. Updates then arrive exactly like
stable ones, just sooner.

The same **Updates** card has **Check for Updates**, **Automatic updates**
(checks every few hours; on by default) and when it **Last checked**.

You can also download any beta directly from
**[beta-builds releases](https://github.com/submersion-app/beta-builds/releases)**.

> [!NOTE]
> On Linux, if you installed the `.deb` or `.rpm` package, the update banner
> gives you the command to upgrade with your package manager. Builds from the
> Microsoft Store and the Snap Store are updated by the store and have no
> **Update channel** setting.

### iOS and the Mac App Store version

Join through TestFlight. **Join the Beta** in **Settings > About** opens the
link, or use it directly:

**[testflight.apple.com/join/aMD393sB](https://testflight.apple.com/join/aMD393sB)**

Install Apple's TestFlight app if you don't have it, open the link, and
TestFlight delivers beta updates automatically from then on.

### Android (Google Play)

Join the testing program with your Google account. **Join the Beta** in
**Settings > About** opens the page, or use it directly:

**[play.google.com/apps/testing/app.submersion](https://play.google.com/apps/testing/app.submersion)**

> [!NOTE]
> Every Play beta goes through Google's review, so betas reach Google Play less
> often than other platforms: at most every couple of days.

## Leaving the beta

- **Builds from GitHub:** **Settings > About > Update channel > Stable**, and
  confirm **Return to stable updates?** with **Switch to Stable**. You stay on
  your current version until the next stable release passes it.
- **iOS:** delete the TestFlight build and reinstall from the App Store.
- **Android:** leave the testing program from the same opt-in page, then
  reinstall from Google Play when the next stable release is out.

## Reporting a problem

Beta reports are the whole point of the channel. Open an issue at
**[github.com/submersion-app/submersion/issues](https://github.com/submersion-app/submersion/issues)**
and include your exact version from **Settings > About** (for example
"Version 1.7.2.4977 (Beta)"): the last number identifies the precise build you
were running. **Copy diagnostics** in the same place copies your version, device
and recent log lines ready to paste into the report.
