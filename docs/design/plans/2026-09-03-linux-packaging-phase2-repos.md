# Linux Packaging Phase 2: APT and DNF Repositories Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** publish signed APT and DNF repositories at `packages.submersion.app`
so Linux users receive Submersion updates through `apt upgrade` and
`dnf upgrade` like any other package, on both the stable and beta channels.

**Architecture:** a stateless publisher. Each run downloads the packages it
needs from GitHub Releases, regenerates the entire site, signs the metadata,
and deploys to GitHub Pages. The repository is a *view* over GitHub Releases,
never a source of truth, which is what lets a nightly reconcile repair a missed
publish. All logic lives in this repo with tests; the new repo holds only a
thin workflow.

**Tech Stack:** GitHub Actions, GitHub Pages, Python 3 (stdlib only),
`dpkg-scanpackages`, `apt-ftparchive`, `createrepo_c`, GnuPG, `gh` CLI.

**Spec:** `docs/superpowers/specs/2026-09-03-linux-packaging-design.md`, Section 4

**Depends on:** Phase 1 (PR #1514). The `.deb` and `.rpm` must exist as release
assets before there is anything to index.

## Two decisions this plan makes

Both are plan-level choices inside the approved design. They are called out
here rather than buried so they can be overridden before work starts.

**1. The repository-building code lives in this repo, not in
`submersion-app/linux-packages`.** That repo gets a workflow that checks this
one out and runs `scripts/release/linux_repo/`. The logic then sits where the
test harness, the review process, and the existing `scripts/*_test.py`
convention already are, and the second repo stays nearly empty. The alternative,
putting the scripts in the new repo, would place the code that decides what
every Linux user downloads outside normal review.

**2. RPMs are signed at build time in `build-all.yml`, not by the repository
workflow.** Section 4 of the spec says `rpmsign --addsign` runs in the repo
workflow. Signing at build time instead means the `.rpm` on GitHub Releases and
the `.rpm` in the DNF repo are the same bytes, covered by the same
`checksums-sha256.txt`, which is what "the repository is a view over Releases"
should mean. It costs adding the signing key to the main repo's secrets. Debian
packages need no equivalent: apt verifies the signed `Release` file, not
individual `.deb` files.

## Global Constraints

- **Worktree:** a new worktree and branch, `feat/linux-package-repos`, created
  from `origin/main` after Phase 1 merges. Never check it out in the main tree.
- **No em-dashes** (U+2014) in any file, comment, commit message, or PR body.
- **No emojis** in code, comments, or documentation.
- **Python scripts are stdlib only**, each with a sibling `*_test.py` runnable
  as `python3 scripts/release/linux_repo/<name>_test.py`, using `unittest`.
- **No secret material in the repo.** The signing key exists only in Actions
  secrets and on the maintainer's machine. Tests never need a key: the scripts
  generate unsigned metadata and signing is a separate workflow step.
- **Repository identity:** APT suites `stable` and `beta`, component `main`,
  architecture `amd64`. DNF repositories `stable` and `beta`, basearch
  `x86_64`.
- **Retention:** two versions per suite, enforced by the fetch step.
- **Size guard:** the assembled site fails the build above 800 MB, against the
  1 GB Pages cap.
- **PR descriptions:** no Claude Code attribution line, no session URL.

---

## File Structure

**Created in this repo:**

| File | Responsibility |
| --- | --- |
| `scripts/release/linux_repo/fetch_release_packages.py` | Download the last N releases' packages for one channel |
| `scripts/release/linux_repo/build_apt_repo.py` | Emit `pool/`, `Packages`, `Packages.gz`, and an unsigned `Release` |
| `scripts/release/linux_repo/build_rpm_repo.py` | Lay out RPMs per suite and run `createrepo_c` |
| `scripts/release/linux_repo/assemble_site.py` | Orchestrate the four stages and enforce the size guard |
| `scripts/release/linux_repo/site_assets/submersion.repo` | DNF drop-in template |
| `scripts/release/linux_repo/site_assets/setup.sh` | Documented enrollment script served from the site |
| `scripts/release/linux_repo/*_test.py` | One test suite per script |
| `.github/workflows/publish-linux-repo.yml` | Reference copy of the workflow the other repo runs |

**Created in `submersion-app/linux-packages`:**

| File | Responsibility |
| --- | --- |
| `.github/workflows/publish.yml` | Checkout this repo, assemble, sign, deploy to Pages |
| `README.md` | What the repo is, and that its logic lives in the app repo |

**Modified in this repo:**

| File | Change |
| --- | --- |
| `scripts/release/stage_linux_package.py` | Self-enrollment files plus a postinstall hook |
| `scripts/release/build_linux_packages.sh` | Pass `--after-install`, sign the RPM when a key is present |
| `.github/workflows/build-all.yml` | RPM signing step |
| `.github/workflows/release.yml`, `beta.yml`, `promote.yml` | `repository_dispatch` on success |
| `docs/developer/release-secrets-setup.md` | Signing key and dispatch token |
| `README.md`, `docs/guide/installation.md` | Repository enrollment instructions |

---

### Task 1: Create the signing key and the repository (maintainer actions)

Nothing else can be verified end to end until these exist. Both steps handle
secret material or create public infrastructure, so a person performs them.

**Files:**
- Modify: `docs/developer/release-secrets-setup.md`

**Interfaces:**
- Produces: secrets `LINUX_REPO_GPG_PRIVATE_KEY`, `LINUX_REPO_GPG_PASSPHRASE`,
  `LINUX_REPO_DISPATCH_TOKEN`, consumed by Tasks 6 and 7, and the public key
  bytes consumed by Task 5.

- [ ] **Step 1: Generate the key offline**

Save this as a script and run it with `bash generate-key.sh` rather than
pasting it line by line: it aborts on the first failure, and pasting would
close an interactive shell instead.

```bash
#!/usr/bin/env bash
# Without this the block runs on after a failure: a gpg that could not
# generate the key would flow straight into the export below and produce an
# empty or wrong secret, which then gets pasted into a GitHub secret.
set -euo pipefail

# Everything here is private key material, so it is written inside a
# mktemp -d directory (created 0700) with umask 077 in force. Shell
# redirection creates files using the caller's umask, commonly 0644, and a
# chmod afterwards still leaves a window in which another local user can read
# the file. The directory closes that window regardless of file mode.
umask 077
KEYDIR=$(mktemp -d)

# gpg writes the generated secret key into its own home directory, not into
# the file the export is redirected to, so GNUPGHOME is pointed inside KEYDIR.
# Without this the private key persists in ~/.gnupg after the cleanup below
# believes it has removed everything, and, worse, the KEYID lookup further
# down would match any existing key for the same address, so the export could
# quietly produce the wrong key and the repository would be signed by it.
export GNUPGHOME="$KEYDIR/gnupg"
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"

# tr -d: command substitution strips the trailing newline from the argument,
# but the file is what becomes the LINUX_REPO_GPG_PASSPHRASE secret. The
# stored passphrase would then not match the one the key was created with,
# and every signing step would fail.
openssl rand -base64 32 | tr -d '\n' > "$KEYDIR/repo-pass"

# --pinentry-mode loopback is required on GnuPG 2.1+ for --passphrase to be
# honoured at all; without it gpg ignores the option and tries to prompt
# through pinentry, which has nowhere to prompt in a scripted context. The
# signing steps in Task 6 pass the same flag for the same reason.
#
# --passphrase-file rather than --passphrase: a passphrase given on the command
# line is visible to every user on the machine through ps.
gpg --batch --pinentry-mode loopback --passphrase-file "$KEYDIR/repo-pass" \
  --quick-generate-key "Submersion Package Signing <dev@submersion.app>" \
  rsa4096 sign never

KEYID=$(gpg --list-keys --with-colons dev@submersion.app | awk -F: '/^pub/{print $5; exit}')

# pipefail above already aborts if gpg itself fails. This covers the other
# case: gpg succeeding while printing no pub record, which leaves KEYID empty
# and no non-zero status anywhere. An empty key id would make the export below
# select nothing in particular, and the result would be pasted into a GitHub
# secret without anyone noticing.
if [ -z "$KEYID" ]; then
  echo "Could not read the new key's id from $GNUPGHOME." >&2
  exit 1
fi
echo "Key id: $KEYID"

# Exporting a passphrase-protected secret key needs the same treatment: it
# decrypts the key, so it prompts exactly as generation does.
gpg --batch --pinentry-mode loopback --passphrase-file "$KEYDIR/repo-pass" \
  --armor --export-secret-keys "$KEYID" > "$KEYDIR/repo-private.asc"

# The public half needs no passphrase.
gpg --export "$KEYID" > "$KEYDIR/submersion.gpg"   # dearmored, for signed-by=

echo "Key material is in $KEYDIR"
```

Expected: `$KEYDIR/submersion.gpg` is a binary keyring, and
`gpg --show-keys "$KEYDIR/submersion.gpg"` prints one key. Confirm the
directory is private with `ls -ld "$KEYDIR"`, which must show `drwx------`,
and confirm the isolation held with `gpg --list-secret-keys`, which must list
exactly the key just generated and nothing from your personal keyring.

- [ ] **Step 2: Store the secrets**

In `submersion-app/submersion`: `LINUX_REPO_GPG_PRIVATE_KEY` (contents of
`$KEYDIR/repo-private.asc`) and `LINUX_REPO_GPG_PASSPHRASE` (contents of
`$KEYDIR/repo-pass`), for RPM signing at build time.

In `submersion-app/linux-packages`: the same two secrets, for metadata signing.

In `submersion-app/submersion`: `LINUX_REPO_DISPATCH_TOKEN`, a fine-grained PAT
with Contents: write on `submersion-app/linux-packages` only.

Then shred the two secrets, which are now stored where they are needed:

```bash
# shred is GNU coreutils and is absent on macOS, where this procedure is most
# likely to be run; rm -P is the BSD equivalent. On APFS, and on any SSD,
# neither reliably overwrites the original blocks, so treat this as tidying
# rather than secure erasure. The real protection is that these files only
# ever existed inside a 0700 directory.
if command -v shred > /dev/null 2>&1; then
  shred -u "$KEYDIR/repo-private.asc" "$KEYDIR/repo-pass"
else
  rm -P "$KEYDIR/repo-private.asc" "$KEYDIR/repo-pass"
fi
```

`$KEYDIR` itself stays until Step 4, because it still holds the public key that
step commits, and the isolated `GNUPGHOME` inside it still holds the secret
key. Do not `rmdir` it here: the directory is not empty, so that would fail,
and it would destroy the public key before it has been copied anywhere.

- [ ] **Step 3: Create the repository and point DNS at it**

Create `submersion-app/linux-packages` as a public repository. In its settings,
set Pages source to GitHub Actions, and add the custom domain
`packages.submersion.app`. Add a DNS CNAME for `packages` pointing at
`submersion-app.github.io`.

- [ ] **Step 4: Commit the public key and document the setup**

The dearmored public key is committed to this repo at
`scripts/release/linux_repo/site_assets/submersion.gpg`, because it is public by
definition and the site must serve identical bytes on every rebuild.

```bash
cp "$KEYDIR/submersion.gpg" scripts/release/linux_repo/site_assets/submersion.gpg
gpg --show-keys scripts/release/linux_repo/site_assets/submersion.gpg
```

Add a `### Linux Package Repository` section to
`docs/developer/release-secrets-setup.md` recording all four secrets, which repo
each lives in, the key fingerprint, and the rotation procedure.

Only now remove the working directory, which also removes the isolated
`GNUPGHOME` and with it the generated secret key:

```bash
rm -rf "$KEYDIR"
unset GNUPGHOME
```

`rm -rf` rather than `rmdir`, because the directory holds the GnuPG home as
well as the public key.

- [ ] **Step 5: Commit**

```bash
git add scripts/release/linux_repo/site_assets/submersion.gpg \
  docs/developer/release-secrets-setup.md
git commit -m "docs: record the Linux package repository signing setup"
```

---

### Task 2: Fetch the packages a suite should carry

**Files:**
- Create: `scripts/release/linux_repo/fetch_release_packages.py`
- Create: `scripts/release/linux_repo/fetch_release_packages_test.py`

**Interfaces:**
- Produces:
  `fetch_release_packages.py --channel {stable,beta} --limit 2 --out DIR`,
  downloading each release's `.deb` and `.rpm`. Exposes
  `select_releases(tags, limit)` and `asset_names(tag)` as pure functions.
  Task 5 calls the CLI.

- [ ] **Step 1: Write the failing test**

```python
#!/usr/bin/env python3
"""Unit tests for fetch_release_packages.py.

Run: python3 scripts/release/linux_repo/fetch_release_packages_test.py

The selection logic decides what every Linux user can install. Getting the
ordering wrong publishes an older build as the newest available version, which
apt would then refuse to upgrade past, stranding users silently.
"""

import importlib.util
import os
import unittest

SCRIPT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "fetch_release_packages.py"
)
spec = importlib.util.spec_from_file_location("fetch_release_packages", SCRIPT)
fetch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fetch)


class SelectReleasesTest(unittest.TestCase):
    def test_keeps_the_newest_n_by_version_not_string_order(self):
        tags = ["v1.7.9.7100", "v1.7.10.7200", "v1.7.6.7000"]
        # Plain string sort would put 1.7.9 above 1.7.10.
        self.assertEqual(
            fetch.select_releases(tags, 2), ["v1.7.10.7200", "v1.7.9.7100"]
        )

    def test_limit_larger_than_available_returns_everything(self):
        self.assertEqual(
            fetch.select_releases(["v1.0.0.1"], 5), ["v1.0.0.1"]
        )

    def test_ignores_tags_that_are_not_four_segment_versions(self):
        tags = ["v1.7.10.7200", "nightly", "v1.7.9.7100", "v2"]
        self.assertEqual(
            fetch.select_releases(tags, 3), ["v1.7.10.7200", "v1.7.9.7100"]
        )

    def test_empty_input_raises_rather_than_publishing_an_empty_repo(self):
        with self.assertRaises(SystemExit):
            fetch.select_releases([], 2)


class AssetNamesTest(unittest.TestCase):
    def test_derives_both_package_names_from_a_tag(self):
        self.assertEqual(
            fetch.asset_names("v1.7.10.7200"),
            [
                "Submersion-v1.7.10.7200-Linux-amd64.deb",
                "Submersion-v1.7.10.7200-Linux-x86_64.rpm",
            ],
        )


class ChannelRepoTest(unittest.TestCase):
    def test_stable_reads_the_app_repo(self):
        self.assertEqual(fetch.repo_for("stable"), "submersion-app/submersion")

    def test_beta_reads_the_beta_builds_repo(self):
        self.assertEqual(fetch.repo_for("beta"), "submersion-app/beta-builds")

    def test_unknown_channel_is_rejected(self):
        with self.assertRaises(SystemExit):
            fetch.repo_for("nightly")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `python3 scripts/release/linux_repo/fetch_release_packages_test.py`
Expected: FAIL with `FileNotFoundError: [Errno 2] No such file or
directory: ... fetch_release_packages.py`. The harness loads the script by
path through `spec_from_file_location` plus `exec_module`, which never
consults the import system, so a missing file raises when the loader opens
it rather than as an import error.

- [ ] **Step 3: Write the implementation**

Key points the implementation must honor:

- `select_releases` sorts by a tuple of integers parsed from the tag, never by
  string, and exits rather than returning an empty list.
- `repo_for` maps `stable` to `submersion-app/submersion` and `beta` to
  `submersion-app/beta-builds`, matching `promote.yml:87`.
- Downloading shells out to
  `gh release download <tag> --repo <repo> --pattern '<name>' --dir <out>`,
  and a missing asset is a hard failure: a release without packages means the
  suite would silently lose a version.

```python
#!/usr/bin/env python3
"""Download the Submersion Linux packages a repository suite should carry.

The published repository is a view over GitHub Releases rather than a store of
its own, so every publish re-derives its contents from the releases that exist
right now. That is what lets a nightly reconcile repair a missed publish.

Usage:
    fetch_release_packages.py --channel stable --limit 2 --out packages/stable
"""

import argparse
import os
import re
import subprocess
import sys

_TAG_RE = re.compile(r"^v(\d+)\.(\d+)\.(\d+)\.(\d+)$")

_CHANNEL_REPOS = {
    "stable": "submersion-app/submersion",
    "beta": "submersion-app/beta-builds",
}


def repo_for(channel):
    """The GitHub repository holding a channel's releases."""
    if channel not in _CHANNEL_REPOS:
        sys.exit(
            "fetch_release_packages: unknown channel %r (expected one of %s)"
            % (channel, ", ".join(sorted(_CHANNEL_REPOS)))
        )
    return _CHANNEL_REPOS[channel]


def select_releases(tags, limit):
    """The newest `limit` release tags, ordered newest first.

    Sorted numerically per segment: a string sort puts v1.7.9 above v1.7.10 and
    would publish an older build as the newest available version.
    """
    parsed = []
    for tag in tags:
        match = _TAG_RE.match(tag)
        if match:
            parsed.append((tuple(int(p) for p in match.groups()), tag))
    if not parsed:
        sys.exit(
            "fetch_release_packages: no four-segment version tags found. "
            "Publishing an empty repository would remove Submersion from "
            "every enrolled system."
        )
    parsed.sort(reverse=True)
    return [tag for _, tag in parsed[:limit]]


def asset_names(tag):
    """The two package asset names a release carries."""
    return [
        "Submersion-%s-Linux-amd64.deb" % tag,
        "Submersion-%s-Linux-x86_64.rpm" % tag,
    ]


def download(tag, repo, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    for name in asset_names(tag):
        result = subprocess.run(
            ["gh", "release", "download", tag, "--repo", repo,
             "--pattern", name, "--dir", out_dir, "--clobber"],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            sys.exit(
                "fetch_release_packages: %s is missing %s.\n%s"
                % (tag, name, result.stderr.strip())
            )


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--channel", required=True, choices=("stable", "beta"))
    parser.add_argument("--limit", type=int, default=2)
    parser.add_argument("--out", required=True)
    args = parser.parse_args(argv)

    repo = repo_for(args.channel)
    listing = subprocess.run(
        ["gh", "release", "list", "--repo", repo, "--limit", "50",
         "--json", "tagName", "-q", ".[].tagName"],
        check=True, capture_output=True, text=True,
    ).stdout.split()

    for tag in select_releases(listing, args.limit):
        print("fetching %s" % tag)
        download(tag, repo, args.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `python3 scripts/release/linux_repo/fetch_release_packages_test.py`
Expected: `OK`, 8 tests.

- [ ] **Step 5: Verify against the real releases**

```bash
python3 scripts/release/linux_repo/fetch_release_packages.py \
  --channel stable --limit 1 --out /tmp/pkgtest
ls -la /tmp/pkgtest
```

Expected: one `.deb` and one `.rpm`. This only works once Phase 1 has shipped a
release carrying them; until then the expected result is the "is missing"
error, which confirms the failure path.

- [ ] **Step 6: Commit**

```bash
git add scripts/release/linux_repo/fetch_release_packages.py \
  scripts/release/linux_repo/fetch_release_packages_test.py
git commit -m "feat(linux-repo): fetch the packages a suite should carry"
```

---

### Task 3: Build the APT repository

`dpkg-scanpackages` plus `apt-ftparchive`, not `reprepro` or `aptly`: both of
those want a persistent database that a stateless rebuild would have to fake.

**Files:**
- Create: `scripts/release/linux_repo/build_apt_repo.py`
- Create: `scripts/release/linux_repo/build_apt_repo_test.py`

**Interfaces:**
- Consumes: a directory of `.deb` files per suite from Task 2.
- Produces: `build_apt_repo.py --packages DIR --suite NAME --site DIR`, writing
  `pool/main/s/submersion/`, `dists/<suite>/main/binary-amd64/Packages{,.gz}`,
  and an unsigned `dists/<suite>/Release`. Signing is Task 6's workflow step, so
  no test needs a key.

- [ ] **Step 1: Write the failing test**

Cover, with `.deb` files faked as plain files where the layout is what matters
and a real `dpkg-deb`-built fixture where `Packages` content is:

```python
class LayoutTest(unittest.TestCase):
    def test_packages_land_in_the_debian_pool_path(self):
        # pool/main/s/submersion/ is the conventional path; apt does not
        # require it, but tools and mirrors assume it.
        ...

    def test_release_file_declares_the_suite_and_architecture(self):
        text = ...
        self.assertIn("Suite: stable", text)
        self.assertIn("Architectures: amd64", text)
        self.assertIn("Components: main", text)

    def test_release_file_carries_checksums_for_the_packages_index(self):
        # Without SHA256 entries apt rejects the repository as unverifiable
        # even when the signature is valid.
        ...

    def test_packages_gz_is_written_alongside_packages(self):
        ...

    def test_an_empty_package_directory_is_rejected(self):
        # Publishing an empty Packages index removes the app from every
        # enrolled system on the next apt update.
        with self.assertRaises(SystemExit):
            ...
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `python3 scripts/release/linux_repo/build_apt_repo_test.py`
Expected: FAIL with `FileNotFoundError` for `build_apt_repo.py`, for the
same reason as Task 2: the harness loads by path, not by import.

- [ ] **Step 3: Write the implementation**

The script must:

1. Copy each `.deb` into `<site>/apt/pool/main/s/submersion/`.
2. Run `dpkg-scanpackages --arch amd64 pool/main/s/submersion` from the `apt/`
   directory, so `Filename:` paths are relative to the repository root, and
   write `dists/<suite>/main/binary-amd64/Packages`.
3. Write `Packages.gz` with `gzip.compress(..., mtime=0)`, so an unchanged
   input produces an unchanged byte stream and Pages does not see churn.
4. Run `apt-ftparchive release dists/<suite>` with `-o APT::FTPArchive::Release::Suite=<suite>`,
   `::Codename=<suite>`, `::Origin=Submersion`, `::Label=Submersion`,
   `::Architectures=amd64`, `::Components=main`, and write the output to
   `dists/<suite>/Release`.
5. Exit non-zero if the package directory is empty.

- [ ] **Step 4: Run the test to verify it passes**

Expected: `OK`.

- [ ] **Step 5: Commit**

```bash
git add scripts/release/linux_repo/build_apt_repo.py \
  scripts/release/linux_repo/build_apt_repo_test.py
git commit -m "feat(linux-repo): build the APT repository metadata"
```

---

### Task 4: Build the DNF repository

**Files:**
- Create: `scripts/release/linux_repo/build_rpm_repo.py`
- Create: `scripts/release/linux_repo/build_rpm_repo_test.py`

**Interfaces:**
- Produces: `build_rpm_repo.py --packages DIR --suite NAME --site DIR`, writing
  `<site>/rpm/<suite>/` with the RPMs and a `repodata/` from `createrepo_c`.

- [ ] **Step 1: Write the failing test**

```python
class LayoutTest(unittest.TestCase):
    def test_rpms_land_in_the_suite_directory(self):
        ...

    def test_repodata_is_generated(self):
        self.assertTrue(os.path.isfile(".../rpm/stable/repodata/repomd.xml"))

    def test_repomd_is_well_formed_xml(self):
        xml.dom.minidom.parse(".../repodata/repomd.xml")

    def test_an_empty_package_directory_is_rejected(self):
        with self.assertRaises(SystemExit):
            ...

    def test_createrepo_missing_gives_an_actionable_error(self):
        # Same shape as linux_package_deps.py's readelf check: name the
        # package to install rather than surfacing a bare FileNotFoundError.
        ...
```

- [ ] **Step 2: Run the test to verify it fails**

- [ ] **Step 3: Write the implementation**

Copy the RPMs into `<site>/rpm/<suite>/`, then run `createrepo_c --update .`
there. Missing `createrepo_c` exits with "install createrepo-c", matching the
error style `linux_package_deps.py` uses for `readelf`.

- [ ] **Step 4: Run the test to verify it passes**

- [ ] **Step 5: Commit**

```bash
git add scripts/release/linux_repo/build_rpm_repo.py \
  scripts/release/linux_repo/build_rpm_repo_test.py
git commit -m "feat(linux-repo): build the DNF repository metadata"
```

---

### Task 5: Assemble the whole site

**Files:**
- Create: `scripts/release/linux_repo/assemble_site.py`
- Create: `scripts/release/linux_repo/assemble_site_test.py`
- Create: `scripts/release/linux_repo/site_assets/submersion.repo`
- Create: `scripts/release/linux_repo/site_assets/setup.sh`
- Create: `scripts/release/linux_repo/site_assets/index.html`

**Interfaces:**
- Consumes: Tasks 2, 3, and 4.
- Produces: `assemble_site.py --site DIR [--limit 2]`, a complete unsigned site.

- [ ] **Step 1: Write the failing test**

```python
class SiteTest(unittest.TestCase):
    def test_both_suites_are_built_for_both_formats(self):
        for suite in ("stable", "beta"):
            self.assertTrue(os.path.isdir(".../apt/dists/%s" % suite))
            self.assertTrue(os.path.isdir(".../rpm/%s" % suite))

    def test_public_key_is_served_at_the_documented_path(self):
        # setup.sh and every install doc reference /submersion.gpg by name.
        self.assertTrue(os.path.isfile(".../submersion.gpg"))

    def test_dnf_drop_in_and_setup_script_are_served(self):
        ...

    def test_size_guard_rejects_a_site_over_the_limit(self):
        with self.assertRaises(SystemExit):
            assemble.check_size(root, limit_bytes=1)

    def test_size_guard_accepts_a_site_under_the_limit(self):
        assemble.check_size(root, limit_bytes=10 ** 9)

    def test_setup_script_pins_the_keyring_with_signed_by(self):
        # An unpinned key would let any key in the system trusted set sign
        # updates for this repository.
        self.assertIn("signed-by=/usr/share/keyrings/submersion.gpg", text)

    def test_setup_script_rejects_an_unknown_channel(self):
        # The channel lands in an apt source line and a sed replacement;
        # rejecting it outright turns a malformed enrollment into an error.
        ...

    def test_setup_script_never_pipes_curl_into_tee(self):
        # POSIX sh has no pipefail, so a failed download in a pipeline would
        # write an empty file and still report success.
        self.assertNotIn("| sudo tee", text)

    def test_setup_script_handles_zypper_before_dnf(self):
        # openSUSE ships zypper and not dnf; checking dnf first would send
        # those users to the tarball branch.
        self.assertLess(text.index("command -v zypper"), text.index("command -v dnf"))
```

- [ ] **Step 2: Run the test to verify it fails**

- [ ] **Step 3: Write the site assets**

`setup.sh`, served at `https://packages.submersion.app/setup.sh`, must be
readable enough that a cautious user can audit it before running:

```bash
#!/bin/sh
# Enroll this system in the Submersion package repository.
#
# Read before running. It adds one repository and one signing key, nothing
# else. To undo:
#   sudo rm -f /etc/apt/sources.list.d/submersion.list \
#              /usr/share/keyrings/submersion.gpg
#   sudo rm -f /etc/yum.repos.d/submersion.repo
#   sudo rm -f /etc/zypp/repos.d/submersion.repo
set -eu

CHANNEL="${1:-stable}"
case "$CHANNEL" in
  stable | beta) ;;
  *)
    echo "Unknown channel: $CHANNEL (expected stable or beta)" >&2
    exit 2
    ;;
esac

BASE="https://packages.submersion.app"

# Downloaded to a file, then installed, rather than piped into sudo tee.
# POSIX sh has no pipefail, so a pipeline reports the exit status of its last
# command: curl could fail on a network error or a 404 while tee still
# succeeded, writing an empty keyring and leaving the script to print
# "Enrolled" over a repository that can never verify.
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

if command -v apt-get > /dev/null 2>&1; then
  curl -fsSL "$BASE/submersion.gpg" -o "$tmpdir/submersion.gpg"
  sudo install -m 644 "$tmpdir/submersion.gpg" \
    /usr/share/keyrings/submersion.gpg
  printf 'deb [signed-by=/usr/share/keyrings/submersion.gpg] %s/apt %s main\n' \
    "$BASE" "$CHANNEL" > "$tmpdir/submersion.list"
  sudo install -m 644 "$tmpdir/submersion.list" \
    /etc/apt/sources.list.d/submersion.list
  sudo apt-get update
  echo "Enrolled. Install with: sudo apt install submersion"
# zypper before dnf: openSUSE can have both, but zypper owns the package
# database there, and openSUSE does not ship dnf by default. Checking dnf
# first would send openSUSE users to the tarball branch.
elif command -v zypper > /dev/null 2>&1; then
  curl -fsSL "$BASE/submersion.repo" -o "$tmpdir/repo.in"
  sed "s/@CHANNEL@/$CHANNEL/" "$tmpdir/repo.in" > "$tmpdir/submersion.repo"
  sudo install -m 644 "$tmpdir/submersion.repo" \
    /etc/zypp/repos.d/submersion.repo
  echo "Enrolled. Install with: sudo zypper install submersion"
elif command -v dnf > /dev/null 2>&1; then
  curl -fsSL "$BASE/submersion.repo" -o "$tmpdir/repo.in"
  sed "s/@CHANNEL@/$CHANNEL/" "$tmpdir/repo.in" > "$tmpdir/submersion.repo"
  sudo install -m 644 "$tmpdir/submersion.repo" \
    /etc/yum.repos.d/submersion.repo
  echo "Enrolled. Install with: sudo dnf install submersion"
else
  echo "No apt, zypper, or dnf found. Use the tarball from GitHub Releases." >&2
  exit 1
fi
```

`submersion.repo` uses `@CHANNEL@` for the same substitution, sets
`gpgcheck=1`, `repo_gpgcheck=1`, and `gpgkey=https://packages.submersion.app/submersion.gpg`.
The same file serves dnf and zypper, which read the same INI format from
`/etc/yum.repos.d` and `/etc/zypp/repos.d` respectively.

`index.html` is a plain page explaining what the site is, with the manual
enrollment commands, so someone who lands on the domain is not staring at a 404.

- [ ] **Step 4: Write the implementation**

`assemble_site.py` fetches both channels into temporary directories, calls the
two builders per suite, copies `site_assets/` to the site root, and runs
`check_size(root, limit_bytes=800 * 1024 * 1024)`.

- [ ] **Step 5: Run the test to verify it passes**

- [ ] **Step 6: Commit**

```bash
git add scripts/release/linux_repo/
git commit -m "feat(linux-repo): assemble the full repository site"
```

---

### Task 6: The publishing workflow

**Files:**
- Create: `.github/workflows/publish-linux-repo.yml` in this repo (reference
  copy, `workflow_dispatch` only, so it is reviewable here)
- Create: `.github/workflows/publish.yml` in `submersion-app/linux-packages`
- Create: `README.md` in `submersion-app/linux-packages`

**Interfaces:**
- Consumes: Task 1's secrets and Task 5's `assemble_site.py`.

- [ ] **Step 1: Write the workflow**

```yaml
name: Publish Linux repository

on:
  repository_dispatch:
    types: [publish-packages]
  schedule:
    # Daily reconcile: republishes when the site and the latest releases
    # disagree, so a dropped dispatch is self-healing rather than permanent.
    - cron: '17 4 * * *'
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: publish-linux-repo
  cancel-in-progress: false

jobs:
  publish:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    environment:
      name: github-pages
      url: ${{ steps.deploy.outputs.page_url }}
    steps:
      # The logic lives in the app repo, where the tests and review are.
      #
      # Non-cone sparse-checkout with a directory pattern does include that
      # directory's contents: the patterns are gitignore-style, so an anchored
      # path matches the directory and everything beneath it. Verified against
      # git directly rather than assumed, because the behavior reads as
      # ambiguous and cone mode is the more usual choice for a directory.
      # Non-cone is used here to match the single-file checkout in
      # build-all.yml's verify job, which cone mode cannot express.
      - name: Check out the app repository
        uses: actions/checkout@v7
        with:
          repository: submersion-app/submersion
          sparse-checkout: scripts/release/linux_repo
          sparse-checkout-cone-mode: false

      # Guard rather than trust: an empty checkout would otherwise surface as
      # a confusing "No such file or directory" from assemble_site.py two
      # steps later.
      - name: Confirm the scripts were checked out
        run: test -f scripts/release/linux_repo/assemble_site.py

      - name: Install repository tools
        run: |
          sudo apt-get update -qq
          sudo apt-get install -y dpkg-dev apt-utils createrepo-c gnupg

      - name: Assemble the site
        env:
          GH_TOKEN: ${{ github.token }}
        run: python3 scripts/release/linux_repo/assemble_site.py --site _site

      - name: Import the signing key
        env:
          KEY: ${{ secrets.LINUX_REPO_GPG_PRIVATE_KEY }}
          PASSPHRASE: ${{ secrets.LINUX_REPO_GPG_PASSPHRASE }}
        run: |
          set -euo pipefail
          # printf rather than echo: armored key material is multi-line, and
          # printf's behavior does not vary with the shell's echo semantics.
          printf '%s\n' "$KEY" | gpg --batch --import

          # The passphrase goes to a 0600 file rather than into each gpg
          # command's argv, matching Task 1. Process arguments are readable
          # through ps and /proc by anything else on the machine. The runner
          # is ephemeral and single-tenant, so the practical exposure here is
          # far smaller than on the maintainer's laptop, but the cost of doing
          # it properly is one line and the inconsistency was its own smell.
          umask 077
          printf '%s' "$PASSPHRASE" > "$RUNNER_TEMP/gpg-pass"

      - name: Sign the APT metadata
        run: |
          set -euo pipefail
          for suite in stable beta; do
            gpg --batch --yes --pinentry-mode loopback \
              --passphrase-file "$RUNNER_TEMP/gpg-pass" \
              --clearsign -o "_site/apt/dists/$suite/InRelease" \
              "_site/apt/dists/$suite/Release"
            gpg --batch --yes --pinentry-mode loopback \
              --passphrase-file "$RUNNER_TEMP/gpg-pass" \
              -abs -o "_site/apt/dists/$suite/Release.gpg" \
              "_site/apt/dists/$suite/Release"
          done

      - name: Sign the DNF metadata
        run: |
          set -euo pipefail
          for suite in stable beta; do
            gpg --batch --yes --pinentry-mode loopback \
              --passphrase-file "$RUNNER_TEMP/gpg-pass" \
              --detach-sign --armor \
              -o "_site/rpm/$suite/repodata/repomd.xml.asc" \
              "_site/rpm/$suite/repodata/repomd.xml"
          done

      # Proves the repository is installable before it replaces the live one.
      - name: Verify apt can read the repository
        run: |
          set -euo pipefail
          docker run --rm -v "$PWD/_site:/site:ro" debian:12 bash -c '
            # pipefail matters for the apt-cache pipeline below: without it
            # a failed apt-cache is masked by tee succeeding. Note this is a
            # standalone pipeline, where set -e plus pipefail does abort; in
            # an if condition a failing pipeline would merely read as false.
            set -euxo pipefail
            apt-get update -qq && apt-get install -y -qq ca-certificates > /dev/null
            cp /site/submersion.gpg /usr/share/keyrings/submersion.gpg
            echo "deb [signed-by=/usr/share/keyrings/submersion.gpg] file:///site/apt stable main" \
              > /etc/apt/sources.list.d/submersion.list
            apt-get update -o Dir::Etc::sourcelist=/etc/apt/sources.list.d/submersion.list \
              -o Dir::Etc::sourceparts=/dev/null
            # "Candidate: (none)" is what apt prints when the package is
            # not installable, and it contains the word Candidate, so a bare
            # grep for it passes on a broken repository. Assert the candidate
            # is real, then prove the dependencies resolve.
            apt-cache policy submersion | tee /tmp/policy
            if grep -q "Candidate: (none)" /tmp/policy; then
              echo "repository offers no installable candidate"
              exit 1
            fi
            apt-get install -y --dry-run submersion
          '

      - uses: actions/upload-pages-artifact@v3
        with:
          path: _site

      - id: deploy
        uses: actions/deploy-pages@v4
```

- [ ] **Step 2: Verify with a manual dispatch**

Run the workflow by hand and confirm it deploys, then from a Debian container:

```bash
docker run --rm debian:12 bash -c '
  set -eu
  apt-get update -qq && apt-get install -y -qq curl ca-certificates gnupg > /dev/null
  # Downloaded and then run, never piped into sh. A failed curl writes
  # nothing and sh exits 0 on an empty script, so the pipeline would report
  # a successful enrollment over a repository that was never added.
  curl -fsSL https://packages.submersion.app/setup.sh -o /tmp/setup.sh
  sh /tmp/setup.sh
  apt-get install -y submersion
  submersion --version
'
```

Expected: the version prints. This is the end-to-end proof that the whole
chain works.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/publish-linux-repo.yml
git commit -m "ci(linux-repo): publishing workflow for the package repositories"
```

---

### Task 7: Dispatch a publish from the release workflows

**Files:**
- Modify: `.github/workflows/release.yml`, `beta.yml`, `promote.yml`

**Interfaces:**
- Consumes: `LINUX_REPO_DISPATCH_TOKEN` from Task 1.

- [ ] **Step 1: Add the dispatch step**

At the end of each workflow's publishing job, after the release exists:

```yaml
      # The repository publisher reconciles nightly as well, so a failure here
      # delays updates by hours rather than losing them. Non-blocking for the
      # same reason: a release that is published must not be marked failed
      # because a downstream index did not refresh.
      - name: Ask the Linux repository to republish
        continue-on-error: true
        env:
          GH_TOKEN: ${{ secrets.LINUX_REPO_DISPATCH_TOKEN }}
        run: |
          gh api repos/submersion-app/linux-packages/dispatches \
            -f event_type=publish-packages
```

- [ ] **Step 2: Verify the token scope**

```bash
GH_TOKEN=<the PAT> gh api repos/submersion-app/linux-packages/dispatches \
  -f event_type=publish-packages
```

Expected: HTTP 204 and a run appears. A 403 means the PAT lacks Contents: write
on that repository.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/release.yml .github/workflows/beta.yml \
  .github/workflows/promote.yml
git commit -m "ci: ask the Linux repository to republish after a release"
```

---

### Task 8: Self-enrollment and RPM signing in the packages

**Files:**
- Modify: `scripts/release/stage_linux_package.py`
- Modify: `scripts/release/stage_linux_package_test.py`
- Modify: `scripts/release/build_linux_packages.sh`
- Modify: `.github/workflows/build-all.yml`

**Interfaces:**
- Consumes: the public key from Task 1 and the site paths from Task 5.

- [ ] **Step 1: Write the failing tests**

Extend `stage_linux_package_test.py`:

```python
class SelfEnrollmentTest(unittest.TestCase):
    def test_deb_ships_the_sources_file_and_keyring(self):
        # A direct .deb download must keep receiving updates, or most
        # direct-download users run one version forever.
        self.assertTrue(os.path.isfile(
            ".../usr/share/keyrings/submersion.gpg"))
        self.assertTrue(os.path.isfile(
            ".../etc/apt/sources.list.d/submersion.list"))

    def test_deb_sources_file_pins_the_keyring(self):
        self.assertIn("signed-by=/usr/share/keyrings/submersion.gpg", text)

    def test_rpm_ships_the_yum_repo_drop_in(self):
        self.assertTrue(os.path.isfile(".../etc/yum.repos.d/submersion.repo"))

    def test_rpm_repo_drop_in_enables_signature_checking(self):
        self.assertIn("gpgcheck=1", text)
        self.assertIn("repo_gpgcheck=1", text)

    def test_deb_does_not_ship_the_rpm_drop_in_or_the_reverse(self):
        ...

    def test_enrollment_targets_the_stable_suite(self):
        # A package that enrolled users in beta would push prereleases to
        # everyone who downloaded a stable .deb.
        self.assertIn(" stable main", text)
```

- [ ] **Step 2: Run the tests to verify they fail**

- [ ] **Step 3: Implement self-enrollment**

`stage_linux_package.py` gains, per install method:

- `deb`: `/usr/share/keyrings/submersion.gpg` and
  `/etc/apt/sources.list.d/submersion.list`
- `rpm`: `/etc/yum.repos.d/submersion.repo`

Both point at the `stable` suite. The package description gains a sentence
saying the repository is added and how to remove it.

- [ ] **Step 4: Sign the RPM at build time**

`build_linux_packages.sh` gains an optional `--sign-key-id`; when set, it runs
`rpmsign --addsign` on the built RPM with a loopback pinentry. `build-all.yml`
imports the key from secrets and passes the id. When the secret is absent, as
in `ci.yaml` on a fork PR, signing is skipped and the build still succeeds.

- [ ] **Step 5: Run the tests to verify they pass**

- [ ] **Step 6: Commit**

```bash
git add scripts/release lib .github/workflows/build-all.yml
git commit -m "feat(linux): self-enroll packaged installs in the update repository"
```

---

### Task 9: Document enrollment

**Files:**
- Modify: `README.md`, `docs/guide/installation.md`
- Modify: `docs/developer/release-secrets-setup.md`

- [ ] **Step 1: Lead the install docs with the repository**

Both install sections gain the repository as the recommended path, above the
direct download, with the manual commands spelled out alongside `setup.sh` so
nobody has to pipe a script to a shell to enroll.

State plainly, in both places, that the `.deb` and `.rpm` add the repository
when installed directly, and give the two-line removal.

- [ ] **Step 2: Verify no em-dashes**

```bash
# The pattern is built from UTF-8 bytes rather than written literally, so this
# file does not itself contain the character it forbids.
EMDASH=$(printf '\xe2\x80\x94')
grep -n "$EMDASH" README.md docs/guide/installation.md \
  docs/developer/release-secrets-setup.md && echo "FOUND" || echo "clean"
```

- [ ] **Step 3: Commit**

```bash
git add README.md docs/guide/installation.md \
  docs/developer/release-secrets-setup.md
git commit -m "docs: document Linux repository enrollment"
```

---

## Final Verification

- [ ] **Run every script test suite**

```bash
for t in scripts/release/linux_repo/*_test.py; do python3 "$t" || exit 1; done
python3 scripts/release/stage_linux_package_test.py
```

- [ ] **Run the Dart suite once, unpiped**

```bash
flutter test
```

- [ ] **End-to-end enrollment from a clean container**

```bash
docker run --rm debian:12 bash -c '
  set -eu
  apt-get update -qq && apt-get install -y -qq curl ca-certificates gnupg > /dev/null
  curl -fsSL https://packages.submersion.app/setup.sh -o /tmp/setup.sh
  sh /tmp/setup.sh
  apt-get install -y submersion && submersion --version'
docker run --rm fedora:latest bash -c '
  set -eu
  curl -fsSL https://packages.submersion.app/submersion.repo -o /tmp/repo.in
  sed s/@CHANNEL@/stable/ /tmp/repo.in > /etc/yum.repos.d/submersion.repo
  dnf install -y submersion && submersion --version'
```

- [ ] **Verify an upgrade actually upgrades**

Install the older of the two retained versions, then `apt update && apt upgrade`
and confirm it moves to the newer one. This is the behavior the whole phase
exists to provide, and nothing else tests it.

- [ ] **Confirm the beta suite is separate**

Enroll a container in `beta` and confirm it offers the beta version while a
`stable` container does not.
