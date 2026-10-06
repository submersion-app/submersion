# Linux Packaging Phase 1: Installable Packages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ship `.deb` and `.rpm` packages that install Submersion, declare their
own dependencies, register desktop integration, and grant dive computer device
access, plus a tarball that diagnoses what it needs.

**Architecture:** one Flutter build inside an `ubuntu:22.04` container produces
a bundle; a staging script turns that bundle into a canonical filesystem tree; a
dependency script derives the runtime dependency list from the built binary's
`DT_NEEDED` entries; `fpm` emits both package formats from that one tree. Clean
containers install the results in CI as a smoke test.

**Tech Stack:** GitHub Actions, Docker containers, Python 3 (stdlib only), fpm
(Ruby), dpkg, rpm, systemd udev, Flutter/Dart, C++ (GTK runner).

**Spec:** `docs/superpowers/specs/2026-09-03-linux-packaging-design.md`

**Phase 2** (the APT/DNF repositories on GitHub Pages, self-enrollment, and the
in-app update-channel wiring that depends on them) is a separate plan, written
after this one lands. Phase 1 stands alone: it gives Linux users installable,
dependency-resolving packages from GitHub Releases.

## Global Constraints

- **Worktree:** all work happens in `.claude/worktrees/linux-packaging` on
  branch `feat/linux-packaging`. Never check this branch out in the main tree.
- **No em-dashes** (U+2014) in any file, comment, commit message, or PR body.
  En-dashes as prose punctuation and spaced hyphens are equally forbidden.
- **No emojis** in code, comments, or documentation.
- **Python scripts are stdlib only**, matching `scripts/check_bundled_native_assets.py`.
  Each gets a sibling `*_test.py` runnable as `python3 scripts/<name>_test.py`,
  using `unittest`.
- **Package identity:** name `submersion`, binary `submersion`, application ID
  `app.submersion`, license `GPL-3.0`, homepage `https://submersion.app`,
  maintainer `Submersion <dev@submersion.app>`, description
  `An open-source dive logging application for scuba divers.`
- **Version string:** the release tag with the leading `v` stripped, for example
  tag `v1.7.7.7180` gives package version `1.7.7.7180`.
- **Asset names:** `Submersion-${TAG_NAME}-Linux-amd64.deb` and
  `Submersion-${TAG_NAME}-Linux-x86_64.rpm`. Capital S, matching the existing
  six assets, so the `Submersion-*` checksum globs pick them up.
- **Build floor:** glibc 2.35 via `container: ubuntu:22.04`.
- **udev rules** use `TAG+="uaccess"`, never `GROUP="plugdev"` or
  `GROUP="dialout"`.
- **Immutability:** never mutate objects or arrays in Dart code.
- **After any Dart change:** run `dart format .` over the whole project.
- **File size:** 200-400 lines typical, 800 maximum.

---

## File Structure

**Created:**

| File | Responsibility |
| --- | --- |
| `scripts/gen_udev_rules.py` | Parse libdivecomputer's VID/PID tables, emit udev rules |
| `scripts/gen_udev_rules_test.py` | Fixture tests for the generator |
| `scripts/data/linux_soname_map.json` | soname to package name, for four package managers |
| `scripts/linux_package_deps.py` | Read `DT_NEEDED` from a bundle, map to dependency tokens |
| `scripts/linux_package_deps_test.py` | Tests for the mapping, including the unmapped-soname failure |
| `scripts/release/stage_linux_package.py` | Build the canonical install tree from a bundle |
| `scripts/release/stage_linux_package_test.py` | Tests for tree layout and generated file contents |
| `scripts/release/linux_tarball_extras/install.sh` | Tarball installer with dependency preflight |
| `scripts/release/linux_tarball_extras/uninstall.sh` | Reverses install.sh |
| `scripts/release/install_sh_test.sh` | Shell tests for the installer |
| `lib/features/auto_update/domain/entities/linux_install_method.dart` | `LinuxInstallMethod` enum |
| `lib/features/auto_update/data/services/linux_install_method_reader.dart` | Reads the `INSTALL_METHOD` marker |
| `test/features/auto_update/data/linux_install_method_reader_test.dart` | Reader tests |
| `lib/features/auto_update/presentation/widgets/update_banner_actions.dart` | Banner action row, testable without providers |
| `test/features/auto_update/presentation/update_banner_actions_test.dart` | Banner action behavior per install method |

**Modified:**

| File | Change |
| --- | --- |
| `.github/workflows/build-all.yml:549-631` | Container build, packaging steps, new artifacts |
| `.github/workflows/release.yml:434` | `EXPECTED` gains the two package assets |
| `linux/runner/main.cc` | `--version` short-circuit |
| `lib/features/auto_update/presentation/providers/update_providers.dart` | `linuxInstallMethodProvider` |
| `lib/features/auto_update/presentation/widgets/update_banner.dart:47-52` | Package-manager hint instead of Download |
| `lib/l10n/arb/app_*.arb` (11 files) | New `autoUpdate_banner_packageManagerHint` key |
| `README.md`, `docs/guide/installation.md` | Linux install instructions |

---

### Task 1: Verify the Ubuntu 22.04 dependency floor

The spec makes this task one because the answer can invalidate the floor
decision. `.github/workflows/native-plugin-tests.yml:177-179` carries this
comment:

> libwebkit2gtk-4.1-dev: required since flutter_web_auth_2 pulled in
> desktop_webview_window, whose Linux plugin links webkit2gtk (4.1 on
> Ubuntu 24.04; its CMake falls back to the 4.0 name only on older distros).

If `libwebkit2gtk-4.1-dev` is absent on 22.04, `desktop_webview_window`
silently links `webkit2gtk-4.0` and `libsoup-2.4` instead
(`desktop_webview_window-0.3.0/linux/CMakeLists.txt:10-17`), which changes the
runtime contract without failing the build.

**Files:**
- Modify: `docs/superpowers/specs/2026-09-03-linux-packaging-design.md` (Risks table)

**Interfaces:**
- Produces: a recorded yes/no that Tasks 2, 5, and 7 depend on.

- [ ] **Step 1: Check package availability in a clean 22.04 image**

```bash
docker run --rm ubuntu:22.04 bash -c '
  apt-get update -qq
  apt-cache policy libwebkit2gtk-4.1-dev libsoup-3.0-dev libsecret-1-dev libgtk-3-dev
'
```

Expected: a `Candidate:` line with a real version for each, not `(none)`.

- [ ] **Step 2: Confirm the pkg-config module name resolves**

```bash
docker run --rm ubuntu:22.04 bash -c '
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq pkg-config libwebkit2gtk-4.1-dev > /dev/null
  pkg-config --exists webkit2gtk-4.1 && echo "webkit2gtk-4.1 OK"
  pkg-config --exists libsoup-3.0 && echo "libsoup-3.0 OK"
'
```

Expected: both `OK` lines. This is the exact check
`desktop_webview_window`'s CMake performs, so a pass here means no fallback.

- [ ] **Step 3: Record the result in the spec**

Replace the first row of the spec's Risks table with the finding. If both
checks passed, write:

```markdown
| ~~`libwebkit2gtk-4.1` may be unavailable on Ubuntu 22.04~~ | Verified 2026-09-03: `ubuntu:22.04` provides `libwebkit2gtk-4.1-dev` and `libsoup-3.0-dev`, and `pkg-config --exists webkit2gtk-4.1` succeeds, so no CMake fallback occurs at the chosen floor. |
```

If either check failed, **stop and escalate**: the floor decision needs
revisiting, and the remaining tasks assume it holds.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/2026-09-03-linux-packaging-design.md
git commit -m "docs: verify webkit2gtk-4.1 availability at the Ubuntu 22.04 floor"
```

---

### Task 2: Move the Linux build into an ubuntu:22.04 container

No packaging yet. This task changes only where the build runs, so a regression
here is unambiguous: the tarball it produces must be equivalent to today's.

**Files:**
- Modify: `.github/workflows/build-all.yml:549-570`

**Interfaces:**
- Produces: a `build/linux/x64/release/bundle/` built against glibc 2.35, which
  every later task consumes.

- [ ] **Step 1: Add the container and its prerequisites**

Replace the job header and dependency step in `.github/workflows/build-all.yml`:

```yaml
  build-linux:
    name: Build Linux
    runs-on: ubuntu-latest
    # The glibc floor is pinned by the container image, not the runner label:
    # GitHub retires runner images on its own schedule, and a label-pinned
    # floor would rise silently the day 22.04 is removed. glibc 2.35 covers
    # Ubuntu 22.04+, Debian 12+, and every current Fedora and openSUSE.
    container: ubuntu:22.04
    timeout-minutes: 40

    steps:
      - name: Install Linux dependencies
        run: |
          apt-get update -y
          DEBIAN_FRONTEND=noninteractive apt-get install -y \
            clang cmake ninja-build pkg-config \
            libgtk-3-dev liblzma-dev libstdc++-12-dev \
            libsqlite3-dev libsecret-1-dev libwebkit2gtk-4.1-dev \
            libssl-dev \
            curl git unzip xz-utils ca-certificates sudo file rpm

      # actions/checkout inside a container trips git's dubious-ownership
      # check, which makes every later git command fail.
      - name: Trust the workspace
        run: git config --global --add safe.directory '*'

      - name: Checkout repository
        uses: actions/checkout@v7
        with:
          submodules: recursive
          ref: ${{ inputs.ref }}
```

Note the removed `sudo` prefixes: the container runs as root. `timeout-minutes`
rises from 30 to 40 because the container installs its toolchain from scratch
on every run.

- [ ] **Step 2: Push the branch and watch the job**

```bash
git add .github/workflows/build-all.yml
git commit -m "ci: build Linux inside an ubuntu:22.04 container"
git push -u origin feat/linux-packaging
gh run watch "$(gh run list --branch feat/linux-packaging --limit 1 --json databaseId -q '.[0].databaseId')"
```

Expected: `Build Linux` succeeds and uploads `linux-tar`.

- [ ] **Step 3: Verify the glibc floor actually moved**

Download the artifact and read the binary's required glibc versions:

```bash
gh run download "$(gh run list --branch feat/linux-packaging --limit 1 --json databaseId -q '.[0].databaseId')" -n linux-tar -D /tmp/lintar
mkdir -p /tmp/linbundle && tar xzf /tmp/lintar/Submersion-*-Linux.tar.gz -C /tmp/linbundle
docker run --rm -v /tmp/linbundle:/b ubuntu:22.04 bash -c \
  'objdump -T /b/submersion 2>/dev/null | grep -o "GLIBC_[0-9.]*" | sort -Vu | tail -3'
```

Expected: the highest version is `GLIBC_2.35` or lower. A `GLIBC_2.38` or
similar means the container did not take effect.

- [ ] **Step 4: Commit**

Already committed in Step 2. If Step 3 required a fix, commit it now:

```bash
git add .github/workflows/build-all.yml
git commit -m "ci: correct the Linux container build floor"
```

---

### Task 3: Add a `--version` flag to the Linux runner

`linux/runner/main.cc` is the stock six-line Flutter runner. Without this, the
container smoke test in Task 9 cannot assert anything about the installed
binary without standing up a display server.

There is deliberately no unit test for this: the repo's native test harness
(`packages/libdivecomputer_plugin/test/native/`) belongs to the plugin, not the
runner, and standing up a second CMake test target to cover an argv comparison
is not worth it. Task 9's smoke test is this change's test, in a real installed
package, which is a stronger assertion than a unit test would be.

**Files:**
- Modify: `linux/runner/main.cc`

**Interfaces:**
- Produces: `submersion --version` prints `submersion <version>` to stdout and
  exits 0 without initializing GTK. Task 9 asserts on this exact format.

- [ ] **Step 1: Write the implementation**

Replace the whole of `linux/runner/main.cc`:

```cpp
#include <cstdio>
#include <cstring>

#include "my_application.h"

// Kept in sync with pubspec.yaml by the build; see linux/CMakeLists.txt.
#ifndef SUBMERSION_VERSION
#define SUBMERSION_VERSION "unknown"
#endif

int main(int argc, char** argv) {
  // Answered before GTK initializes, so packaging smoke tests can assert the
  // installed version in a container with no display server.
  for (int i = 1; i < argc; i++) {
    if (strcmp(argv[i], "--version") == 0) {
      printf("submersion %s\n", SUBMERSION_VERSION);
      return 0;
    }
  }

  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
```

- [ ] **Step 2: Feed the version in from the build**

Append to `linux/CMakeLists.txt`, immediately after the
`add_dependencies(${BINARY_NAME} flutter_assemble)` line:

```cmake
# Surface the marketing version to the runner's --version flag. FLUTTER_VERSION
# is set by Flutter's generated config from pubspec.yaml.
target_compile_definitions(${BINARY_NAME}
  PRIVATE "SUBMERSION_VERSION=\"${FLUTTER_VERSION}\"")
```

- [ ] **Step 3: Build locally to verify it compiles**

```bash
docker run --rm -v "$PWD":/src -w /src ubuntu:22.04 bash -c '
  apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    clang cmake ninja-build pkg-config libgtk-3-dev > /dev/null
  echo "toolchain ready"
'
```

Expected: `toolchain ready`. The full Flutter build is exercised in CI rather
than locally; the compile itself is verified by the next CI run.

- [ ] **Step 4: Commit**

```bash
git add linux/runner/main.cc linux/CMakeLists.txt
git commit -m "feat(linux): add a --version flag to the runner"
```

---

### Task 4: Generate udev rules from libdivecomputer's device tables

Upstream's
`packages/libdivecomputer_plugin/third_party/libdivecomputer/contrib/udev/libdivecomputer.rules`
is 35 lines covering nine devices, every rule using `GROUP="plugdev"`, a group
Fedora does not create. Generating from the descriptor tables means a submodule
bump widens hardware support automatically.

The tables live in
`packages/libdivecomputer_plugin/third_party/libdivecomputer/src/descriptor.c`
in exactly two shapes (lines 667, 699, 862):

```c
	static const dc_usbhid_desc_t usbhid[] = {
		{0x2e6c, 0x3201}, // G2, G2 TEK
		{0xc251, 0x2006}, // Aladin Square
	};
	static const dc_usb_desc_t usb[] = {
		{0x0471, 0x0888}, // Atomic Aquatics Cobalt
	};
```

**Files:**
- Create: `scripts/gen_udev_rules.py`
- Create: `scripts/gen_udev_rules_test.py`

**Interfaces:**
- Produces: `python3 scripts/gen_udev_rules.py <descriptor.c> > <output.rules>`.
  Task 6 calls it to place the file in the staging tree.

- [ ] **Step 1: Write the failing test**

Create `scripts/gen_udev_rules_test.py`:

```python
#!/usr/bin/env python3
"""Unit tests for gen_udev_rules.py.

Run: python3 scripts/gen_udev_rules_test.py

The regression this guards: libdivecomputer's descriptor tables are C source,
not a data file, so a submodule bump that reshapes them would make a naive
parser emit an empty rules file. An empty file installs cleanly and silently
leaves every USB dive computer unreachable, which is exactly the class of
failure check_bundled_native_assets.py exists to prevent for native libraries.
"""

import importlib.util
import os
import tempfile
import unittest

SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "gen_udev_rules.py")
spec = importlib.util.spec_from_file_location("gen_udev_rules", SCRIPT)
gen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen)

SAMPLE = """
dc_filter_uwatec (const dc_descriptor_t *descriptor)
{
\tstatic const dc_usbhid_desc_t usbhid[] = {
\t\t{0x2e6c, 0x3201}, // G2, G2 TEK
\t\t{0xc251, 0x2006}, // Aladin Square
\t};
}

dc_filter_atomic (const dc_descriptor_t *descriptor)
{
\tstatic const dc_usb_desc_t usb[] = {
\t\t{0x0471, 0x0888}, // Atomic Aquatics Cobalt
\t};
}
"""


class ParseDevicesTest(unittest.TestCase):
    def test_extracts_usbhid_devices_with_comments(self):
        devices = gen.parse_devices(SAMPLE)
        self.assertIn(gen.Device("2e6c", "3201", "G2, G2 TEK", True), devices)
        self.assertIn(gen.Device("c251", "2006", "Aladin Square", True), devices)

    def test_extracts_plain_usb_devices(self):
        devices = gen.parse_devices(SAMPLE)
        self.assertIn(
            gen.Device("0471", "0888", "Atomic Aquatics Cobalt", False), devices
        )

    def test_finds_every_device_in_the_sample(self):
        self.assertEqual(len(gen.parse_devices(SAMPLE)), 3)

    def test_empty_source_raises_rather_than_emitting_nothing(self):
        with self.assertRaises(SystemExit):
            gen.parse_devices("int main(void) { return 0; }")


class RenderTest(unittest.TestCase):
    def test_hidraw_device_gets_hidraw_and_usb_rules(self):
        text = gen.render([gen.Device("2e6c", "3201", "G2, G2 TEK", True)])
        self.assertIn(
            'SUBSYSTEM=="hidraw", ATTRS{idVendor}=="2e6c", '
            'ATTRS{idProduct}=="3201", TAG+="uaccess"',
            text,
        )
        self.assertIn(
            'SUBSYSTEM=="usb", ATTR{idVendor}=="2e6c", '
            'ATTR{idProduct}=="3201", TAG+="uaccess"',
            text,
        )

    def test_plain_usb_device_gets_no_hidraw_rule(self):
        text = gen.render([gen.Device("0471", "0888", "Cobalt", False)])
        self.assertNotIn("hidraw", text)

    def test_never_uses_group_based_access(self):
        text = gen.render([gen.Device("2e6c", "3201", "G2", True)])
        self.assertNotIn("plugdev", text)
        self.assertNotIn("dialout", text)

    def test_includes_serial_bridge_rules(self):
        text = gen.render([gen.Device("2e6c", "3201", "G2", True)])
        # FTDI, Prolific, and Silicon Labs bridges are how the serial dive
        # computers reach /dev/ttyUSB*.
        for vid in ("0403", "067b", "10c4"):
            self.assertIn(
                'SUBSYSTEM=="tty", ATTRS{idVendor}=="%s", TAG+="uaccess"' % vid,
                text,
            )

    def test_device_comment_is_preserved(self):
        text = gen.render([gen.Device("2e6c", "3201", "G2, G2 TEK", True)])
        self.assertIn("# G2, G2 TEK", text)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `python3 scripts/gen_udev_rules_test.py`
Expected: FAIL, `FileNotFoundError` or `ModuleNotFoundError` for
`gen_udev_rules.py`.

- [ ] **Step 3: Write the implementation**

Create `scripts/gen_udev_rules.py`:

```python
#!/usr/bin/env python3
"""Generate udev rules for the dive computers libdivecomputer supports.

Upstream ships contrib/udev/libdivecomputer.rules, but it covers only a handful
of devices and every rule reads GROUP="plugdev", a group Fedora does not create.
This generator reads the VID/PID tables out of descriptor.c instead, so a
submodule bump widens hardware support without anyone editing a list, and emits
TAG+="uaccess" so systemd-logind grants access to the user on the active seat.
uaccess needs no group membership, no usermod, and no log out and back in, and
it behaves identically on Debian and Fedora.

Usage:
    gen_udev_rules.py <path/to/descriptor.c>   > 60-submersion-divecomputers.rules
"""

import collections
import re
import sys

Device = collections.namedtuple("Device", "vid pid comment hid")

# The two table shapes in descriptor.c. dc_usbhid_desc_t devices are opened
# through /dev/hidraw*; dc_usb_desc_t devices through the raw USB node.
_TABLE_RE = re.compile(
    r"static\s+const\s+(dc_usbhid_desc_t|dc_usb_desc_t)\s+\w+\s*\[\]\s*=\s*\{(.*?)\};",
    re.DOTALL,
)
_ENTRY_RE = re.compile(
    r"\{\s*0x([0-9a-fA-F]{4})\s*,\s*0x([0-9a-fA-F]{4})\s*\}\s*,?\s*(?://\s*(.*))?"
)

# USB-to-serial bridges used by the serial dive computers. These are not in
# descriptor.c because libdivecomputer addresses them by tty path, not by ID.
# Vendor-wide by necessity: the bridge chip carries the vendor's ID, and the
# dive computer behind it is invisible to udev.
SERIAL_BRIDGES = (
    ("0403", "FTDI (Oceanic, Aeris, Sherwood, Hollis)"),
    ("067b", "Prolific PL2303 (Mares, Cressi)"),
    ("10c4", "Silicon Labs CP210x (Suunto, Uwatec)"),
)

HEADER = """# Submersion dive computer access rules.
#
# Generated by scripts/gen_udev_rules.py from libdivecomputer's descriptor.c.
# Do not edit by hand; edit the generator or bump the submodule.
#
# TAG+="uaccess" hands access to the user on the active seat via
# systemd-logind. No group membership is required, and access follows the
# seat, so it is revoked on fast user switching.
"""


def parse_devices(source):
    """Extract every VID/PID pair from descriptor.c's device tables."""
    devices = []
    for kind, body in _TABLE_RE.findall(source):
        hid = kind == "dc_usbhid_desc_t"
        for vid, pid, comment in _ENTRY_RE.findall(body):
            devices.append(
                Device(vid.lower(), pid.lower(), (comment or "").strip(), hid)
            )
    if not devices:
        sys.exit(
            "gen_udev_rules: no device tables found. descriptor.c's shape "
            "changed; update _TABLE_RE and _ENTRY_RE rather than shipping an "
            "empty rules file."
        )
    return devices


def render(devices):
    """Render the rules file for the given devices."""
    lines = [HEADER]
    for device in devices:
        if device.comment:
            lines.append("# %s" % device.comment)
        if device.hid:
            lines.append(
                'SUBSYSTEM=="hidraw", ATTRS{idVendor}=="%s", '
                'ATTRS{idProduct}=="%s", TAG+="uaccess"' % (device.vid, device.pid)
            )
        lines.append(
            'SUBSYSTEM=="usb", ATTR{idVendor}=="%s", '
            'ATTR{idProduct}=="%s", TAG+="uaccess"' % (device.vid, device.pid)
        )
        lines.append("")

    lines.append("# USB-to-serial bridges (/dev/ttyUSB*)")
    for vid, comment in SERIAL_BRIDGES:
        lines.append("# %s" % comment)
        lines.append(
            'SUBSYSTEM=="tty", ATTRS{idVendor}=="%s", TAG+="uaccess"' % vid
        )
    lines.append("")
    return "\n".join(lines)


def main(argv):
    if len(argv) != 2:
        sys.exit("usage: gen_udev_rules.py <path/to/descriptor.c>")
    with open(argv[1], "r", encoding="utf-8") as handle:
        source = handle.read()
    sys.stdout.write(render(parse_devices(source)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `python3 scripts/gen_udev_rules_test.py`
Expected: `OK`, 10 tests.

- [ ] **Step 5: Run it against the real descriptor.c**

```bash
python3 scripts/gen_udev_rules.py \
  packages/libdivecomputer_plugin/third_party/libdivecomputer/src/descriptor.c
```

Expected: rules for 9 devices (4 Uwatec/Scubapro hidraw, 4 Suunto hidraw, 1
Atomic Aquatics usb) plus the 3 serial bridge rules. Confirm no `plugdev`
appears anywhere in the output.

- [ ] **Step 6: Commit**

```bash
git add scripts/gen_udev_rules.py scripts/gen_udev_rules_test.py
git commit -m "feat(linux): generate udev rules from libdivecomputer's device tables"
```

---

### Task 5: Derive package dependencies from the built binary

Hand-writing the dependency list would let a CMake fallback ship a package that
declares `webkit2gtk-4.1` while linking `4.0`. Reading `DT_NEEDED` from the
artifact makes that impossible.

The script separates the two concerns so the mapping is testable without an ELF
fixture: `read_needed()` shells out to `readelf`, and `map_sonames()` is pure.

**Files:**
- Create: `scripts/data/linux_soname_map.json`
- Create: `scripts/linux_package_deps.py`
- Create: `scripts/linux_package_deps_test.py`

**Interfaces:**
- Consumes: a bundle directory from Task 2.
- Produces: `python3 scripts/linux_package_deps.py <bundle> --format deb|rpm|json`.
  `deb` and `rpm` print one dependency token per line; `json` prints the full
  mapping. Task 7 consumes `deb` and `rpm`; Task 10 ships the JSON map.

- [ ] **Step 1: Write the soname map**

Create `scripts/data/linux_soname_map.json`:

```json
{
  "_comment": "soname to package name, per package manager. rpm entries are soname provides, which every RPM distro exposes identically: Fedora names the package gtk3 and openSUSE names it libgtk-3-0, but both provide libgtk-3.so.0()(64bit). The pacman and zypper columns are used only by the tarball's install.sh preflight.",
  "libgtk-3.so.0": {"apt": "libgtk-3-0", "rpm": "libgtk-3.so.0()(64bit)", "pacman": "gtk3", "zypper": "gtk3"},
  "libgdk-3.so.0": {"apt": "libgtk-3-0", "rpm": "libgdk-3.so.0()(64bit)", "pacman": "gtk3", "zypper": "gtk3"},
  "libwebkit2gtk-4.1.so.0": {"apt": "libwebkit2gtk-4.1-0", "rpm": "libwebkit2gtk-4.1.so.0()(64bit)", "pacman": "webkit2gtk-4.1", "zypper": "webkit2gtk-4_1"},
  "libjavascriptcoregtk-4.1.so.0": {"apt": "libjavascriptcoregtk-4.1-0", "rpm": "libjavascriptcoregtk-4.1.so.0()(64bit)", "pacman": "webkit2gtk-4.1", "zypper": "webkit2gtk-4_1"},
  "libsoup-3.0.so.0": {"apt": "libsoup-3.0-0", "rpm": "libsoup-3.0.so.0()(64bit)", "pacman": "libsoup3", "zypper": "libsoup-3_0-0"},
  "libsecret-1.so.0": {"apt": "libsecret-1-0", "rpm": "libsecret-1.so.0()(64bit)", "pacman": "libsecret", "zypper": "libsecret-1-0"},
  "libglib-2.0.so.0": {"apt": "libglib2.0-0", "rpm": "libglib-2.0.so.0()(64bit)", "pacman": "glib2", "zypper": "libglib-2_0-0"},
  "libgobject-2.0.so.0": {"apt": "libglib2.0-0", "rpm": "libgobject-2.0.so.0()(64bit)", "pacman": "glib2", "zypper": "libgobject-2_0-0"},
  "libgio-2.0.so.0": {"apt": "libglib2.0-0", "rpm": "libgio-2.0.so.0()(64bit)", "pacman": "glib2", "zypper": "libgio-2_0-0"},
  "libcairo.so.2": {"apt": "libcairo2", "rpm": "libcairo.so.2()(64bit)", "pacman": "cairo", "zypper": "libcairo2"},
  "libpango-1.0.so.0": {"apt": "libpango-1.0-0", "rpm": "libpango-1.0.so.0()(64bit)", "pacman": "pango", "zypper": "libpango-1_0-0"},
  "liblzma.so.5": {"apt": "liblzma5", "rpm": "liblzma.so.5()(64bit)", "pacman": "xz", "zypper": "liblzma5"},
  "libstdc++.so.6": {"apt": "libstdc++6", "rpm": "libstdc++.so.6()(64bit)", "pacman": "gcc-libs", "zypper": "libstdc++6"},
  "libgcc_s.so.1": {"apt": "libgcc-s1", "rpm": "libgcc_s.so.1()(64bit)", "pacman": "gcc-libs", "zypper": "libgcc_s1"},
  "libm.so.6": {"apt": "libc6", "rpm": "libm.so.6()(64bit)", "pacman": "glibc", "zypper": "glibc"},
  "libc.so.6": {"apt": "libc6", "rpm": "libc.so.6()(64bit)", "pacman": "glibc", "zypper": "glibc"},
  "libpthread.so.0": {"apt": "libc6", "rpm": "libpthread.so.0()(64bit)", "pacman": "glibc", "zypper": "glibc"},
  "libdl.so.2": {"apt": "libc6", "rpm": "libdl.so.2()(64bit)", "pacman": "glibc", "zypper": "glibc"}
}
```

- [ ] **Step 2: Write the failing test**

Create `scripts/linux_package_deps_test.py`:

```python
#!/usr/bin/env python3
"""Unit tests for linux_package_deps.py.

Run: python3 scripts/linux_package_deps_test.py

The regression this guards: desktop_webview_window's CMake silently falls back
from webkit2gtk-4.1 to 4.0 when 4.1 is absent at build time, which changes what
the shipped binary needs without failing the build. A hand-written dependency
list would then be wrong in a way nothing detects until a user's package
manager installs the wrong library. Deriving the list from DT_NEEDED and
failing on any unmapped soname makes that impossible to ship.
"""

import importlib.util
import json
import os
import tempfile
import unittest

SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "linux_package_deps.py")
spec = importlib.util.spec_from_file_location("linux_package_deps", SCRIPT)
deps = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deps)

SONAME_MAP = {
    "libgtk-3.so.0": {"apt": "libgtk-3-0", "rpm": "libgtk-3.so.0()(64bit)",
                      "pacman": "gtk3", "zypper": "gtk3"},
    "libc.so.6": {"apt": "libc6", "rpm": "libc.so.6()(64bit)",
                  "pacman": "glibc", "zypper": "glibc"},
    "libglib-2.0.so.0": {"apt": "libglib2.0-0", "rpm": "libglib-2.0.so.0()(64bit)",
                         "pacman": "glib2", "zypper": "libglib-2_0-0"},
}


class MapSonamesTest(unittest.TestCase):
    def test_maps_to_apt_names(self):
        result = deps.map_sonames({"libgtk-3.so.0", "libc.so.6"}, SONAME_MAP, "apt")
        self.assertEqual(result, ["libc6", "libgtk-3-0"])

    def test_maps_to_rpm_soname_provides(self):
        result = deps.map_sonames({"libgtk-3.so.0"}, SONAME_MAP, "rpm")
        self.assertEqual(result, ["libgtk-3.so.0()(64bit)"])

    def test_deduplicates_shared_packages(self):
        # Several glib sonames map to one apt package; the list must not repeat it.
        result = deps.map_sonames(
            {"libglib-2.0.so.0", "libc.so.6"}, SONAME_MAP, "apt"
        )
        self.assertEqual(result, ["libc6", "libglib2.0-0"])

    def test_output_is_sorted_for_reproducibility(self):
        result = deps.map_sonames(
            {"libgtk-3.so.0", "libc.so.6", "libglib-2.0.so.0"}, SONAME_MAP, "apt"
        )
        self.assertEqual(result, sorted(result))

    def test_unmapped_soname_is_a_hard_failure(self):
        with self.assertRaises(SystemExit) as caught:
            deps.map_sonames({"libwebkit2gtk-4.0.so.37"}, SONAME_MAP, "apt")
        self.assertIn("libwebkit2gtk-4.0.so.37", str(caught.exception))


class BundledFilteringTest(unittest.TestCase):
    def test_bundled_libraries_are_not_dependencies(self):
        with tempfile.TemporaryDirectory() as root:
            os.makedirs(os.path.join(root, "lib"))
            for name in ("libsqlcipher.so", "libdivecomputer.so.0"):
                open(os.path.join(root, "lib", name), "w").close()
            bundled = deps.bundled_sonames(root)
        self.assertEqual(bundled, {"libsqlcipher.so", "libdivecomputer.so.0"})

    def test_missing_lib_dir_yields_no_bundled_names(self):
        with tempfile.TemporaryDirectory() as root:
            self.assertEqual(deps.bundled_sonames(root), set())


class LoadMapTest(unittest.TestCase):
    def test_comment_key_is_ignored(self):
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
            json.dump({"_comment": "notes", "libc.so.6": SONAME_MAP["libc.so.6"]}, handle)
            path = handle.name
        try:
            loaded = deps.load_map(path)
            self.assertNotIn("_comment", loaded)
            self.assertIn("libc.so.6", loaded)
        finally:
            os.unlink(path)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `python3 scripts/linux_package_deps_test.py`
Expected: FAIL, module not found.

- [ ] **Step 4: Write the implementation**

Create `scripts/linux_package_deps.py`:

```python
#!/usr/bin/env python3
"""Derive a Linux package's runtime dependencies from a built bundle.

Hand-written dependency lists go stale silently. desktop_webview_window's CMake
falls back from webkit2gtk-4.1 to 4.0 when 4.1 is missing at build time
(desktop_webview_window/linux/CMakeLists.txt), which changes what the binary
needs without failing the build, so a declared list can be wrong in a way
nothing catches until a user's package manager installs the wrong library.

This reads DT_NEEDED out of the built artifacts instead, subtracts the
libraries shipped inside the package, and maps what remains through
scripts/data/linux_soname_map.json. An unmapped soname is a hard failure: the
alternative is a package that installs cleanly and then fails to launch, which
is the same shape as issue #1129 (see check_bundled_native_assets.py).

RPM dependencies are soname provides rather than package names, because Fedora
calls the package gtk3 while openSUSE calls it libgtk-3-0, and both provide
libgtk-3.so.0()(64bit).

Usage:
    linux_package_deps.py <bundle-root> --format {deb,rpm,json}
"""

import argparse
import json
import os
import re
import subprocess
import sys

DEFAULT_MAP = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "data", "linux_soname_map.json"
)

_NEEDED_RE = re.compile(r"\(NEEDED\).*\[(.+?)\]")

_FORMAT_COLUMN = {"deb": "apt", "rpm": "rpm"}


def load_map(path):
    """Load the soname map, dropping documentation keys."""
    with open(path, "r", encoding="utf-8") as handle:
        raw = json.load(handle)
    return {k: v for k, v in raw.items() if not k.startswith("_")}


def bundled_sonames(bundle_root):
    """Names of the shared libraries shipped inside the bundle's lib/."""
    lib_dir = os.path.join(bundle_root, "lib")
    if not os.path.isdir(lib_dir):
        return set()
    return {name for name in os.listdir(lib_dir) if ".so" in name}


def read_needed(path):
    """DT_NEEDED entries of one ELF file, via readelf."""
    try:
        output = subprocess.run(
            ["readelf", "-d", path],
            check=True,
            capture_output=True,
            text=True,
        ).stdout
    except FileNotFoundError:
        sys.exit(
            "linux_package_deps: readelf not found. Install binutils in the "
            "build container."
        )
    except subprocess.CalledProcessError as error:
        sys.exit("linux_package_deps: readelf failed on %s: %s" % (path, error))
    return set(_NEEDED_RE.findall(output))


def collect_sonames(bundle_root):
    """Every DT_NEEDED entry across the bundle, minus what the bundle ships."""
    targets = [os.path.join(bundle_root, "submersion")]
    lib_dir = os.path.join(bundle_root, "lib")
    if os.path.isdir(lib_dir):
        targets.extend(
            os.path.join(lib_dir, name)
            for name in sorted(os.listdir(lib_dir))
            if ".so" in name
        )

    needed = set()
    for target in targets:
        if os.path.isfile(target):
            needed |= read_needed(target)
    return needed - bundled_sonames(bundle_root)


def map_sonames(sonames, soname_map, column):
    """Map sonames to dependency tokens, sorted and deduplicated."""
    unmapped = sorted(name for name in sonames if name not in soname_map)
    if unmapped:
        sys.exit(
            "linux_package_deps: unmapped soname(s): %s\n"
            "Add them to scripts/data/linux_soname_map.json. An unmapped "
            "library means the package would install without declaring "
            "something it needs." % ", ".join(unmapped)
        )
    return sorted({soname_map[name][column] for name in sonames})


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle_root")
    parser.add_argument("--format", choices=("deb", "rpm", "json"), required=True)
    parser.add_argument("--map", default=DEFAULT_MAP)
    args = parser.parse_args(argv)

    soname_map = load_map(args.map)
    sonames = collect_sonames(args.bundle_root)

    if args.format == "json":
        json.dump(
            {name: soname_map[name] for name in map_sonames_keys(sonames, soname_map)},
            sys.stdout,
            indent=2,
            sort_keys=True,
        )
        sys.stdout.write("\n")
        return 0

    for token in map_sonames(sonames, soname_map, _FORMAT_COLUMN[args.format]):
        print(token)
    return 0


def map_sonames_keys(sonames, soname_map):
    """Validated soname list, for the json format."""
    map_sonames(sonames, soname_map, "apt")
    return sorted(sonames)


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `python3 scripts/linux_package_deps_test.py`
Expected: `OK`, 9 tests.

- [ ] **Step 6: Commit**

```bash
git add scripts/linux_package_deps.py scripts/linux_package_deps_test.py scripts/data/linux_soname_map.json
git commit -m "feat(linux): derive package dependencies from DT_NEEDED"
```

---

### Task 6: Stage the canonical install tree

One tree, two package formats, so the `.deb` and `.rpm` are provably the same
binary.

**Files:**
- Create: `scripts/release/stage_linux_package.py`
- Create: `scripts/release/stage_linux_package_test.py`

**Interfaces:**
- Consumes: `gen_udev_rules.py` from Task 4.
- Produces:
  `python3 scripts/release/stage_linux_package.py <bundle> <staging-dir> --version <v> --install-method <deb|rpm>`
  creates the tree Task 7 hands to fpm.

- [ ] **Step 1: Write the failing test**

Create `scripts/release/stage_linux_package_test.py`:

```python
#!/usr/bin/env python3
"""Unit tests for stage_linux_package.py.

Run: python3 scripts/release/stage_linux_package_test.py

The tree this builds is the only thing standing between a working install and
a 40 MB archive of loose files: it is where the .desktop entry, the icons, the
AppStream metadata, the udev rules, and the install-method marker come from.
Every assertion here is something a user would otherwise discover as a missing
menu entry or an unreachable dive computer.
"""

import importlib.util
import os
import tempfile
import unittest

SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "stage_linux_package.py")
spec = importlib.util.spec_from_file_location("stage_linux_package", SCRIPT)
stage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stage)


def make_bundle(root):
    """A minimal stand-in for build/linux/x64/release/bundle."""
    os.makedirs(os.path.join(root, "lib"))
    os.makedirs(os.path.join(root, "data", "flutter_assets"))
    with open(os.path.join(root, "submersion"), "w") as handle:
        handle.write("binary")
    with open(os.path.join(root, "lib", "libsqlcipher.so"), "w") as handle:
        handle.write("lib")
    return root


class TreeLayoutTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.bundle = make_bundle(os.path.join(self._tmp.name, "bundle"))
        self.staging = os.path.join(self._tmp.name, "staging")
        stage.build_tree(
            self.bundle, self.staging, version="1.7.7.7180", install_method="deb"
        )

    def tearDown(self):
        self._tmp.cleanup()

    def _path(self, *parts):
        return os.path.join(self.staging, *parts)

    def test_bundle_is_copied_verbatim(self):
        self.assertTrue(os.path.isfile(self._path("usr/lib/submersion/submersion")))
        self.assertTrue(
            os.path.isfile(self._path("usr/lib/submersion/lib/libsqlcipher.so"))
        )

    def test_bundle_relative_layout_is_preserved_for_the_rpath(self):
        # The runner finds its native assets through $ORIGIN/lib
        # (linux/CMakeLists.txt:17); flattening the tree would break every
        # bundled library at launch.
        binary = self._path("usr/lib/submersion/submersion")
        sibling_lib = self._path("usr/lib/submersion/lib")
        self.assertEqual(os.path.dirname(binary), os.path.dirname(sibling_lib))

    def test_wrapper_is_executable_and_execs_the_real_binary(self):
        wrapper = self._path("usr/bin/submersion")
        self.assertTrue(os.access(wrapper, os.X_OK))
        with open(wrapper) as handle:
            self.assertIn('exec /usr/lib/submersion/submersion "$@"', handle.read())

    def test_desktop_file_binds_the_window_to_its_icon(self):
        with open(self._path("usr/share/applications/app.submersion.desktop")) as h:
            text = h.read()
        self.assertIn("StartupWMClass=submersion", text)
        self.assertIn("Exec=submersion %U", text)
        self.assertIn("Icon=app.submersion", text)
        self.assertIn("Categories=Science;Education;Utility;", text)

    def test_icons_are_installed_at_every_hicolor_size(self):
        for size in (16, 32, 48, 64, 128, 256, 512):
            self.assertTrue(
                os.path.isfile(
                    self._path(
                        "usr/share/icons/hicolor/%dx%d/apps/app.submersion.png"
                        % (size, size)
                    )
                ),
                "missing %dx%d icon" % (size, size),
            )

    def test_appstream_metadata_carries_id_name_and_version(self):
        with open(self._path("usr/share/metainfo/app.submersion.metainfo.xml")) as h:
            text = h.read()
        self.assertIn("<id>app.submersion</id>", text)
        self.assertIn("<name>Submersion</name>", text)
        self.assertIn('version="1.7.7.7180"', text)

    def test_udev_rules_are_installed_and_use_uaccess(self):
        path = self._path("usr/lib/udev/rules.d/60-submersion-divecomputers.rules")
        self.assertTrue(os.path.isfile(path))
        with open(path) as handle:
            text = handle.read()
        self.assertIn('TAG+="uaccess"', text)
        self.assertNotIn("plugdev", text)

    def test_install_method_marker_records_the_format(self):
        with open(self._path("usr/lib/submersion/INSTALL_METHOD")) as handle:
            self.assertEqual(handle.read().strip(), "deb")


class InstallMethodTest(unittest.TestCase):
    def test_rpm_marker_says_rpm(self):
        with tempfile.TemporaryDirectory() as tmp:
            bundle = make_bundle(os.path.join(tmp, "bundle"))
            staging = os.path.join(tmp, "staging")
            stage.build_tree(bundle, staging, version="1.0.0.1", install_method="rpm")
            with open(os.path.join(staging, "usr/lib/submersion/INSTALL_METHOD")) as h:
                self.assertEqual(h.read().strip(), "rpm")

    def test_unknown_install_method_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            bundle = make_bundle(os.path.join(tmp, "bundle"))
            with self.assertRaises(SystemExit):
                stage.build_tree(
                    bundle, os.path.join(tmp, "s"), version="1.0.0.1",
                    install_method="snap",
                )


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `python3 scripts/release/stage_linux_package_test.py`
Expected: FAIL, module not found.

- [ ] **Step 3: Write the implementation**

Create `scripts/release/stage_linux_package.py`. Icon downscaling uses Pillow,
which `scripts/requirements.txt` already provides for `generate_icon.py`; when
Pillow is absent the script copies the master icon to every size rather than
failing, so the tree is always complete.

```python
#!/usr/bin/env python3
"""Build the canonical Linux install tree from a Flutter bundle.

Both the .deb and the .rpm are emitted from this one tree, so the two packages
are provably the same binary rather than two builds that happen to agree.

The bundle is copied verbatim into /usr/lib/submersion because the runner
resolves its native assets through an $ORIGIN/lib rpath (linux/CMakeLists.txt);
preserving the relative layout is what lets the packaged copy launch at all.

Usage:
    stage_linux_package.py <bundle-root> <staging-dir> \\
        --version 1.7.7.7180 --install-method deb
"""

import argparse
import os
import shutil
import subprocess
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MASTER_ICON = os.path.join(REPO_ROOT, "assets", "icon", "icon.png")
DESCRIPTOR_C = os.path.join(
    REPO_ROOT, "packages", "libdivecomputer_plugin", "third_party",
    "libdivecomputer", "src", "descriptor.c",
)
GEN_UDEV = os.path.join(REPO_ROOT, "scripts", "gen_udev_rules.py")

ICON_SIZES = (16, 32, 48, 64, 128, 256, 512)
INSTALL_METHODS = ("deb", "rpm")

DESKTOP_ENTRY = """[Desktop Entry]
Type=Application
Name=Submersion
GenericName=Dive Log
Comment=An open-source dive logging application for scuba divers.
Exec=submersion %U
Icon=app.submersion
Terminal=false
Categories=Science;Education;Utility;
Keywords=dive;diving;scuba;divelog;logbook;
StartupWMClass=submersion
"""

WRAPPER = """#!/bin/sh
# Submersion launcher. The real binary lives beside its data/ and lib/
# directories because it resolves native assets through an $ORIGIN/lib rpath.
exec /usr/lib/submersion/submersion "$@"
"""

METAINFO = """<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
  <id>app.submersion</id>
  <name>Submersion</name>
  <summary>Dive logging for scuba divers</summary>
  <metadata_license>CC0-1.0</metadata_license>
  <project_license>GPL-3.0</project_license>
  <description>
    <p>
      Submersion is an open-source dive logging application. It downloads dives
      from dive computers, tracks gear and dive sites, and shows decompression
      and gas analytics.
    </p>
  </description>
  <launchable type="desktop-id">app.submersion.desktop</launchable>
  <url type="homepage">https://submersion.app</url>
  <url type="bugtracker">https://github.com/submersion-app/submersion/issues</url>
  <releases>
    <release version="{version}" date="{date}"/>
  </releases>
</component>
"""


def _write(path, text, mode=0o644):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text)
    os.chmod(path, mode)


def _stage_icons(staging):
    try:
        from PIL import Image
    except ImportError:
        Image = None

    for size in ICON_SIZES:
        target = os.path.join(
            staging, "usr/share/icons/hicolor/%dx%d/apps/app.submersion.png"
            % (size, size)
        )
        os.makedirs(os.path.dirname(target), exist_ok=True)
        if Image is None:
            shutil.copyfile(MASTER_ICON, target)
            continue
        with Image.open(MASTER_ICON) as image:
            image.convert("RGBA").resize((size, size), Image.LANCZOS).save(target)


def _stage_udev_rules(staging):
    target = os.path.join(
        staging, "usr/lib/udev/rules.d/60-submersion-divecomputers.rules"
    )
    os.makedirs(os.path.dirname(target), exist_ok=True)
    rules = subprocess.run(
        [sys.executable, GEN_UDEV, DESCRIPTOR_C],
        check=True, capture_output=True, text=True,
    ).stdout
    _write(target, rules)


def build_tree(bundle_root, staging, version, install_method, date="2026-09-03"):
    """Create the full install tree under `staging`."""
    if install_method not in INSTALL_METHODS:
        sys.exit(
            "stage_linux_package: unknown install method %r (expected one of %s)"
            % (install_method, ", ".join(INSTALL_METHODS))
        )

    app_dir = os.path.join(staging, "usr/lib/submersion")
    if os.path.exists(staging):
        shutil.rmtree(staging)
    shutil.copytree(bundle_root, app_dir)

    _write(os.path.join(staging, "usr/bin/submersion"), WRAPPER, mode=0o755)
    _write(
        os.path.join(staging, "usr/share/applications/app.submersion.desktop"),
        DESKTOP_ENTRY,
    )
    _write(
        os.path.join(staging, "usr/share/metainfo/app.submersion.metainfo.xml"),
        METAINFO.format(version=version, date=date),
    )
    _write(os.path.join(app_dir, "INSTALL_METHOD"), install_method + "\n")
    _stage_icons(staging)
    _stage_udev_rules(staging)
    return staging


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle_root")
    parser.add_argument("staging")
    parser.add_argument("--version", required=True)
    parser.add_argument("--install-method", required=True, choices=INSTALL_METHODS)
    args = parser.parse_args(argv)
    build_tree(args.bundle_root, args.staging, args.version, args.install_method)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `python3 scripts/release/stage_linux_package_test.py`
Expected: `OK`, 10 tests.

- [ ] **Step 5: Commit**

```bash
git add scripts/release/stage_linux_package.py scripts/release/stage_linux_package_test.py
git commit -m "feat(linux): stage the canonical package install tree"
```

---

### Task 7: Emit the .deb and .rpm in CI

**Files:**
- Modify: `.github/workflows/build-all.yml` (after the existing
  `Check bundled native assets` step)

**Interfaces:**
- Consumes: Tasks 4, 5, and 6.
- Produces: artifact `linux-packages` containing the tarball, the `.deb`, and
  the `.rpm`.

- [ ] **Step 1: Add the packaging steps**

Insert after the `Check bundled native assets` step and before `Create tarball`:

```yaml
      - name: Install packaging tools
        run: |
          DEBIAN_FRONTEND=noninteractive apt-get install -y \
            ruby ruby-dev build-essential binutils rpm python3-pil
          gem install --no-document fpm

      - name: Stage package trees
        env:
          TAG_NAME: ${{ inputs.version-tag }}
        run: |
          set -euo pipefail
          VERSION="${TAG_NAME#v}"
          echo "PKG_VERSION=$VERSION" >> "$GITHUB_ENV"
          for method in deb rpm; do
            python3 scripts/release/stage_linux_package.py \
              build/linux/x64/release/bundle \
              "staging-$method" \
              --version "$VERSION" \
              --install-method "$method"
          done

      - name: Derive runtime dependencies
        run: |
          set -euo pipefail
          python3 scripts/linux_package_deps.py \
            build/linux/x64/release/bundle --format deb > deps-deb.txt
          python3 scripts/linux_package_deps.py \
            build/linux/x64/release/bundle --format rpm > deps-rpm.txt
          echo "--- deb dependencies ---"; cat deps-deb.txt
          echo "--- rpm dependencies ---"; cat deps-rpm.txt

      - name: Build .deb and .rpm
        env:
          TAG_NAME: ${{ inputs.version-tag }}
        run: |
          set -euo pipefail
          common_args=(
            --name submersion
            --version "$PKG_VERSION"
            --license GPL-3.0
            --maintainer "Submersion <dev@submersion.app>"
            --url "https://submersion.app"
            --description "An open-source dive logging application for scuba divers."
            --input-type dir
          )

          # ffmpeg and gnome-keyring are weak dependencies on purpose. ffmpeg
          # is absent from stock Fedora (it lives in RPM Fusion), so a hard
          # requirement would make the package uninstallable there, and the app
          # already degrades gracefully without it. gnome-keyring supplies the
          # Secret Service that flutter_secure_storage_linux needs, which is
          # present on GNOME and KDE but not on minimal window managers.
          deb_depends=()
          while read -r dep; do deb_depends+=(--depends "$dep"); done < deps-deb.txt
          fpm "${common_args[@]}" \
            --output-type deb \
            --architecture amd64 \
            "${deb_depends[@]}" \
            --deb-recommends ffmpeg \
            --deb-recommends gnome-keyring \
            --package "Submersion-${TAG_NAME}-Linux-amd64.deb" \
            -C staging-deb usr

          rpm_depends=()
          while read -r dep; do rpm_depends+=(--depends "$dep"); done < deps-rpm.txt
          fpm "${common_args[@]}" \
            --output-type rpm \
            --architecture x86_64 \
            "${rpm_depends[@]}" \
            --rpm-tag "Recommends: ffmpeg" \
            --rpm-tag "Recommends: gnome-keyring" \
            --package "Submersion-${TAG_NAME}-Linux-x86_64.rpm" \
            -C staging-rpm usr
```

- [ ] **Step 2: Widen the upload to carry all three artifacts**

Replace the `Upload Linux artifact` step:

```yaml
      - name: Upload Linux artifacts
        uses: actions/upload-artifact@v7
        with:
          name: linux-packages
          path: |
            Submersion-*.tar.gz
            Submersion-*.deb
            Submersion-*.rpm
          retention-days: 5
```

- [ ] **Step 3: Push and verify the packages build**

```bash
git add .github/workflows/build-all.yml
git commit -m "ci(linux): emit .deb and .rpm packages"
git push
gh run watch "$(gh run list --branch feat/linux-packaging --limit 1 --json databaseId -q '.[0].databaseId')"
```

Expected: the run succeeds, the `Derive runtime dependencies` step logs a
dependency list that includes `libgtk-3-0` and `libwebkit2gtk-4.1-0`, and the
`linux-packages` artifact holds three files.

- [ ] **Step 4: Inspect the built .deb locally**

```bash
gh run download "$(gh run list --branch feat/linux-packaging --limit 1 --json databaseId -q '.[0].databaseId')" -n linux-packages -D /tmp/linpkg
docker run --rm -v /tmp/linpkg:/p debian:12 bash -c 'dpkg -I /p/Submersion-*.deb'
```

Expected: the control block lists `Depends:` with the derived libraries,
`Recommends: ffmpeg, gnome-keyring`, and version without a leading `v`.

- [ ] **Step 5: Commit any fixes**

```bash
git add .github/workflows/build-all.yml
git commit -m "ci(linux): correct package metadata"
```

---

### Task 8: Wire the new assets through the release workflows

Without this, a packaging failure produces a release that is missing packages
and nothing notices.

**Files:**
- Modify: `.github/workflows/release.yml:434`

**Interfaces:**
- Consumes: the artifact names from Task 7.

- [ ] **Step 1: Add the packages to the expected-asset list**

In `.github/workflows/release.yml`, extend the `EXPECTED` array:

```bash
          EXPECTED=(
            "Submersion-${TAG_NAME}-macOS.dmg"
            "Submersion-${TAG_NAME}-Windows-Setup.exe"
            "Submersion-${TAG_NAME}-Linux.tar.gz"
            "Submersion-${TAG_NAME}-Linux-amd64.deb"
            "Submersion-${TAG_NAME}-Linux-x86_64.rpm"
            "Submersion-${TAG_NAME}-Android.apk"
            "Submersion-${TAG_NAME}-Android.aab"
            "checksums-sha256.txt"
          )
```

- [ ] **Step 2: Confirm the checksum globs already cover the new files**

The `Submersion-*` globs at `release.yml:335` and `release.yml:388`, the
`softprops/action-gh-release` `files:` glob at `release.yml:404`, and
`beta.yml:230`'s `Submersion*` all match the new capital-S asset names. Verify
by inspection, then confirm with:

```bash
grep -n "Submersion-\*\|Submersion\*" .github/workflows/release.yml .github/workflows/beta.yml
```

Expected: every match is a glob, not an explicit per-file list. No changes
needed. If any explicit list appears, add both new files to it.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "ci: require the Linux packages in release validation"
```

---

### Task 9: Smoke-test the packages in clean containers

An unsatisfiable dependency must be a test failure, not a user's bug report.

**Files:**
- Modify: `.github/workflows/build-all.yml` (new job)

**Interfaces:**
- Consumes: the `linux-packages` artifact from Task 7 and the `--version` flag
  from Task 3.

- [ ] **Step 1: Add the job**

Append to `.github/workflows/build-all.yml`, after `build-linux`:

```yaml
  # ============================================================================
  # Verify Linux Packages
  # ============================================================================
  verify-linux-packages:
    name: Verify Linux Packages
    needs: build-linux
    runs-on: ubuntu-latest
    timeout-minutes: 20
    strategy:
      fail-fast: false
      matrix:
        include:
          - image: debian:12
            format: deb
          - image: fedora:latest
            format: rpm

    steps:
      - name: Download Linux packages
        uses: actions/download-artifact@v8
        with:
          name: linux-packages
          path: packages

      # Installing through the real package manager is the point: it proves
      # every declared dependency is resolvable on a stock system, which is
      # exactly what the tar.gz could never demonstrate.
      - name: Install and run in a clean ${{ matrix.image }}
        run: |
          set -euo pipefail
          docker run --rm -v "$PWD/packages:/p" ${{ matrix.image }} bash -c '
            set -eux
            if command -v apt-get > /dev/null; then
              apt-get update -qq
              DEBIAN_FRONTEND=noninteractive apt-get install -y /p/Submersion-*.deb
            else
              dnf install -y /p/Submersion-*.rpm
            fi

            # The binary answers --version before GTK initializes, so this
            # needs no display server.
            /usr/bin/submersion --version

            test -f /usr/share/applications/app.submersion.desktop
            test -f /usr/share/metainfo/app.submersion.metainfo.xml
            test -f /usr/lib/udev/rules.d/60-submersion-divecomputers.rules
            test -f /usr/share/icons/hicolor/256x256/apps/app.submersion.png

            # A GROUP-based rule would silently fail on Fedora, which has no
            # plugdev group.
            grep -q "uaccess" /usr/lib/udev/rules.d/60-submersion-divecomputers.rules
            ! grep -q "plugdev" /usr/lib/udev/rules.d/60-submersion-divecomputers.rules

            # No unresolved shared libraries after a real dependency install.
            ldd /usr/lib/submersion/submersion | grep "not found" && exit 1
            echo "package verified"
          '
```

- [ ] **Step 2: Push and verify both matrix legs pass**

```bash
git add .github/workflows/build-all.yml
git commit -m "ci(linux): smoke-test packages in clean debian and fedora containers"
git push
gh run watch "$(gh run list --branch feat/linux-packaging --limit 1 --json databaseId -q '.[0].databaseId')"
```

Expected: both legs print `package verified`. A failure in the `ldd` check
means the soname map is missing an entry; add it to
`scripts/data/linux_soname_map.json` and re-run.

- [ ] **Step 3: Commit any soname map additions**

```bash
git add scripts/data/linux_soname_map.json
git commit -m "fix(linux): map sonames surfaced by the container smoke test"
```

---

### Task 10: Give the tarball an installer and a dependency preflight

The tarball stays the path for Arch, NixOS, and anyone who will not use a
package manager. Today it turns a missing library into a loader error; this
turns it into the exact command to fix it.

**Files:**
- Create: `scripts/release/linux_tarball_extras/install.sh`
- Create: `scripts/release/linux_tarball_extras/uninstall.sh`
- Create: `scripts/release/install_sh_test.sh`
- Modify: `.github/workflows/build-all.yml` (`Create tarball` step)

**Interfaces:**
- Consumes: `scripts/data/linux_soname_map.json` from Task 5, shipped in the
  tarball root as `deps.json`.

- [ ] **Step 1: Write the failing test**

Create `scripts/release/install_sh_test.sh`:

```bash
#!/usr/bin/env bash
# Tests for the tarball installer's pure functions.
#
# Run: bash scripts/release/install_sh_test.sh
#
# The installer's job is to turn "error while loading shared libraries:
# libwebkit2gtk-4.1.so.0" into "sudo apt install libwebkit2gtk-4.1-0". These
# tests cover the mapping and the package-manager detection, which is where
# that translation lives.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="$SCRIPT_DIR/linux_tarball_extras/install.sh"
FAILURES=0

assert_eq() {
  if [ "$1" != "$2" ]; then
    echo "FAIL: $3"
    echo "  expected: $2"
    echo "  actual:   $1"
    FAILURES=$((FAILURES + 1))
  else
    echo "ok: $3"
  fi
}

# Source the installer with SUBMERSION_INSTALL_SH_TEST set, which makes it
# define its functions and return instead of running.
SUBMERSION_INSTALL_SH_TEST=1
export SUBMERSION_INSTALL_SH_TEST
# shellcheck source=/dev/null
. "$INSTALLER"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
cat > "$WORKDIR/deps.json" <<'JSON'
{
  "_comment": "test fixture",
  "libgtk-3.so.0": {"apt": "libgtk-3-0", "rpm": "libgtk-3.so.0()(64bit)", "pacman": "gtk3", "zypper": "gtk3"},
  "libwebkit2gtk-4.1.so.0": {"apt": "libwebkit2gtk-4.1-0", "rpm": "x", "pacman": "webkit2gtk-4.1", "zypper": "webkit2gtk-4_1"}
}
JSON

assert_eq "$(map_soname "$WORKDIR/deps.json" "libgtk-3.so.0" apt)" \
  "libgtk-3-0" "maps a soname to its apt package"

assert_eq "$(map_soname "$WORKDIR/deps.json" "libgtk-3.so.0" pacman)" \
  "gtk3" "maps a soname to its pacman package"

assert_eq "$(map_soname "$WORKDIR/deps.json" "libunknown.so.9" apt)" \
  "" "returns empty for an unmapped soname rather than guessing"

assert_eq "$(install_command_for apt "libgtk-3-0 libwebkit2gtk-4.1-0")" \
  "sudo apt install libgtk-3-0 libwebkit2gtk-4.1-0" "builds the apt command"

assert_eq "$(install_command_for dnf "gtk3")" \
  "sudo dnf install gtk3" "builds the dnf command"

assert_eq "$(install_command_for pacman "gtk3")" \
  "sudo pacman -S --needed gtk3" "builds the pacman command"

assert_eq "$(install_command_for zypper "gtk3")" \
  "sudo zypper install gtk3" "builds the zypper command"

if [ "$FAILURES" -gt 0 ]; then
  echo "$FAILURES test(s) failed"
  exit 1
fi
echo "all tests passed"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash scripts/release/install_sh_test.sh`
Expected: FAIL, `No such file or directory` for `install.sh`.

- [ ] **Step 3: Write the installer**

Create `scripts/release/linux_tarball_extras/install.sh`:

```bash
#!/usr/bin/env bash
# Install Submersion from the tarball into the current user's home.
#
# The .deb and .rpm packages are the better path on Debian, Ubuntu, Mint,
# Fedora, RHEL, and openSUSE. This exists for everything else, and for anyone
# who prefers not to install system packages.
#
# Usage: ./install.sh [--prefix DIR] [--no-udev]
set -euo pipefail

PREFIX="${HOME}/.local"
APP_DIR="${PREFIX}/opt/submersion"
INSTALL_UDEV=1
UDEV_RULES="/usr/lib/udev/rules.d/60-submersion-divecomputers.rules"

map_soname() {
  # map_soname <deps.json> <soname> <column> -> package name, or empty
  python3 - "$1" "$2" "$3" <<'PY'
import json, sys
path, soname, column = sys.argv[1:4]
with open(path, encoding="utf-8") as handle:
    data = json.load(handle)
entry = data.get(soname)
print(entry[column] if entry else "")
PY
}

install_command_for() {
  # install_command_for <manager> <packages> -> the command to run
  case "$1" in
    apt) echo "sudo apt install $2" ;;
    dnf) echo "sudo dnf install $2" ;;
    pacman) echo "sudo pacman -S --needed $2" ;;
    zypper) echo "sudo zypper install $2" ;;
    *) echo "" ;;
  esac
}

detect_manager() {
  for manager in apt dnf pacman zypper; do
    if command -v "$manager" > /dev/null 2>&1; then
      echo "$manager"
      return
    fi
  done
  echo ""
}

preflight() {
  local here="$1"
  local manager missing packages command
  manager="$(detect_manager)"
  missing="$(ldd "$here/submersion" "$here"/lib/*.so 2>/dev/null \
    | awk '/not found/ {print $1}' | sort -u)"

  if [ -z "$missing" ]; then
    echo "All shared libraries resolve."
    return 0
  fi

  echo "Missing shared libraries:"
  packages=""
  for soname in $missing; do
    echo "  $soname"
    if [ -n "$manager" ]; then
      local package
      package="$(map_soname "$here/deps.json" "$soname" \
        "$([ "$manager" = "dnf" ] && echo rpm || echo "$manager")")"
      [ -n "$package" ] && packages="$packages $package"
    fi
  done

  if [ -n "$packages" ]; then
    command="$(install_command_for "$manager" "${packages# }")"
    echo ""
    echo "Install them with:"
    echo "  $command"
  fi
  return 1
}

main() {
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  while [ $# -gt 0 ]; do
    case "$1" in
      --prefix) PREFIX="$2"; APP_DIR="${PREFIX}/opt/submersion"; shift 2 ;;
      --no-udev) INSTALL_UDEV=0; shift ;;
      *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
  done

  preflight "$here" || echo "Continuing; the app may not launch until these are installed."

  mkdir -p "$APP_DIR" "${PREFIX}/bin" \
    "${PREFIX}/share/applications" "${PREFIX}/share/icons/hicolor/256x256/apps"
  cp -a "$here/." "$APP_DIR/"
  rm -f "$APP_DIR/install.sh" "$APP_DIR/uninstall.sh"

  ln -sf "$APP_DIR/submersion" "${PREFIX}/bin/submersion"

  cat > "${PREFIX}/share/applications/app.submersion.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Submersion
GenericName=Dive Log
Comment=An open-source dive logging application for scuba divers.
Exec=${PREFIX}/bin/submersion %U
Icon=app.submersion
Terminal=false
Categories=Science;Education;Utility;
Keywords=dive;diving;scuba;divelog;logbook;
StartupWMClass=submersion
DESKTOP

  if [ -f "$APP_DIR/data/flutter_assets/assets/icon/icon.png" ]; then
    cp "$APP_DIR/data/flutter_assets/assets/icon/icon.png" \
      "${PREFIX}/share/icons/hicolor/256x256/apps/app.submersion.png"
  fi

  if [ "$INSTALL_UDEV" = "1" ] && [ -f "$here/60-submersion-divecomputers.rules" ]; then
    echo ""
    echo "Dive computers connected by USB need a udev rule to be reachable."
    echo "Install it with:"
    echo "  sudo cp $APP_DIR/60-submersion-divecomputers.rules $UDEV_RULES"
    echo "  sudo udevadm control --reload-rules && sudo udevadm trigger"
  fi

  echo ""
  echo "Installed to $APP_DIR"
  echo "Run it with: ${PREFIX}/bin/submersion"
  echo "Make sure ${PREFIX}/bin is on your PATH."
}

# Sourced by install_sh_test.sh to test the pure functions in isolation.
if [ -z "${SUBMERSION_INSTALL_SH_TEST:-}" ]; then
  main "$@"
fi
```

- [ ] **Step 4: Write the uninstaller**

Create `scripts/release/linux_tarball_extras/uninstall.sh`:

```bash
#!/usr/bin/env bash
# Remove a tarball installation of Submersion.
#
# Usage: ./uninstall.sh [--prefix DIR]
#
# Dive log data lives outside the install tree and is never touched here.
set -euo pipefail

PREFIX="${HOME}/.local"

while [ $# -gt 0 ]; do
  case "$1" in
    --prefix) PREFIX="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

rm -rf "${PREFIX}/opt/submersion"
rm -f "${PREFIX}/bin/submersion"
rm -f "${PREFIX}/share/applications/app.submersion.desktop"
rm -f "${PREFIX}/share/icons/hicolor/256x256/apps/app.submersion.png"

echo "Removed Submersion from ${PREFIX}."
echo "Your dive log data was not touched."
echo ""
echo "If you installed the udev rules, remove them with:"
echo "  sudo rm -f /usr/lib/udev/rules.d/60-submersion-divecomputers.rules"
echo "  sudo udevadm control --reload-rules"
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash scripts/release/install_sh_test.sh`
Expected: `all tests passed`, 7 assertions.

- [ ] **Step 6: Lint both scripts**

Run: `shellcheck scripts/release/linux_tarball_extras/*.sh scripts/release/install_sh_test.sh`
Expected: no errors. Warnings about sourcing a dynamic path are acceptable and
already suppressed with a `# shellcheck source=/dev/null` directive.

- [ ] **Step 7: Ship the extras inside the tarball**

Replace the `Create tarball` step in `.github/workflows/build-all.yml`:

```yaml
      - name: Create tarball
        env:
          TAG_NAME: ${{ inputs.version-tag }}
        run: |
          set -euo pipefail
          BUNDLE=build/linux/x64/release/bundle
          cp scripts/release/linux_tarball_extras/install.sh "$BUNDLE/"
          cp scripts/release/linux_tarball_extras/uninstall.sh "$BUNDLE/"
          chmod +x "$BUNDLE/install.sh" "$BUNDLE/uninstall.sh"
          cp scripts/data/linux_soname_map.json "$BUNDLE/deps.json"
          python3 scripts/gen_udev_rules.py \
            packages/libdivecomputer_plugin/third_party/libdivecomputer/src/descriptor.c \
            > "$BUNDLE/60-submersion-divecomputers.rules"
          cd "$BUNDLE"
          tar czf "$GITHUB_WORKSPACE/Submersion-${TAG_NAME}-Linux.tar.gz" .
```

Note this step now runs **after** the staging steps, so the extras never reach
the `.deb` or `.rpm` trees. Confirm the ordering when editing.

- [ ] **Step 8: Commit**

```bash
git add scripts/release/linux_tarball_extras scripts/release/install_sh_test.sh .github/workflows/build-all.yml
git commit -m "feat(linux): give the tarball an installer with a dependency preflight"
```

---

### Task 11: Teach the in-app updater about packaged installs

`update_providers.dart:43` points Linux at `Linux.tar.gz` and
`update_banner.dart:49` opens it in a browser. On a dpkg-managed install that
hands the user a tarball which would shadow the packaged copy.

**Files:**
- Create: `lib/features/auto_update/domain/entities/linux_install_method.dart`
- Create: `lib/features/auto_update/data/services/linux_install_method_reader.dart`
- Create: `test/features/auto_update/data/linux_install_method_reader_test.dart`
- Create: `lib/features/auto_update/presentation/widgets/update_banner_actions.dart`
- Create: `test/features/auto_update/presentation/update_banner_actions_test.dart`
- Modify: `lib/features/auto_update/presentation/providers/update_providers.dart`
- Modify: `lib/features/auto_update/presentation/widgets/update_banner.dart:47-52`
- Modify: `lib/l10n/arb/app_*.arb` (11 files)

**Interfaces:**
- Consumes: the `INSTALL_METHOD` marker written by Task 6.
- Produces: `linuxInstallMethodProvider` returning `LinuxInstallMethod`.

- [ ] **Step 1: Write the failing test**

Create `test/features/auto_update/data/linux_install_method_reader_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/auto_update/data/services/linux_install_method_reader.dart';
import 'package:submersion/features/auto_update/domain/entities/linux_install_method.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('install_method_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('reads deb from the marker beside the executable', () async {
    File('${tempDir.path}/INSTALL_METHOD').writeAsStringSync('deb\n');
    final reader = LinuxInstallMethodReader(
      executablePath: '${tempDir.path}/submersion',
    );
    expect(reader.read(), LinuxInstallMethod.deb);
  });

  test('reads rpm from the marker', () async {
    File('${tempDir.path}/INSTALL_METHOD').writeAsStringSync('rpm\n');
    final reader = LinuxInstallMethodReader(
      executablePath: '${tempDir.path}/submersion',
    );
    expect(reader.read(), LinuxInstallMethod.rpm);
  });

  test('falls back to tarball when the marker is absent', () {
    final reader = LinuxInstallMethodReader(
      executablePath: '${tempDir.path}/submersion',
    );
    expect(reader.read(), LinuxInstallMethod.tarball);
  });

  test('falls back to tarball when the marker holds something unknown', () {
    File('${tempDir.path}/INSTALL_METHOD').writeAsStringSync('snap\n');
    final reader = LinuxInstallMethodReader(
      executablePath: '${tempDir.path}/submersion',
    );
    expect(reader.read(), LinuxInstallMethod.tarball);
  });

  test('tolerates surrounding whitespace in the marker', () {
    File('${tempDir.path}/INSTALL_METHOD').writeAsStringSync('  deb  \n\n');
    final reader = LinuxInstallMethodReader(
      executablePath: '${tempDir.path}/submersion',
    );
    expect(reader.read(), LinuxInstallMethod.deb);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/auto_update/data/linux_install_method_reader_test.dart`
Expected: FAIL, `Target of URI doesn't exist`.

- [ ] **Step 3: Write the entity**

Create `lib/features/auto_update/domain/entities/linux_install_method.dart`:

```dart
/// How this Linux copy of Submersion was installed.
///
/// A packaged install is upgraded by the system package manager, so the
/// in-app updater must not offer a tarball that would shadow the packaged
/// copy. The marker file is written into the package by
/// scripts/release/stage_linux_package.py.
enum LinuxInstallMethod {
  /// Installed from a .deb; upgraded with apt.
  deb,

  /// Installed from an .rpm; upgraded with dnf.
  rpm,

  /// Unpacked from the tarball; upgraded by downloading a new tarball.
  tarball;

  /// Whether a system package manager owns this install.
  bool get isPackaged => this != LinuxInstallMethod.tarball;
}
```

- [ ] **Step 4: Write the reader**

Create `lib/features/auto_update/data/services/linux_install_method_reader.dart`:

```dart
import 'dart:io';

import '../../domain/entities/linux_install_method.dart';

/// Reads the install-method marker that the Linux packages ship.
///
/// The marker sits beside the executable at /usr/lib/submersion/INSTALL_METHOD.
/// The tarball ships no marker, so its absence is the tarball case rather than
/// an error.
class LinuxInstallMethodReader {
  const LinuxInstallMethodReader({required this.executablePath});

  final String executablePath;

  LinuxInstallMethod read() {
    try {
      final marker = File(
        '${File(executablePath).parent.path}/INSTALL_METHOD',
      );
      if (!marker.existsSync()) return LinuxInstallMethod.tarball;
      return switch (marker.readAsStringSync().trim()) {
        'deb' => LinuxInstallMethod.deb,
        'rpm' => LinuxInstallMethod.rpm,
        _ => LinuxInstallMethod.tarball,
      };
    } on FileSystemException {
      return LinuxInstallMethod.tarball;
    }
  }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/features/auto_update/data/linux_install_method_reader_test.dart`
Expected: 5 tests pass.

- [ ] **Step 6: Add the provider**

In `lib/features/auto_update/presentation/providers/update_providers.dart`, add
the import and the provider next to the existing platform providers:

```dart
/// How this Linux copy was installed. A provider rather than an inline
/// Platform check, matching isLinuxPlatformProvider in sync_providers.dart,
/// so widget tests can simulate each install method on any CI host.
final linuxInstallMethodProvider = Provider<LinuxInstallMethod>((ref) {
  if (!Platform.isLinux) return LinuxInstallMethod.tarball;
  return LinuxInstallMethodReader(
    executablePath: Platform.resolvedExecutable,
  ).read();
});
```

- [ ] **Step 7: Add the localized hint to all 11 ARB files**

In `lib/l10n/arb/app_en.arb`, beside `autoUpdate_banner_download` (line 20078):

```json
  "autoUpdate_banner_packageManagerHint": "Update with: {command}",
  "@autoUpdate_banner_packageManagerHint": {
    "description": "Shown instead of a Download button when Submersion was installed from a .deb or .rpm, since the system package manager owns the upgrade.",
    "placeholders": {
      "command": { "type": "String", "example": "sudo apt upgrade submersion" }
    }
  },
```

Add the same key with a translation to each of `app_ar.arb`, `app_de.arb`,
`app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`,
`app_nl.arb`, `app_pt.arb`, `app_zh.arb`. Every locale must carry the key, or
the generated hub falls back inconsistently.

- [ ] **Step 8: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: `lib/l10n/arb/app_localizations*.dart` regenerate with the new
getter, and `flutter analyze` reports no missing-key errors.

- [ ] **Step 9: Design the actions widget (write the test first, in Step 10)**

`UpdateStatusNotifier`'s constructor schedules a 5 second delayed check, so
stubbing it inside a widget test leaks a pending timer. Extracting the actions
row removes the need to stub it at all, and gives the install-method behavior a
unit to be tested against directly.

This is the widget Step 11 creates, at
`lib/features/auto_update/presentation/widgets/update_banner_actions.dart`.
Read it now, then write its test before creating the file:

```dart
import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../domain/entities/linux_install_method.dart';

/// The action area of [UpdateBanner].
///
/// A packaged Linux install is upgraded by the system package manager, so this
/// shows the command rather than a download button: the app knows about the
/// release before the package manager has told the user, but it is not the
/// thing that should install it.
class UpdateBannerActions extends StatelessWidget {
  const UpdateBannerActions({
    super.key,
    required this.installMethod,
    required this.downloadUrl,
    required this.onDownload,
    required this.onDismiss,
  });

  final LinuxInstallMethod installMethod;
  final String? downloadUrl;
  final ValueChanged<String> onDownload;
  final VoidCallback onDismiss;

  /// The command that upgrades a packaged install.
  static String upgradeCommand(LinuxInstallMethod method) => switch (method) {
    LinuxInstallMethod.deb => 'sudo apt upgrade submersion',
    LinuxInstallMethod.rpm => 'sudo dnf upgrade submersion',
    LinuxInstallMethod.tarball => '',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = downloadUrl;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (installMethod.isPackaged)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SelectableText(
              context.l10n.autoUpdate_banner_packageManagerHint(
                upgradeCommand(installMethod),
              ),
              style: theme.textTheme.bodySmall,
            ),
          )
        else if (url != null)
          TextButton(
            onPressed: () => onDownload(url),
            child: Text(context.l10n.autoUpdate_banner_download),
          ),
        IconButton(
          icon: const Icon(Icons.close, size: 18),
          tooltip: context.l10n.common_action_dismiss,
          onPressed: onDismiss,
        ),
      ],
    );
  }
}
```

Confirm the l10n import path matches what `update_banner.dart` already uses; if
that file imports the localizations differently, copy its import verbatim.

- [ ] **Step 10: Write the failing test**

Create `test/features/auto_update/presentation/update_banner_actions_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/auto_update/domain/entities/linux_install_method.dart';
import 'package:submersion/features/auto_update/presentation/widgets/update_banner_actions.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget _host(LinuxInstallMethod method, {String? downloadUrl}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(
    body: UpdateBannerActions(
      installMethod: method,
      downloadUrl: downloadUrl,
      onDownload: (_) {},
      onDismiss: () {},
    ),
  ),
);

void main() {
  const url = 'https://example.invalid/Submersion-Linux.tar.gz';

  testWidgets('tarball install offers a download button', (tester) async {
    await tester.pumpWidget(
      _host(LinuxInstallMethod.tarball, downloadUrl: url),
    );
    expect(find.text('Download'), findsOneWidget);
  });

  testWidgets('deb install shows the apt command, not a download', (
    tester,
  ) async {
    await tester.pumpWidget(_host(LinuxInstallMethod.deb, downloadUrl: url));
    expect(find.text('Download'), findsNothing);
    expect(find.textContaining('sudo apt upgrade submersion'), findsOneWidget);
  });

  testWidgets('rpm install shows the dnf command', (tester) async {
    await tester.pumpWidget(_host(LinuxInstallMethod.rpm, downloadUrl: url));
    expect(find.text('Download'), findsNothing);
    expect(find.textContaining('sudo dnf upgrade submersion'), findsOneWidget);
  });

  testWidgets('a packaged install shows no download even with a url', (
    tester,
  ) async {
    await tester.pumpWidget(_host(LinuxInstallMethod.deb, downloadUrl: url));
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('dismiss is always available', (tester) async {
    await tester.pumpWidget(_host(LinuxInstallMethod.deb));
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  test('upgradeCommand is empty for a tarball install', () {
    expect(
      UpdateBannerActions.upgradeCommand(LinuxInstallMethod.tarball),
      isEmpty,
    );
  });
}
```

- [ ] **Step 11: Run the test to verify it fails, then wire the widget in**

Run: `flutter test test/features/auto_update/presentation/update_banner_actions_test.dart`
Expected: FAIL, `Target of URI doesn't exist` for `update_banner_actions.dart`.

Then create the widget from Step 9 and replace the `actions:` list in
`lib/features/auto_update/presentation/widgets/update_banner.dart` with a single
entry:

```dart
      actions: [
        UpdateBannerActions(
          installMethod: ref.watch(linuxInstallMethodProvider),
          downloadUrl: downloadUrl,
          onDownload: _openDownload,
          onDismiss: () => setState(() => _dismissed = true),
        ),
      ],
```

Add the import for `update_banner_actions.dart` at the top of the file.

- [ ] **Step 12: Run the tests to verify they pass**

Run: `flutter test test/features/auto_update/`
Expected: all tests pass, including the pre-existing ones.

- [ ] **Step 13: Format, analyze, and commit**

```bash
dart format .
flutter analyze
git add lib test
git commit -m "feat(linux): show the package-manager command on packaged installs"
```

`flutter analyze` must report zero issues, infos included, because CI treats
infos as fatal.

---

### Task 12: Document the install paths

**Files:**
- Modify: `README.md:335-372` (the Linux build-from-source section)
- Modify: `docs/guide/installation.md`

**Interfaces:**
- Consumes: the asset names from Task 7.

- [ ] **Step 1: Add an install section to the README**

Insert a new collapsible block immediately before the existing
`<summary><b>Linux: building from source (distro dependencies)</b></summary>`
block:

````markdown
<details>
<summary><b>Linux: installing</b></summary>

**Debian, Ubuntu, Mint, and derivatives**

Download `Submersion-<version>-Linux-amd64.deb` from
[Releases](https://github.com/submersion-app/submersion/releases), then:

```bash
sudo apt install ./Submersion-*-Linux-amd64.deb
```

**Fedora, RHEL, openSUSE**

Download `Submersion-<version>-Linux-x86_64.rpm`, then:

```bash
sudo dnf install ./Submersion-*-Linux-x86_64.rpm
```

Both packages install a desktop entry, icons, and udev rules that let dive
computers connected by USB be reached without any group membership or
`usermod` step. Video compression is optional and needs `ffmpeg`, which the
packages recommend but do not require.

**Everything else (Arch, NixOS, and anyone who prefers not to install packages)**

Download `Submersion-<version>-Linux.tar.gz`, unpack it, and run the included
installer:

```bash
tar xzf Submersion-*-Linux.tar.gz
./install.sh
```

`install.sh` checks for missing shared libraries, prints the exact command to
install them for your package manager, installs a desktop entry and icon into
`~/.local/share`, and links the binary into `~/.local/bin`. It also prints the
command to install the udev rules, which needs root. `./uninstall.sh` reverses
all of it and never touches your dive log data.

</details>
````

- [ ] **Step 2: Mirror it in the docs site**

Add the same three paths to the Linux section of `docs/guide/installation.md`,
matching that file's existing heading structure and tab style.

- [ ] **Step 3: Verify no em-dashes crept in**

```bash
# The pattern is built from UTF-8 bytes rather than written literally, so this
# file does not itself contain the character it forbids.
EMDASH=$(printf '\xe2\x80\x94')
grep -n "$EMDASH" README.md docs/guide/installation.md \
  && echo "FOUND EM-DASHES" || echo "clean"
```

Expected: `clean`.

- [ ] **Step 4: Commit**

```bash
git add README.md docs/guide/installation.md
git commit -m "docs: document the Linux install paths"
```

---

### Task 13: Cover packaging on every pull request (added during execution)

`build-all.yml` is `workflow_call`-only, and nothing a pull request triggers
invokes it: `ci.yaml` runs on push and pull_request but has its own
`build-linux` job that never calls it. So every change to the release build
path, this one included, was unverifiable until after a merge, at which point a
break fails `verify-linux-packages`, fails `build-all`, fails `beta.yml`'s build
job, and publishes no beta that cycle.

This task closes that gap by extracting the packaging into scripts both
workflows call, then adding the same coverage to `ci.yaml`.

**Files:**
- Create: `scripts/release/build_linux_packages.sh`
- Create: `scripts/release/verify_linux_package.sh`
- Modify: `.github/workflows/build-all.yml` (call the shared scripts)
- Modify: `.github/workflows/ci.yaml` (packaging plus container verification)

**Scope limit, stated so it is not assumed away:** `ci.yaml`'s `build-linux`
runs on `ubuntu-latest`, not the `ubuntu:22.04` container. It therefore covers
packaging mechanics, dependency derivation, and installability, but **not** the
glibc floor. `build-all.yml` remains the only check on the floor itself.

- [x] **Step 1: Extract the packaging into a shared script**

`scripts/release/build_linux_packages.sh` takes `--bundle`, `--version`,
`--deb`, `--rpm`, and an optional `--staging-root`, then stages both trees,
derives both dependency lists, and runs fpm twice. Portable to bash 3.2 so it
runs on a developer's macOS shell as well as in CI.

- [x] **Step 2: Extract the in-container assertions**

`scripts/release/verify_linux_package.sh` runs inside the container, installs
whatever package it finds in `/p` with the native package manager, and asserts
`--version`, the desktop entry, metainfo, udev rules with `uaccess` and without
`plugdev`, the icon, and no unresolved libraries.

- [x] **Step 3: Point build-all.yml at both scripts**

Its three packaging steps collapse to one call, and the verify job mounts the
script into the container. Checkout must precede `download-artifact` in that
job: `actions/checkout` cleans the workspace by default and would otherwise
delete the downloaded packages.

- [x] **Step 4: Add the same coverage to ci.yaml's build-linux**

After the existing native-asset check: install fpm and rpm, build both packages
at the pubspec version, and run the verification script in `debian:12` and
`fedora:latest`.

- [x] **Step 5: Verify locally as far as a macOS host allows**

```bash
shellcheck scripts/release/build_linux_packages.sh scripts/release/verify_linux_package.sh
TMP=$(mktemp -d); mkdir -p "$TMP/bundle/lib"; echo bin > "$TMP/bundle/submersion"
bash scripts/release/build_linux_packages.sh --bundle "$TMP/bundle" \
  --version 1.7.7.124 --deb "$TMP/o.deb" --rpm "$TMP/o.rpm" --staging-root "$TMP"
```

Expected: staging completes, then it stops at `readelf not found`, which is the
correct actionable error on a host without binutils.

---

## Final Verification

- [ ] **Run the full Python test suite**

```bash
python3 scripts/gen_udev_rules_test.py
python3 scripts/linux_package_deps_test.py
python3 scripts/release/stage_linux_package_test.py
bash scripts/release/install_sh_test.sh
```

Expected: all pass.

- [ ] **Run the Dart suite once, unpiped**

```bash
flutter test
```

Piping to `grep` hides the exit status, so run it plain and read the summary.

- [ ] **Confirm CI is green end to end**

```bash
gh run list --branch feat/linux-packaging --limit 3
```

Expected: `Build Linux` and both `Verify Linux Packages` matrix legs pass.

- [ ] **Manually install on a real desktop**

Download the `.deb` from the branch's artifact, install it on a Debian or
Ubuntu desktop, confirm Submersion appears in the application menu with its
icon, launches, and that a USB dive computer is detected without any group
change. This is the one thing CI cannot prove.
