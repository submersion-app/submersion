# Media Sync Phase 1, Slice 5: Store Errors Carry the Server's Reason Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A failed transfer tells the user what the provider actually said, on every adapter, instead of a bare HTTP status.

**Architecture:** Two changes and two tripwires. `MediaStoreException.toString()` stops dropping its own `cause`, which is where three adapters already put the provider's explanation. The S3 client's catch-all folds the error body's `Code` and `Message` into the message it throws, the way the Drive adapter already does. Dropbox and iCloud need no change, and tests pin why.

**Tech Stack:** Flutter, `http`, `xml`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-18-media-sync-program-design.md`, section 5.3 (the Google Drive bullet).

## Global Constraints

- **Branch:** `ericgriffin/media-sync-s5-store-errors`, cut from `main`. This slice shares no files with slices 3 and 4, so it does not stack on them.
- **No schema change.** This slice claims no rung.
- **No em-dashes (U+2014) in any output**: code, comments, commit messages, docs. En-dashes and " - " as prose punctuation are equally forbidden.
- **No emojis** in code, comments, or documentation.
- **TDD**: every behaviour gets a failing test first; each task names the run and the expected result.
- Run `dart format .` before every commit and gate the commit on `flutter analyze` exiting zero (`flutter analyze >/dev/null 2>&1 && git commit ...`); piping it to `tail` hides the exit code.
- Commit messages carry no `Co-Authored-By` line, no tool name and no session URL. The PR body says `Part of #2090` and `Refs #2103`.

---

## What the audit found

The Drive half of this slice is already on main: `_forStatus` folds Google's
`error.message` in, shipped as PR #2019, and #2018 is closed. What section
5.3 calls for and has not happened is the audit of the other three adapters.
Two real gaps, one non-finding:

- **Every adapter loses its `cause`.** `MediaStoreException.toString()` prints
  only `kind` and `message`. The transfer queue stores that string in
  `errorMessage`, and the Transfers page and the media health report both
  read it, so anything an adapter put in `cause` never reaches the person
  looking at the failure. Dropbox puts its `error_summary` there. Both the S3
  and Dropbox media stores put the whole underlying `CloudStorageException`
  there. Every adapter puts the `FileSystemException` there on a read
  failure.
- **The S3 client's catch-all drops the body it already parsed.**
  `_throwFor` reads the XML `<Code>` to recognise four specific failures,
  then throws `S3 <op> failed for "<key>" (HTTP <status>)` for everything
  else, discarding both that `Code` and the `<Message>` beside it. That is
  the same shape as the Drive bug in #2018.
- **Dropbox and iCloud need no change.** `DropboxApiClient._errorSummary`
  already extracts `error_summary` and falls back to a truncated body; its
  problem is only the `toString` above. iCloud is filesystem-backed: there is
  no server and no body, and its failures already carry the
  `FileSystemException` as a cause, which the same `toString` fix surfaces.

## File Structure

| Path | Change | Responsibility |
| --- | --- | --- |
| `lib/core/services/media_store/media_object_store.dart` | Modify | `toString()` appends a bounded `cause`. |
| `lib/core/services/cloud_storage/s3/s3_api_client.dart` | Modify | `_throwFor`'s catch-all carries the XML `Code` and `Message`. |
| `test/core/services/media_store/media_store_exception_test.dart` | Create | What `toString` shows, and what it truncates. |
| `test/core/services/cloud_storage/s3/s3_error_body_test.dart` | Create | The catch-all carries the body; a bad body degrades to the status. |
| `test/core/services/media_store/adapter_error_audit_test.dart` | Create | Tripwires for Dropbox and iCloud, with the reason each needs nothing. |

---

### Task 1: The exception stops hiding its cause

**Files:**
- Modify: `lib/core/services/media_store/media_object_store.dart`
- Create: `test/core/services/media_store/media_store_exception_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: no signature change. `MediaStoreException(message, kind:, cause:)` is unchanged; only `toString()` widens.

**Why a bound:** a cause can be an HTML error page from a proxy, and this
string is written to a database column, rendered in a list tile and pasted
into bug reports. Dropbox already truncates its own body summary to 200
characters; match that.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/services/media_store/media_store_exception_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/media_store/media_object_store.dart';

/// The queue stores `toString()` in `errorMessage`, and the Transfers page
/// and the media health report both read that column, so anything an
/// adapter puts in `cause` is invisible until it appears here.
void main() {
  test('the cause is shown', () {
    const e = MediaStoreException(
      'Dropbox request failed (400)',
      kind: MediaStoreErrorKind.fatal,
      cause: 'path/not_found/...',
    );

    expect(e.toString(), contains('Dropbox request failed (400)'));
    expect(e.toString(), contains('path/not_found/...'));
  });

  test('no cause reads exactly as before', () {
    const e = MediaStoreException(
      'cannot read source for k',
      kind: MediaStoreErrorKind.fatal,
    );

    expect(e.toString(), 'MediaStoreException(fatal): cannot read source for k');
  });

  test('a long cause is bounded', () {
    final e = MediaStoreException(
      'put k failed',
      kind: MediaStoreErrorKind.fatal,
      cause: '<html>${'x' * 5000}</html>',
    );

    expect(e.toString().length, lessThan(400));
  });

  test('a cause that adds nothing is not repeated', () {
    // A wrapped exception whose own toString is already the message would
    // otherwise print twice.
    const e = MediaStoreException(
      'put k failed: Access denied.',
      kind: MediaStoreErrorKind.auth,
      cause: 'Access denied.',
    );

    expect('Access denied.'.allMatches(e.toString()).length, 1);
  });
}
```

`allMatches` is on `Pattern`, so write it as `'Access denied.'.allMatches(...)`.

- [ ] **Step 2: Run to verify the failures**

Run: `flutter test test/core/services/media_store/media_store_exception_test.dart`
Expected: the first, third and fourth cases FAIL (the cause is absent, so there is nothing to bound or de-duplicate); the second passes.

- [ ] **Step 3: Implement**

```dart
  @override
  String toString() {
    final base = 'MediaStoreException(${kind.name}): $message';
    final detail = cause?.toString();
    // The queue stores this string and the Transfers page shows it, so the
    // provider's own explanation has to be in it: Dropbox puts its
    // error_summary in the cause, the S3 and Dropbox stores put the whole
    // underlying CloudStorageException there, and every adapter puts the
    // FileSystemException there on a read failure (#2018 was the same gap
    // one layer up, on Drive).
    //
    // Bounded, because a cause can be an HTML error page from a proxy and
    // this lands in a database column and a list tile. Skipped when the
    // message already contains it, which happens wherever a mapper folded
    // the cause's text in before wrapping it.
    if (detail == null || detail.isEmpty || message.contains(detail)) {
      return base;
    }
    final trimmed = detail.length <= 200 ? detail : '${detail.substring(0, 200)}...';
    return '$base (cause: $trimmed)';
  }
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/core/services/media_store/ test/features/media_store/`
Expected: PASS. If a test asserts an exact `toString()` for an exception that
carries a cause, it was pinning the hidden-cause behaviour; read it and widen
the assertion to `contains`.

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze >/dev/null 2>&1 && git add lib/core/services/media_store/media_object_store.dart test/core/services/media_store/media_store_exception_test.dart && git commit -m "fix(media-store): show the cause in a store exception

The queue stores toString() in errorMessage and the Transfers page and the
media health report both read it, so the explanation an adapter put in the
cause never reached the person looking at the failure. Dropbox puts its
error_summary there, the S3 and Dropbox stores put the underlying
CloudStorageException there, and every adapter puts the FileSystemException
there on a read failure. Bounded, because a cause can be an HTML error page.

Part of #2090, refs #2103"
```

---

### Task 2: The S3 catch-all carries the body it already read

**Files:**
- Modify: `lib/core/services/cloud_storage/s3/s3_api_client.dart` (`_throwFor`)
- Create: `test/core/services/cloud_storage/s3/s3_error_body_test.dart`

**Interfaces:**
- Consumes: the existing `_xmlElementText(String, String)` helper in the same file.
- Produces: no signature change to `_throwFor`.

- [ ] **Step 1: Write the failing test**

Drive the client through a `MockClient` that returns a real S3 error body.
Build the client the way `s3_api_client_test.dart` does (copy its config and
constructor call rather than inventing a second shape).

```dart
    test('a rejected request carries S3 Code and Message', () async {
      final client = clientReturning(
        400,
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<Error><Code>InvalidRequest</Code>'
        '<Message>Multipart uploads are not supported here</Message>'
        '</Error>',
      );

      expect(
        () => client.putObject('k', Uint8List.fromList([1])),
        throwsA(
          isA<CloudStorageException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('InvalidRequest'),
              contains('Multipart uploads are not supported here'),
            ),
          ),
        ),
      );
    });

    test('an unparseable body degrades to the bare status', () async {
      final client = clientReturning(502, '<html>bad gateway</html>');

      expect(
        () => client.putObject('k', Uint8List.fromList([1])),
        throwsA(
          isA<CloudStorageException>().having(
            (e) => e.message,
            'message',
            allOf(contains('502'), isNot(contains('html'))),
          ),
        ),
      );
    });
```

- [ ] **Step 2: Run to verify the failure**

Run: `flutter test test/core/services/cloud_storage/s3/s3_error_body_test.dart`
Expected: the first case FAILS (the message is the bare status); the second passes already.

- [ ] **Step 3: Implement**

Replace the final throw in `_throwFor`:

```dart
    // The Code was parsed above to recognise four specific failures;
    // everything else used to discard it along with the Message beside it,
    // which is the gap #2018 fixed on Drive. S3 error bodies are
    // `<Error><Code>..</Code><Message>..</Message></Error>`, and a body that
    // is not that shape (an HTML page from a proxy, an empty body) degrades
    // to the bare status the caller already had.
    final detail = [
      if (errorCode != null) errorCode,
      ?_xmlElementText(
        utf8.decode(response.bodyBytes, allowMalformed: true),
        'Message',
      ),
    ].join(': ');
    throw CloudStorageException(
      'S3 $operation failed for "$key" (HTTP ${response.statusCode})'
      '${detail.isEmpty ? '' : ': $detail'}',
    );
```

If the analyzer rejects the `?` null-aware element (it needs a recent SDK),
write it with an explicit local and an `if (message != null)` instead; do not
change the behaviour to match the syntax.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/core/services/cloud_storage/s3/`
Expected: PASS. A test asserting the exact catch-all string was pinning the
bare status; widen it to `contains`.

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze >/dev/null 2>&1 && git add lib/core/services/cloud_storage/s3/s3_api_client.dart test/core/services/cloud_storage/s3/s3_error_body_test.dart && git commit -m "fix(s3): carry the error body's Code and Message, not just the status

_throwFor already parsed the XML Code to recognise four specific failures
and then threw it away for everything else, along with the Message beside
it, so a rejected upload read as a bare HTTP status. Same gap as #2018 on
Drive. A body that is not that shape still degrades to the status.

Part of #2090, refs #2103"
```

---

### Task 3: Pin why Dropbox and iCloud need nothing

**Files:**
- Create: `test/core/services/media_store/adapter_error_audit_test.dart`

**Why:** section 5.3 asks for the audit, and an audit that changes no code
leaves no trace. These tests are the trace, and they fail with the reason if
either adapter loses the property.

- [ ] **Step 1: Write the tests**

One test that a Dropbox failure reaches `MediaStoreException.toString()` with
the `error_summary` in it, driven through `DropboxMediaObjectStore` with a
`MockClient` returning `{"error_summary": "path/not_found/..."}`. One test
that an iCloud read failure carries its `FileSystemException` as a cause and
so appears in `toString()`. Build both stores the way their existing tests do.

- [ ] **Step 2: Run**

Run: `flutter test test/core/services/media_store/adapter_error_audit_test.dart`
Expected: PASS once Task 1 is in. These are tripwires, not a change.

- [ ] **Step 3: Commit**

```bash
dart format .
flutter analyze >/dev/null 2>&1 && git add test/core/services/media_store/adapter_error_audit_test.dart && git commit -m "test(media-store): pin the Dropbox and iCloud error paths

The audit section 5.3 asks for, recorded as tests. Dropbox already extracts
error_summary and iCloud carries its FileSystemException; both only needed
the cause to stop being hidden.

Part of #2090, refs #2103"
```

---

### Task 4: Verify and open the PR

- [ ] **Step 1: Full affected run**

Run: `flutter test test/core/services/media_store test/core/services/cloud_storage test/features/media_store test/features/media`
Expected: PASS.

- [ ] **Step 2: Push and open the PR**

Base `main`. Body: the two gaps with their evidence, the note that the Drive
half shipped as #2019 and #2018 is already closed, and `Part of #2090` /
`Refs #2103`.

---

## Known limits (not in this slice)

- **The Transfers page still shows one line.** A long provider message is
  truncated by the tile, not by this change. Making the failure expandable is
  queue visibility work and belongs to slice 10.
- **No adapter gains a retry it did not have.** This slice changes what a
  failure says, never whether it is retried or how it is classified.

## Self-review against the spec

- **5.3 Google Drive `error.message`:** already on main (PR #2019), #2018
  closed. Recorded in "What the audit found" rather than re-done.
- **5.3 adapter audit:** Tasks 1 to 3. Two real gaps fixed, two adapters
  pinned as needing nothing.
- **Placeholders:** none. Task 2 names a syntax fallback if the analyzer
  rejects a null-aware element, and Task 3 says to copy each store's existing
  test construction rather than inventing one.
- **Type consistency:** `MediaStoreException`, `MediaStoreErrorKind`,
  `CloudStorageException`, `_throwFor`, `_xmlElementText`, `_errorSummary`
  are spelled the same in every task.

---

## Review follow-up (PR #2246)

Three gaps the review found after the tasks above landed. Each has a test
that goes red when its own fix alone is reverted.

- **The bound guarded the wrong half.** `MediaStoreException.toString()`
  caps `cause`, but `S3MediaObjectStore._map` splices the whole
  `CloudStorageException.message` into the media exception's *primary*
  message, which nothing caps. A 3500-character `<Message>` from an
  S3-compatible server reached `errorMessage` intact. `_throwFor` now bounds
  the `Code`/`Message` detail at the same 200 characters before composing
  the exception.
- **The wrapped cause printed twice.** `CloudStorageException.toString()`
  prefixes `CloudStorageException: `, so `message.contains(detail)` never
  matched on the S3 and Dropbox paths and the whole provider explanation was
  appended a second time. `_messageCarries` now also compares with a
  leading `ClassName: ` stripped.
- **403 still hid the provider's reason.** The catch-all gained the `Code`
  but the access-denied branch above it did not, so a provider that rejects
  a signature and one that denies a key read identically. The advice stays
  first, with the code appended, which keeps both the `contains('Access
  denied')` classification in `_map` and the settings-page snackbar test.

A fourth point from the same review, that the mapped S3 error could lose a
nested transport cause, did not reproduce. `_map` builds its message out of
`e.message`, which omits the cause, so the unprefixed detail still carries
the ` (HandshakeException: ...)` suffix the message lacks, the containment
check fails and the cause is appended. Pinned by "a nested transport cause
still reaches the string" so a later change to the suppression rule cannot
quietly drop it.

A later round found the same gap in the branches above the catch-all. The
403 path appended only the `Code`, so `AccessDenied` with a `Message` of
"user is disabled" reached the queue as the generic advice plus the code,
and the region branch dropped the `Message` that names the region its own
advice tells the person to go and find. `_throwFor` now decodes the body
once, parses `Code` and `Message` once, and every branch ends with the same
bounded detail in parentheses after its advice. A body that is not that
shape leaves each message exactly as it was, so the curated wording and the
`contains` assertions on it are unchanged.

That round introduced a regression the next one caught: the media stores
classify a failure by substring on `CloudStorageException.message`, so a 500
whose `Message` read "Access denied by policy" was filed as
`MediaStoreErrorKind.auth` and stopped being retried. The slice promises not
to change classification, and it did.

The fix is the shape the Dropbox client already threw: the provider's words
go in the `cause`, never in the `message`. `_throwFor` passes the bounded
detail as the cause and leaves each curated message alone, so the
classification input is exactly what it was before this slice. Both media
mappers now classify on `e.message` and build their wrapped message from
`e.displayMessage`, which folds the cause in, so the explanation still
reaches the queue, the Transfers page and the media health report, and the
cause is not then repeated after it.

The iCloud filesystem-cause test was also weaker than it looked. It asserted
on the key, which the message already carries, so it passed whether or not
the cause survived. It now asserts on the source file's own path, which only
the `FileSystemException` can supply, and goes red when the cause is
suppressed.

Routing the detail through `displayMessage` then exposed an unbounded path
of its own. Dropbox's `_errorSummary` capped the raw-body fallback at 200
characters but returned the structured `error_summary` untouched, and that
value is provider-controlled, so a 5000-character summary reached
`MediaStoreException.message`, the half nothing downstream bounds. Both
paths now go through one bound.

Auditing the rest of the S3 client for the same shape found one more:
`completeMultipartUpload` parses the `Code` out of a 200 body to notice the
upload failed at all, then threw it away. That is the slice's own gap, one
status class over. It now passes the same bounded detail as its cause, and
`_throwFor` and it share one `_bodyDetail` helper so a third site cannot
compose the rule differently.

Rendering the cause made `MediaStoreException.toString()` able to throw for
the first time, because `cause` is an arbitrary `Object?` whose own
`toString` may throw. That matters more than it looks: the upload pipeline
calls `toString` inside its catch to hand `markFailed` its text, and anything
that escapes that catch leaves the row `transferring`, which the drainer
never selects (#1270). The cause is now rendered through a guard that falls
back to `Error.safeToString`, the same fallback `CloudStorageException` uses
for its own cause. A pipeline test drives a store failure with an
unrenderable cause and asserts the row returns to `pending`; it goes red
with the guard removed.
