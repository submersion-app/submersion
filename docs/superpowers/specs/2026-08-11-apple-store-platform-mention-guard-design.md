# Apple App Store platform-mention guard

Date: 2026-08-11

## Problem

Apple App Review guideline 2.3.10 forbids references to other platforms in App
Store metadata. Two fields in App Store Connect are fed automatically from text
that routinely names Windows, Android, and Linux:

1. **App Store "What's New"** — `promote.yml` reads the GitHub release body with
   `gh release view ... -q .body`, truncates it, and writes
   `ios/fastlane/metadata/en-US/release_notes.txt` (copied to `macos/`). The
   `submit_existing` lane in both Fastfiles then uploads it with
   `skip_metadata: false`. The source text is the hand-written multi-platform
   release announcement.
2. **TestFlight "What to Test"** — `scripts/release/beta_release_notes.sh
   --format store` produces `beta-notes-store.txt`, which `beta.yml` hands to
   `beta_changelog` in the iOS and macOS Fastfiles as `BETA_CHANGELOG_FILE`. The
   source text is PR titles, which routinely carry scopes like `fix(android):`.

Every historical release note in `docs/releases/` contains at least one banned
term, frequently in headings, parentheticals, and mid-sentence clauses.

## Goal

No banned platform term reaches either Apple-bound field, without changing the
multi-platform text those fields are derived from.

## Non-goals

- `docs/releases/*.md` are not linted. They are the ScubaBoard announcements and
  should keep naming every platform.
- GitHub release bodies are not rewritten. Only the copy piped into
  `release_notes.txt` is sanitized.
- Google Play release notes (`--format play`) are untouched. Android is not a
  banned term there.
- The GitHub beta release body (`--format markdown`) is untouched and keeps
  internal work.
- The Sparkle appcast and `release-notes.html` are untouched. They serve the
  direct-download DMG and EXE, not App Store Connect.
- App Store description, keywords, and subtitle are untouched. They are never
  uploaded; every lane other than `submit_existing` passes `skip_metadata: true`.

### Accepted asymmetry

macOS ships through both the Mac App Store (sanitized) and the direct-download
DMG via Sparkle (not sanitized). The same version will have two differently
worded bodies. This is intended.

## Design

### 1. The sanitizer

`scripts/release/sanitize_apple_store_notes.py` — reads stdin, writes sanitized
text to stdout, all diagnostics to **stderr**.

Stdout purity is a hard requirement. `generate_changelog.sh` previously wrote
progress to stdout and embedded `Changelog: ...` lines in every published beta
release body.

Term list lives in `scripts/release/apple_store_banned_terms.json` so the Python
sanitizer and the Ruby backstop cannot drift apart.

#### Term table

| Pattern | Case | Class |
| --- | --- | --- |
| `Windows` | sensitive | platform |
| `Android`, `Linux` | insensitive | platform |
| `Ubuntu`, `Debian`, `Flatpak`, `AppImage` | insensitive | platform |
| `apt` / `apt-get` followed by `install` or `update` | insensitive | platform |
| `PC`, `PCs`, `Microsoft`, `Microsoft Store` | sensitive | platform |
| `.exe`, `MSI`, `.msi` | mixed | platform |
| `Google Play`, `Play Store` | insensitive | store |

All patterns are word-bounded.

`Windows`, `PC`, and `Microsoft` are matched **case-sensitively**. In every file
under `docs/releases/`, capitalized `Windows` is the operating system and
lowercase `window`/`windows` is a UI window or a time window ("a two-column
layout on wide windows", "the planner gets the whole window", "photos plainly
inside the dive window", "falls only across the windows where it is"). Case
sensitivity yields zero false positives across the entire historical corpus. The
cost is that a lowercase typo meaning the OS is not caught; that is accepted.

`apt` is narrowed to command context so that the ordinary English adjective
survives.

`APK` is deliberately **not** in the list.

#### Passes

Applied in order.

**Pass 0 — normalize.** CRLF to LF. This moves out of `promote.yml`, so both
callers get it.

**Pass 1 — list repair.** Find runs of the form `A, B, C, and D`, `A, B and C`,
`A and B`, or `A, B` where every member is at most three words and at least one
member is entirely a banned term. Drop the banned members and rebuild:

| Members surviving | Result |
| --- | --- |
| 3 or more | `A, B, and C` (Oxford comma) |
| 2 | `A and B` |
| 1 | `A` |
| 0 | `other platforms`; a parenthetical that contained only the list is deleted |

Worked examples:

- `(macOS, Windows, Linux, and Android)` becomes `(macOS)`
- `Mac, Windows, and Linux` becomes `Mac`
- `iOS, Android, macOS, Windows, and Linux` becomes `iOS and macOS`

The three-word member cap prevents the pattern from consuming ordinary prose
that happens to contain commas and `and`.

**Pass 2 — preposition-aware replacement** of terms that survived pass 1.

| Context | Replacement |
| --- | --- |
| `on`/`for`/`in` + term | preposition + `other platforms` |
| term + `'s` | `other platforms'` |
| sentence-initial | `Other platforms` |
| anything else | `other platforms` |

Store-class terms map to `another store` instead of `other platforms`.

**Pass 3 — tidy.** Collapse adjacent duplicate `other platforms`; `, )` to `)`;
delete emptied parentheses and brackets; collapse double spaces; ` ,` to `,`.

**Pass 4 — assert clean.** Re-scan the output against the same term table. Any
survivor exits non-zero with the offending line on stderr.

This is **fatal, not a warning**. It can only fire on a sanitizer bug, never on
bad input content, because passes 1 and 2 are total over the term table. A red
job is preferable to shipping a 2.3.10 violation.

**Pass 5 — never empty.** If the result is blank or whitespace, emit the
`--fallback` text. A blank whatsNew reads to a tester as "the previous build's
notes still apply", and `promote.yml`'s `test -s` would fail the job regardless.

#### Interface

```
sanitize_apple_store_notes.py [--fallback TEXT] [--report] < in > out
```

`--report` prints a before/after line for every redaction to stderr. Because the
guard never blocks on content, the CI log is the only place a human can see what
was silently changed.

#### Fallback text

`--fallback` has no default; omitting it means an empty result stays empty and
the caller decides. The two callers supply:

- **App Store "What's New"**: `This release includes bug fixes and
  improvements.` A blank file would fail `promote.yml`'s existing `test -s`.
- **TestFlight**: no `--fallback`. Sanitization runs per item, so emptiness is
  handled at the item level (below) and the script's existing non-empty
  guarantees still apply.

### 2. Rename `--format store` to `--format apple`

`beta_release_notes.sh`'s three formats map one-to-one onto channels, and the
`store` name is as misleading as the sanitizer's original name was:
`beta-notes-store.txt` is consumed **only** by the iOS and macOS TestFlight jobs
(`beta.yml:322`, `beta.yml:388`). Google Play reads `beta-notes-play.txt`
(`beta.yml:457`) and the GitHub release reads `beta-notes.md` (`beta.yml:188`).

Hard rename, no alias:

- `beta_release_notes.sh`: the `--format` validation case, the usage header,
  `STORE_LIMIT` to `APPLE_LIMIT`, and the limit selection at line 309
- `beta.yml`: line 132 invocation, and `beta-notes-store.txt` to
  `beta-notes-apple.txt` at lines 133, 139, 147, 322, 388
- `beta_release_notes_test.sh`: 16 `--format store` call sites
- `fastlane_beta_changelog_test.rb`: the `beta-notes-store.txt` fixture name

`--format store` stops working. Any local invocation must be updated.

### 3. Integration

**App Store "What's New"** — `promote.yml`, the "Prepare What's New" step. Insert
the sanitizer into the pipe between `gh release view` and the 3900-character
truncation, so the character budget is computed on the final text. The inline
CRLF normalization is removed, since pass 0 covers it.

**TestFlight "What to Test"** — `beta_release_notes.sh`, inside `add_section`,
gated on `[ "$FORMAT" = apple ]`. Sanitizing here rather than on the finished
string is required: the body is assembled item by item and then truncated against
a hard character budget with dangling-heading repair. Sanitizing afterwards would
invalidate the budget arithmetic and could re-orphan a heading.

Sanitization runs on the item list passed as `add_section`'s second argument,
**before** the existing `[ -n "$2" ] || return 0` guard, so a section whose every
item sanitized away is skipped entirely rather than emitting a bare heading. An
individual item that reduces to nothing, or to only the replacement phrase with
no remaining content, is dropped from the list. If every section ends up empty,
`$LINES` is empty and the script's existing "internal changes only" / "matches
the previous build" fallback fires unchanged.

A comment at the gate records that `apple` means Apple's stores only and that
`play` must not be sanitized.

**Ruby backstop** — `beta_changelog` in `ios/fastlane/Fastfile:97` and
`macos/fastlane/Fastfile:52` runs a regex sweep loaded from
`apple_store_banned_terms.json`, applied after `read_beta_notes` and before the
4000-character truncation. This is a last resort for a local `fastlane` run with
a hand-set `BETA_CHANGELOG` that never passed through the shell script. It does
list repair only in its simplest form; the Python sanitizer remains the quality
path.

`release.yml` needs no change. It never writes `release_notes.txt`, and the
`release`, `upload_only`, and `upload_screenshots` lanes all pass
`skip_metadata: true`.

## Testing

`scripts/release/sanitize_apple_store_notes_test.py`, registered in `ci.yaml`'s
`script-tests` job alongside the existing Python guard tests and included in the
coverage set:

- one case per term group, covering platform-class and store-class replacements
- negative cases drawn from real prose: `wide windows`, `the whole window`,
  `photos plainly inside the dive window`, `the windows where it is`, and `an apt
  description` all pass through byte-identical
- list repair at 4, 3, 2, 1, and 0 surviving members, with and without enclosing
  parentheses
- preposition, possessive, and sentence-initial replacement forms
- idempotence: `sanitize(sanitize(x)) == sanitize(x)`
- empty input and sanitizes-to-empty both produce the fallback
- `--report` writes to stderr and leaves stdout unchanged
- pass 4 exits non-zero when handed text the earlier passes are stubbed to miss
- **corpus test**: every `docs/releases/*.md` is run through the sanitizer and
  asserted to contain zero surviving matches. This is the real input
  distribution and is the test most likely to expose a gap.

`beta_release_notes_test.sh`: an `--format apple` case asserting a banned term in
a PR title is redacted; `--format play` and `--format markdown` cases asserting
the same title passes through untouched; a case where every item sanitizes away
and the existing empty-body fallback fires; and a case asserting `--format store`
is now rejected as an unknown format.

`fastlane_beta_changelog_test.rb`: a case asserting the Ruby backstop redacts a
banned term supplied through `BETA_CHANGELOG` with no file present.

## Known limitations

- **Counts go stale.** `on all five platforms (iOS, Android, macOS, Windows, and
  Linux)` becomes `on all five platforms (iOS and macOS)`. Not automatically
  fixable.
- **Dangling clauses.** `On Android this works through the USB Host API` becomes
  `On other platforms this works through the USB Host API`, which is a
  non-sequitur to an Apple reader. This is the accepted cost of word-level
  redaction over block-level removal.
- **Lowercase `windows` meaning the OS is not caught**, by design.
