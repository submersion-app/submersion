# Update Channels

Submersion ships on two channels:

- **Stable** — tested releases, published every few weeks. This is what you
  get by default, and the right choice for most divers.
- **Beta** — new builds published from every change, usually within the hour.
  Betas are how fixes and features reach real divers early, and how problems
  get caught before a stable release. Every stable release is a beta build
  that proved itself first.

If you have ever wished a fix arrived sooner, or you enjoy trying features
early and reporting what you find, the beta channel is for you.

## What to expect on the beta channel

> [!IMPORTANT]
> Betas may upgrade your dive log's database **before** the stable release
> does. Three things follow from that:
>
> 1. **Switching back to stable is not a downgrade.** You keep your current
>    beta version until the next stable release is newer than it, then
>    rejoin stable automatically.
> 2. **Devices that sync together should use the same channel.** A device on
>    an older version will hold changes from a newer-schema device (with a
>    banner explaining why) until it updates.
> 3. **A backup is taken automatically** before any database upgrade, so
>    your dive log is protected either way.

Beta builds pass the full automated test suite before they are published —
"beta" means newest, not untested.

## Joining the beta

### macOS, Windows, and Linux

In Submersion **1.7.2 or later**: **Settings > About > Update channel >
Beta**. Confirm the dialog and the built-in updater switches to the beta
feed — updates then arrive exactly like stable ones, just sooner.

You can also download any beta directly from
**[beta-builds releases](https://github.com/submersion-app/beta-builds/releases)**.

### iOS (and the Mac App Store version)

Join through TestFlight:

**[testflight.apple.com/join/aMD393sB](https://testflight.apple.com/join/aMD393sB)**

Install Apple's TestFlight app if you don't have it, open the link, and
TestFlight delivers beta updates automatically from then on.

### Android

Join the testing program with your Google account:

**[play.google.com/apps/testing/app.submersion](https://play.google.com/apps/testing/app.submersion)**

> [!NOTE]
> The Android beta currently runs as a closed test while Google's
> requirements for new testing programs are met, so the link may ask you to
> request access first. Beta APKs are also available for direct download
> from [beta-builds releases](https://github.com/submersion-app/beta-builds/releases).

## Leaving the beta

- **Desktop:** Settings > About > Update channel > Stable. You stay on your
  current version until the next stable release passes it.
- **iOS:** delete the TestFlight build and reinstall from the App Store.
- **Android:** leave the testing program from the same opt-in page, then
  reinstall from the Play Store when the next stable release is out.

## Reporting a problem

Beta reports are the whole point of the channel. Open an issue at
**[github.com/submersion-app/submersion/issues](https://github.com/submersion-app/submersion/issues)**
and include your exact version from **Settings > About** (for example
`1.7.2.4977 (Beta)`) — the last number identifies the precise build you were
running.
