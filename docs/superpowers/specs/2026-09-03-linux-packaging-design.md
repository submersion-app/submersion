# Linux Packaging Design

**Problem:** the Linux download is a tar.gz of loose files. It installs nothing,
declares nothing, and resolves nothing, so getting Submersion running on a Linux
system is a research project.

## The gap

`.github/workflows/build-all.yml:620-623` is the entire packaging story:

```yaml
- name: Create tarball
  run: |
    cd build/linux/x64/release/bundle
    tar czf "$GITHUB_WORKSPACE/Submersion-${TAG_NAME}-Linux.tar.gz" .
```

The archive holds `submersion`, `data/`, and `lib/` (bundled native assets:
sqlcipher, pdfium, libdivecomputer, objectbox). A user who unpacks it does not
get:

| Missing | Consequence |
| --- | --- |
| Any dependency declaration | GTK3, `libwebkit2gtk-4.1`, `libsoup-3.0`, `libsecret-1`, `liblzma`, `libstdc++` must already be present. Absent any of them, the loader emits a soname error, not a message. |
| `.desktop` file and icons | No menu entry, no dock icon, no `StartupWMClass` binding. Launch is `./submersion` from a terminal. |
| Device permissions | The Linux dive computer path opens `/dev/hidraw*` (`packages/libdivecomputer_plugin/linux/usbhid_enumerator.c`), `/dev/ttyUSB*` and `/dev/ttyACM*` (`serial_scanner.c`), and BlueZ over D-Bus (`ble_scanner.c`). `hidraw` is root-only by default, so USB dive computers simply never appear. |
| A stated distro requirement | Built on `ubuntu-latest`, and the shipped libraries require GLIBC_2.38, so the binary refuses to start on Debian 12 or Ubuntu 22.04. Nothing said so anywhere, which is the part this design fixes; the floor itself is kept (see Section 3). |
| A working updater | `lib/features/auto_update/presentation/providers/update_providers.dart:43` points Linux at the `Linux.tar.gz` asset, and `update_banner.dart:49` opens it in a browser. There is no install step to hand it to. |

This was a deliberate deferral, not an oversight:
`docs/plans/2026-02-12-github-releases-design.md:173` records "Linux package
formats (Snap, Flatpak, AppImage) -- tar.gz only for now."

## Decisions

| Decision | Choice |
| --- | --- |
| Formats | `.deb` and `.rpm` as the primary path, plus an upgraded tarball for everything else. No Flatpak, AppImage, or Snap. |
| Compatibility floor | glibc 2.38, the floor the released tarball has always had. Covers Ubuntu 24.04+, Debian 13+, Fedora 39+, Mint 22, Arch and Tumbleweed. Excludes Debian 12, Ubuntu 22.04, and RHEL 9, which keep the tarball as today. |
| Updates | Self-hosted APT and DNF repositories, so `apt upgrade` and `dnf upgrade` carry Submersion along with everything else. |
| Repo hosting | A new `submersion-app/linux-packages` repo published to GitHub Pages, rebuilt statelessly on each release. |
| Channels | `stable` and `beta` suites from day one. |
| Self-enrollment | Packages downloaded directly from GitHub Releases install the repo definition and signing key, disclosed plainly. |
| Build mechanism | One Flutter build, one staging tree, two emitted packages. |

`promote.yml:87` resolves a beta tag and reuses it as the stable tag, copying
assets without rebuilding, and tags carry no `-beta` suffix (`v1.7.6.7161`).
A package built once is therefore byte-identical in both channels, and
promotion stays a file copy.

## Section 1: What the package installs

`scripts/release/stage_linux_package.py` builds a canonical staging tree from
the untouched Flutter bundle. Both formats are emitted from that one tree, so
the `.deb` and the `.rpm` are provably the same binary.

| Path | Source |
| --- | --- |
| `/usr/lib/submersion/` | `build/linux/x64/release/bundle/` verbatim |
| `/usr/bin/submersion` | generated wrapper: `exec /usr/lib/submersion/submersion "$@"` |
| `/usr/share/applications/app.submersion.desktop` | generated |
| `/usr/share/icons/hicolor/{16,32,48,64,128,256,512}x{same}/apps/app.submersion.png` | downscaled from `assets/icon/icon.png` |
| `/usr/share/metainfo/app.submersion.metainfo.xml` | generated, with release history |
| `/usr/lib/udev/rules.d/60-submersion-divecomputers.rules` | generated (below) |
| `/usr/lib/submersion/INSTALL_METHOD` | literal `deb` or `rpm` |

Preserving the bundle layout verbatim is what keeps the runner's
`$ORIGIN/lib` rpath (`linux/CMakeLists.txt:17`) working with no build change.
`/usr/bin/submersion` is a wrapper rather than a symlink, not because `$ORIGIN`
needs it (it resolves through symlinks correctly), but because the wrapper is
where environment variables can be set later without re-cutting a release.

The `.desktop` file sets `Categories=Science;Education;Utility;` and
`StartupWMClass=submersion`, without which the running window fails to bind to
its own icon in GNOME and KDE docks. The AppStream metainfo file is what makes
GNOME Software and KDE Discover show a name, a description, and screenshots
instead of an unnamed blob.

### udev rules are generated, not copied

libdivecomputer ships
`packages/libdivecomputer_plugin/third_party/libdivecomputer/contrib/udev/libdivecomputer.rules`,
but it is 35 lines covering roughly nine devices, and every rule reads
`GROUP="plugdev"`. That group does not exist on Fedora, so the file half-works
by construction.

`scripts/gen_udev_rules.py` parses the descriptor table in the libdivecomputer
submodule and emits rules using `TAG+="uaccess"`, which grants access to the
user on the active seat through systemd-logind. No group membership, no
`usermod -aG`, no log out and back in, and identical behavior on Debian and
Fedora. Access follows the seat, so it is also revoked on fast user switching,
which group membership never does.

Rules cover the three subsystems the Linux plugin actually opens: `hidraw`,
`tty` for USB-serial adapters, and the raw `usb` node. A fixture test asserts
the generator's output, so a submodule bump that changes the table's shape
fails loudly rather than silently emitting an empty file.

BLE needs no rules. BlueZ mediates over the D-Bus system bus, which desktop
sessions may already use.

## Section 2: Dependency declarations

The failure mode to design against is a plugin's CMake fallback quietly
changing the runtime contract. `desktop_webview_window` is the live example
(`desktop_webview_window-0.3.0/linux/CMakeLists.txt:10-17`):

```cmake
pkg_check_modules(WebKit IMPORTED_TARGET webkit2gtk-4.1)
if(NOT WebKit_FOUND)
  pkg_check_modules(WebKit REQUIRED IMPORTED_TARGET webkit2gtk-4.0)
endif()
pkg_check_modules(LibSoup REQUIRED IMPORTED_TARGET libsoup-3.0)
```

Pin a runner, hand-write a dependency list, and you can ship a package that
declares 4.1 while linking 4.0. So the list is derived, not asserted.

`scripts/linux_package_deps.py` reads `DT_NEEDED` out of the built `submersion`
binary and every `lib/*.so`, subtracts the libraries bundled inside the
package, and maps each remaining soname through an explicit table. **An
unmapped soname is a hard build failure.** This is deliberately the same guard
shape as `scripts/check_bundled_native_assets.py`, which exists because issue
#1129 proved a missing library stays invisible until a user launches the app.

Starting content of the table, from what the plugins link today:

| soname | apt | rpm | pacman | zypper |
| --- | --- | --- | --- | --- |
| `libgtk-3.so.0` | `libgtk-3-0` | `libgtk-3.so.0()(64bit)` | `gtk3` | `gtk3` |
| `libwebkit2gtk-4.1.so.0` | `libwebkit2gtk-4.1-0` | `libwebkit2gtk-4.1.so.0()(64bit)` | `webkit2gtk-4.1` | `webkit2gtk-4_1` |
| `libsoup-3.0.so.0` | `libsoup-3.0-0` | `libsoup-3.0.so.0()(64bit)` | `libsoup3` | `libsoup-3_0-0` |
| `libsecret-1.so.0` | `libsecret-1-0` | `libsecret-1.so.0()(64bit)` | `libsecret` | `libsecret-1-0` |
| `liblzma.so.5` | `liblzma5` | `liblzma.so.5()(64bit)` | `xz` | `liblzma5` |
| `libstdc++.so.6` | `libstdc++6` | `libstdc++.so.6()(64bit)` | `gcc-libs` | `libstdc++6` |

The `pacman` and `zypper` columns are unused by the packages themselves and
exist for the tarball's preflight check (Section 6).

Depending on **sonames** in the RPM rather than package names is what lets one
`.rpm` install on Fedora, openSUSE, and RHEL alike: Fedora names the package
`gtk3` while openSUSE names it `libgtk-3-0`, but both provide
`libgtk-3.so.0()(64bit)`.

`printing` needs `gtk+-unix-print-3.0` (`printing-5.15.0/linux/CMakeLists.txt:50`),
which ships inside GTK3 itself and adds no new dependency. Its pdfium is
bundled.

### Two weak dependencies

Both `Recommends`, never `Requires`:

- **`ffmpeg`.** `lib/features/media_store/data/platform_video_transcoder.dart:27`
  looks it up on `PATH` and degrades gracefully, with a localized message
  already shipped in all 11 languages ("Install ffmpeg to enable video
  compression. Originals are uploaded until then."). It must stay weak because
  stock Fedora has no ffmpeg at all: it lives in RPM Fusion, so a hard
  `Requires` would make the package uninstallable on a default Fedora system.
- **`gnome-keyring`.** `flutter_secure_storage_linux` requires libsecret
  (`flutter_secure_storage_linux-3.0.2/linux/CMakeLists.txt:15`) and therefore a
  running Secret Service provider. Present on GNOME and KDE; absent on minimal
  window managers, where sync encryption would otherwise fail at runtime with
  no explanation.

## Section 3: Build and CI wiring

### The glibc floor is the runner's, and is left alone

An earlier revision of this design built inside an `ubuntu:22.04` container to
pin a glibc 2.35 floor. That was reverted, for two reasons.

The first is that it reversed a decision without saying so. The floor question
was asked and answered as "build on the ubuntu-22.04 runner"; the container
arrived later in the design, argued as a fresh recommendation rather than as a
change, on the premise that a retired runner label would raise the floor
silently. Retired labels fail loudly, so the premise was wrong.

The second is that the reach was never real to begin with. Measured against
the shipped v1.7.6.7161 tarball, the released binaries already require
GLIBC_2.38:

| File | Requires |
| --- | --- |
| `libflutter_secure_storage_linux_plugin.so` | GLIBC_2.38 |
| `liblibdivecomputer_plugin_plugin.so` | GLIBC_2.38 |
| `libsqlcipher.so` | GLIBC_2.38 |
| `submersion` | GLIBC_2.34 |

The floor is set by three libraries, not by the app. Lowering it would have
extended Submersion to distros it has never supported, at the cost of a
container, a toolchain install on every run, and a class of missing-tool
failures that no pull request can catch, since `build-all.yml` is
`workflow_call`-only. Debian 12 and Ubuntu 22.04 have never been able to run a
release and gain no fallback here: the tarball bundles the same three libraries
and fails on those distros for the same reason.

```yaml
build-linux:
  runs-on: ubuntu-latest      # glibc floor follows the runner image
```

The consequence to accept: when GitHub moves `ubuntu-latest` to the next
release, the floor rises with it and nothing announces that. The distro
requirement in the install docs is therefore a statement about the current
build environment rather than a guarantee.

The existing `apt-get install` step (`build-all.yml:565`) moves inside the
container and gains `curl git unzip xz-utils ca-certificates`, which a bare
image lacks and `subosito/flutter-action` assumes. Two container traps to
handle explicitly:

- `actions/checkout` inside a container trips git's "dubious ownership" check;
  the job needs `git config --global --add safe.directory '*'`.
- The container runs as root. The build creates and uses an unprivileged user
  so Flutter's tooling behaves as it does everywhere else.

### New steps, after the existing native-asset guard

1. `scripts/gen_udev_rules.py`
2. `scripts/release/stage_linux_package.py`
3. `scripts/linux_package_deps.py`
4. `fpm --input-type dir` once per format, fed the derived dependency list.
   Ruby is already in the release pipeline (`release.yml:106`), so `fpm` costs
   nothing new.
5. the existing tarball step, unchanged

### Asset naming follows the existing six assets

`Submersion-${TAG}-Linux-amd64.deb` and `Submersion-${TAG}-Linux-x86_64.rpm`,
not the Debian-conventional `submersion_1.7.6.7161_amd64.deb`.

Conventional names are lowercase and would slip straight through the
`Submersion-*` globs that build the checksum file (`release.yml:335` and `:388`,
`beta.yml:230`), which is exactly the bug `beta.yml` already carries a comment
about, where `Submersion.pkg` was silently omitted from checksums. The
filename is cosmetic in any case: the repository indexer assigns pool paths
from package metadata, not from the downloaded name.

`validate-release`'s `EXPECTED` array (`release.yml:434`) gains both files, so
a packaging step that fails without failing the build still blocks the release.

### A new `verify-linux-packages` job

Install the `.deb` in a clean `debian:12` container and the `.rpm` in a clean
`fedora:latest` container, using the real package manager, so an unsatisfiable
dependency is a test failure rather than a user's bug report. Then run
`submersion --version` and assert the output.

That last check needs a small addition to `linux/runner/main.cc`, which today
is the stock six lines. A `--version` short-circuit that prints and exits
before `g_application_run` means the smoke test needs no display server at all.

## Section 4: The APT and DNF repositories

A new public repo, `submersion-app/linux-packages`, served from Pages at
`packages.submersion.app`.

**Stateless by construction.** Each run downloads the packages it needs from
GitHub Releases, regenerates the whole site, and deploys via
`actions/upload-pages-artifact`. Nothing large is ever committed, so there is
no history to prune and no drift between git and what is served. The repo is
not the source of truth for packages; it is a view over GitHub Releases, which
is what makes a nightly reconcile able to repair it.

```
/submersion.gpg                          dearmored public key, for signed-by=
/apt/dists/{stable,beta}/main/binary-amd64/Packages{,.gz}
/apt/dists/{stable,beta}/{Release,Release.gpg,InRelease}
/apt/pool/main/s/submersion/*.deb
/rpm/{stable,beta}/{repodata/,*.rpm}
/submersion.repo                         drop-in for /etc/yum.repos.d/
/setup.sh                                documented convenience script
```

APT metadata is `dpkg-scanpackages`, then `apt-ftparchive release`, then
`gpg --clearsign`. Neither `reprepro` nor `aptly` is used: both want a
persistent database that a stateless rebuild would have to fake. DNF metadata is
`createrepo_c`, with the RPMs signed by `rpmsign --addsign` and `repomd.xml`
detached-signed with the same key.

**Retention: two versions per suite.** Two suites, two versions, two formats,
roughly 40 MB each puts the site near 320 MB against the 1 GB Pages cap. The
workflow fails if the assembled site exceeds 800 MB rather than discovering the
cap mid-deploy. Bandwidth is the softer constraint: the 100 GB/month soft limit
is roughly 2,500 package downloads, while the metadata every `apt update`
fetches is negligible.

**Triggering is belt and braces**, because a missed publish means users silently
stop receiving updates:

- `repository_dispatch` fired by `release.yml`, `beta.yml`, and `promote.yml`
  on success
- a daily `schedule` that reconciles the published site against the latest
  releases and republishes when they disagree, making a dropped dispatch
  self-healing rather than permanent
- `workflow_dispatch` for manual repair

**Signing key**: generated offline, stored passphrase-protected in that repo's
Actions secrets with the passphrase as a second secret. It signs both the
repository metadata and the RPMs themselves.

### Self-enrollment

Packages downloaded directly from GitHub Releases install the repo definition
and the signing key, so a one-time manual download keeps receiving updates.
This is what Chrome, VS Code, and Docker do, and without it most direct-download
users would quietly run one version forever.

It is disclosed in three places: the package description, the release notes,
and the install documentation, each stating what is added and giving the
one-line removal for anyone who objects.

## Section 5: The in-app updater on packaged installs

Linux uses `GithubUpdateService` (`update_providers.dart:77`), matches the
`Linux.tar.gz` asset, and opens that URL in a browser
(`update_banner.dart:49`). On a dpkg-managed install that is actively wrong: it
hands the user a tarball that would shadow the packaged copy.

A new `linuxInstallMethodProvider` reads the `INSTALL_METHOD` marker beside
`Platform.resolvedExecutable`, yielding `deb`, `rpm`, or `tarball` when the file
is absent. It follows the provider pattern established at
`lib/features/settings/presentation/providers/sync_providers.dart:86`, where
`isLinuxPlatformProvider` exists as a provider rather than an inline `Platform`
check precisely so widget tests can simulate the platform on a macOS CI host.

| Install method | Behavior |
| --- | --- |
| `tarball` | Unchanged: download link to the new tarball. |
| `deb` / `rpm` | The check still runs, but the banner drops the Download button and shows `sudo apt upgrade submersion` or `sudo dnf upgrade submersion` with a copy affordance. No browser navigation. |

Keeping the check while removing the download action is the honest split: the
app knows something the package manager has not told the user yet, but it is
not the thing that should install it.

## Section 6: The tarball, upgraded

The tarball remains the escape hatch for Arch, NixOS, and anyone who will not
use a package manager. It gains three files:

- **`install.sh`**: installs to `~/.local/opt/submersion` by default with no
  root, writes a `.desktop` file and icons into `~/.local/share`, symlinks
  `~/.local/bin/submersion`, and offers to install the udev rules with `sudo`
  or print the command for the user to run themselves.
- **`uninstall.sh`**: reverses exactly that, udev rules included.
- **`deps.json`**: the soname table from Section 2.

The preflight check is what turns a loader error into an actionable message:
run `ldd` over the binary and every plugin `.so`, collect `not found` sonames,
map them through `deps.json`, detect which of `apt`, `dnf`, `pacman`, or
`zypper` is present, and print the exact command. One table, four package
managers, and the same table that produced the package dependencies.

The tarball does not self-enroll in the repositories: there is no installed
package for `apt` to upgrade.

## Section 7: Testing

| Layer | Test |
| --- | --- |
| `gen_udev_rules.py` | Fixture-based: a captured descriptor-table slice in, expected rules out. Guards against a submodule bump silently emitting nothing. |
| `stage_linux_package.py` | Tree layout, desktop-file contents, marker file, icon sizes. |
| `linux_package_deps.py` | Mapping correctness, and that an unmapped soname raises rather than being dropped. |
| `install.sh` | Shell test in the style of `scripts/pre_push_hook_test.sh`, plus shellcheck. |
| Packages | `verify-linux-packages`: real install in clean `debian:12` and `fedora:latest` containers, then `submersion --version`. |
| Updater | Dart tests with `linuxInstallMethodProvider` overridden per install method. |
| Repo workflow | Assembled-site size guard, and a dry run that verifies `apt update` succeeds against the built site before deploying. |

Python tests follow the existing `scripts/*_test.py` convention.

## Section 8: Documentation

- `README.md` and `docs/guide/installation.md`: three paths (add the repo,
  direct `.deb`/`.rpm` download, tarball), with self-enrollment stated plainly
  and the removal command given.
- `docs/developer/release-secrets-setup.md`: GPG key generation and storage,
  and the dispatch token.
- Release notes for the version that ships this: the new formats and the
  self-enrollment behavior.

## Out of scope

Listed so they are deliberate rather than forgotten:

- Flatpak, AppImage, Snap
- arm64: the build is x86-64 only today. The asset naming leaves room, but no
  aarch64 build exists.
- `.uddf` and `.ssrf` file associations (a MIME XML plus desktop-file
  `MimeType=`). A natural follow-up.
- The website download page, which lives in the separate `submersion-website`
  repo.

## Risks

| Risk | Mitigation |
| --- | --- |
| ~~`libwebkit2gtk-4.1` may be unavailable on Ubuntu 22.04~~ | Moot as of 2026-09-04: the 22.04 build environment was reverted, so the build uses the runner's own webkit 4.1. The fallback remains impossible to ship unnoticed either way, since it would put `libwebkit2gtk-4.0.so.37` in the derived dependency list and an unmapped soname fails the build. |
| A libdivecomputer submodule bump changes the descriptor table's shape and the udev generator emits nothing. | Fixture test on the generator's output. |
| A plugin update introduces a new shared-library dependency. | `linux_package_deps.py` fails the build on any unmapped soname. |
| Pages bandwidth or size limits are reached as the Linux audience grows. | Two-versions-per-suite retention, an 800 MB pre-deploy guard, and a documented migration path to a package registry if the limits bind. |
| The repository publish dispatch is dropped and users stop seeing updates. | Daily reconcile job republishes when the site and the latest releases disagree. |
| The glibc floor rises silently when GitHub moves `ubuntu-latest` to a newer release, invalidating the distro requirement in the install docs. | Accepted deliberately in exchange for build simplicity. The requirement is documented as a statement about the current build environment, not a guarantee. A CI guard asserting the maximum required GLIBC symbol version would make the drift visible; not implemented. |
