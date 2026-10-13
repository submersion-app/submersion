# Shared site libraries: privacy, signing, encryption and backup. Implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep notes and rating private, guide storage setup, give each library its own keys, sign every edit with owner-approved keys, encrypt libraries on demand, and let owners back up and restore a library.

**Architecture:** Signing and encryption sit in two thin layers around the existing per-site document sync: `LibrarySigner` and `RolesTrust` decide which remote fields and roles a device accepts, and `LibraryCipher` seals and opens every non-manifest file inside `SharedLibraryTransport`. Keys ride on the existing synced `shared_library_memberships` rows. Backups are zips of the library's stored files, kept on the device and in a `backups/` folder of the library.

**Tech Stack:** Flutter, Drift, Riverpod 3, `cryptography` (Ed25519, AES-GCM, Argon2id, HKDF), the existing `SyncEnvelope` and `Keyslots`, `archive` (zip), `share_plus` and `file_picker` (export and import).

**Spec:** [docs/design/specs/2026-10-12-shared-site-library-security-and-backup-design.md](../specs/2026-10-12-shared-site-library-security-and-backup-design.md), building on [the base design](../specs/2026-10-12-shared-dive-site-library-design.md).

## Global Constraints

- The feature is a "shared site library". The earlier organisation word appears nowhere in this feature: strings, identifiers, comments, routes, test names, docs. Unrelated older uses elsewhere stay.
- No em dashes or en-dash punctuation anywhere; no emojis; no AI-tool attribution in commits or PR text.
- Every user-facing string goes in all eleven ARB files (en, ar, de, es, fr, he, hu, it, nl, pt, zh), then `flutter gen-l10n`.
- Paths built with `p.join`; tests restore any global state they replace.
- Before each commit: `dart format .`, `flutter analyze`, the task's tests, and `test/architecture` plus `test/shared` when a file under `lib/` was added.
- Stage explicit paths. CRLF files stay CRLF (`site_filter_sheet.dart`, `site_map_content.dart`; check `git diff --numstat` after any scripted edit).
- Library format version becomes 2; version 1 libraries are refused (the feature has not shipped).
- Signing: Ed25519. Encryption: SBE1 envelopes (AES-256-GCM) with the file's path inside the library as associated data, data key = HKDF(library key, `ssl:v1:data`). KDF: Argon2id defaults of `KdfParams`.
- Fingerprint: first 16 hex digits of SHA-256 of the public key, upper case, groups of four.
- Automatic backups: at most daily, skipped when a storage backup is under 20 hours old, newest 7 unpinned kept per location.
- Commits follow build-feature follow-up rules: `feat(shared-library): ...` or `fix(shared-library): ...`.

## Rulings (the spec's data model now says the same)

1. **Keys on membership rows, not new tables.** The spec lists two new synced tables. The per-profile member id already lives on `shared_library_memberships` and is derived from any of the profile's rows (`SharedLibraryStore.memberIdForDiver`). The signing key pair and the library key go in four nullable columns there (`signing_public_key`, `signing_private_key`, `library_key_id`, `library_key`), so personal sync carries them with no new serializer arms. Cost if wrong: one more migration later.
2. **The v289 helper grows instead of a new rung.** v289 has never shipped; `_assertSharedLibrarySchema` is idempotent and re-run by `beforeOpen`, so new columns and the backups table are added there. Developer databases already at 290 pick them up through the backstop. Avoids a rung race with main. Cost if wrong: a rung added later.
3. **`rolesJson` holds the trusted roles.** The existing column becomes the last trusted `roles.json`; new device-local columns `roles_rejected` (bool) and `pending_roles_json` (a reset awaiting an answer) carry the warning and the prompt.
4. **Incoming key columns never erase local keys.** Personal sync applies whole rows; a membership row written by a device that had no key yet must not null the key on others. `upsertMembership` coalesces, and the sync apply keeps local non-null key columns against an incoming null (as `_keepLibrarySiteLinks` does for site links).

## Review Focus

1. A profile's second device writes its membership row before the key arrives: the key must survive personal sync (Task 8 test "a keyless row never erases a key").
2. A restoring owner whose device clock is behind every stamp in the library: restored fields must still win (Task 21 test "restore wins with a slow clock").
3. Encryption switched on while a member is mid-sync: the member's late plain upload is converted by the next owner sync (Task 17 test "a late plain upload is converted").
4. An approval arriving after a pending member's edits were skipped: those edits must apply without the member editing again (Task 11 test "approval re-reads held edits").
5. A large library's first verification: 500 sites must verify in under 10 s (Task 11 benchmark test).

---
## Part A: the smaller changes

### Task 1: One name

**Files:**
- Create: `test/architecture/shared_library_naming_test.dart`
- Modify: every file this PR added lines to that names the earlier word (list with the command in Step 3), including `lib/core/router/app_router.dart` (route paths and names) and both existing design docs
- Test: `test/architecture/shared_library_naming_test.dart`

**Interfaces:**
- Produces: routes `/settings/shared-libraries`, `/settings/shared-libraries/connect`, `/settings/shared-libraries/:libraryId`, `.../members`, `.../suggestions`; route names `sharedLibraries`, `sharedLibraryConnect`, `sharedLibrary`, `sharedLibraryMembers`, `sharedLibrarySuggestions`.

- [ ] **Step 1: Write the failing guard test**

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// The feature is a "shared site library" (issue #2567): the earlier
/// organisation word never appears in its code, tests, routes, strings or
/// docs. Unrelated older uses elsewhere in the app are not scanned.
void main() {
  final banned = RegExp('cl' 'ub', caseSensitive: false);
  final roots = [
    p.join('lib', 'core', 'services', 'shared_library'),
    p.join('lib', 'features', 'shared_library'),
    p.join('test', 'core', 'services', 'shared_library'),
    p.join('test', 'features', 'shared_library'),
  ];
  final docs = [
    p.join('docs', 'design', 'specs', '2026-10-12-shared-dive-site-library-design.md'),
    p.join('docs', 'design', 'plans', '2026-10-12-shared-dive-site-library.md'),
    p.join('docs', 'design', 'specs', '2026-10-12-shared-site-library-security-and-backup-design.md'),
    p.join('docs', 'design', 'plans', '2026-10-12-shared-site-library-security-and-backup.md'),
  ];

  test('feature files never use the earlier name', () {
    final hits = <String>[];
    for (final root in roots) {
      for (final f in Directory(root).listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (banned.hasMatch(lines[i])) hits.add('${f.path}:${i + 1}');
        }
      }
    }
    for (final d in docs) {
      final lines = File(d).readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (banned.hasMatch(lines[i])) hits.add('$d:${i + 1}');
      }
    }
    expect(hits, isEmpty);
  });

  test('shared library strings never use the earlier name', () {
    final hits = <String>[];
    for (final f in Directory(p.join('lib', 'l10n', 'arb')).listSync()) {
      if (f is! File || !f.path.endsWith('.arb')) continue;
      final json = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      for (final e in json.entries) {
        if (!e.key.startsWith('sharedLibrary_')) continue;
        if (banned.hasMatch('${e.value}')) hits.add('${f.path}:${e.key}');
      }
    }
    expect(hits, isEmpty);
  });

  test('routes use shared-libraries', () {
    final router = File(p.join('lib', 'core', 'router', 'app_router.dart'))
        .readAsStringSync();
    expect(banned.hasMatch(router.replaceAll(RegExp(r'//.*'), '')), isFalse);
  });
}
```

(The banned word is split as `'cl' 'ub'` so this test file passes its own scan if it is ever moved under a scanned root.)

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/architecture/shared_library_naming_test.dart`
Expected: FAIL, listing many feature files and the router.

- [ ] **Step 3: Rename on the lines this PR added**

The earlier word is written `<w>` below; in shell commands it is `$W`, set first with `W=cl; W="${W}ub"` so this plan never spells it.

List the files: `git diff origin/main...HEAD --name-only | xargs grep -li "$W" | grep -v '\.g\.dart'`.
For each, replace only on lines this PR added (`git diff origin/main...HEAD -U0 -- <file>` gives the line ranges), so unrelated older uses (species names, dive centre search text, certification providers) stay. Mapping, applied in this order, then every remaining hit rewritten by hand to read naturally:

| From | To |
| --- | --- |
| `<w> libraries` (either case) | `shared site libraries` |
| `<w> library` (either case) | `shared site library` |
| `<w> site`, `<w> sites` | `library site`, `library sites` |
| route path `<w>-libraries` | `shared-libraries` |
| route names `<w>Libraries`, `<w>LibraryConnect`, `<w>Library`, `<w>LibraryMembers`, `<w>LibrarySuggestions` | `sharedLibraries`, `sharedLibraryConnect`, `sharedLibrary`, `sharedLibraryMembers`, `sharedLibrarySuggestions` |
| test data names and prefixes built on `<w>` (library names, folder prefixes, `<w>A`, the access key ending in `<W>`) | `'Reef Survey'`, `'site-sync'`, `'site-sync/'`, `libraryA`, `AKIALIBRARY` |
| `the <w>` in prose | `the library's members` or `the people running the storage`, by context |

Every `context.push`/`go` and test path naming the old route moves too (`grep -rn "$W-libraries" lib test`).

- [ ] **Step 4: Run the guard, analyzer and the moved tests**

Run: `flutter test test/architecture/shared_library_naming_test.dart && flutter analyze && flutter test test/core/services/shared_library test/features/shared_library test/features/dive_sites test/core/services/sync`
Expected: PASS; `git diff origin/main...HEAD -U0 | grep '^+' | grep -ic "$W"` prints 0.

- [ ] **Step 5: Commit**

`git commit -m "fix(shared-library): use the shared site library name everywhere"` (explicit paths).

### Task 2: Notes and rating stay private

**Files:**
- Modify: `lib/core/services/shared_library/site_document.dart` (`fieldNames`, `fromJson`)
- Modify: `lib/core/services/shared_library/suggestion_service.dart`, `lib/features/dive_sites/presentation/utils/suggestion_child_fields.dart` if either lists fields explicitly
- Test: `test/core/services/shared_library/site_document_test.dart`, `test/core/services/shared_library/site_document_bridge_test.dart`, `test/core/services/shared_library/shared_library_service_test.dart`

**Interfaces:**
- Produces: `SiteDocument.privateFields` = `{'notes', 'rating'}`; `fieldNames` no longer contains them.

- [ ] **Step 1: Write the failing tests**

In `site_document_test.dart`:

```dart
test('notes and rating are never part of a document', () {
  expect(SiteDocument.fieldNames, isNot(contains('notes')));
  expect(SiteDocument.fieldNames, isNot(contains('rating')));
  final doc = SiteDocument.fromJson({
    'id': 's1',
    'fields': {'name': 'A', 'notes': 'mine', 'rating': 5},
    'clocks': {},
  });
  expect(doc.fields.keys, ['name']);
});
```

In `site_document_bridge_test.dart`:

```dart
test('a library site keeps its own notes and rating', () async {
  await SiteRepository().createSite(
    const DiveSite(id: 's1', name: 'A', notes: 'mine', rating: 4, sharedLibraryId: 'L'),
  );
  final doc = await SiteDocumentBridge().build('s1', const SharedSiteState(siteId: 's1', libraryId: 'L'));
  expect(doc.fields.containsKey('notes'), isFalse);
  expect(doc.fields.containsKey('rating'), isFalse);
  await SiteDocumentBridge().apply(
    doc.copyWith(fields: {...doc.fields, 'name': 'B'}),
    libraryId: 'L',
    vocabularyDiverId: 'd1',
    fields: {'name'},
  );
  final site = await SiteRepository().getSiteById('s1');
  expect(site!.notes, 'mine');
  expect(site.rating, 4);
});
```

In `shared_library_service_test.dart`, a pull of a document from an older build that still carries `notes` must leave the local notes alone:

```dart
test('a remote document carrying notes does not touch local notes', () async {
  // seed a library site with local notes, upload, then rewrite the remote
  // file with 'notes': 'theirs' and a newer clock, and sync again.
  // expect the local site's notes to still be 'mine'.
});
```

(Write it with the file's existing helpers `_seedLibrary`, `_member` and `cloud.seedFile`; the assertion is `expect((await SiteRepository().getSiteById('s1'))!.notes, 'mine')`.)

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/core/services/shared_library/site_document_test.dart test/core/services/shared_library/site_document_bridge_test.dart test/core/services/shared_library/shared_library_service_test.dart`
Expected: FAIL on the three new tests.

- [ ] **Step 3: Implement**

In `site_document.dart` remove `'rating'` and `'notes'` from `fieldNames`, add:

```dart
  /// The member's own: kept on the library site row, never uploaded
  /// (issue #2567), and dropped from documents written by older builds.
  static const Set<String> privateFields = {'notes', 'rating'};
```

and in `fromJson` build `fields` as:

```dart
      fields: rawFields is Map
          ? {
              for (final e in rawFields.entries)
                if (!privateFields.contains(e.key)) '${e.key}': e.value,
            }
          : const {},
```

The bridge builds and applies only `fieldNames`, so no bridge change is needed; if `suggestion_child_fields.dart` or the suggestion diff list fields by hand, remove `notes` and `rating` there.

- [ ] **Step 4: Run them to see them pass, plus the library suites**

Run: `flutter test test/core/services/shared_library test/features/shared_library test/features/dive_sites`
Expected: PASS.

- [ ] **Step 5: Commit**

`git commit -m "feat(shared-library): keep notes and rating private on library sites"`

### Task 3: Confirm before adding a site

**Files:**
- Create: `lib/features/shared_library/presentation/widgets/add_to_library_confirmation.dart`
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page.dart:750-760`, `lib/features/dive_sites/presentation/widgets/site_list_content.dart:1330-1345`, `lib/features/shared_library/presentation/pages/shared_library_page.dart:255-270` (each calls `confirmAddToLibrary` after picking the library and before `publisher.push`)
- Modify: 11 ARB files
- Test: `test/features/shared_library/presentation/widgets/add_to_library_confirmation_test.dart`, `test/features/dive_sites/presentation/pages/site_detail_library_actions_test.dart`

**Interfaces:**
- Produces: `Future<bool> confirmAddToLibrary(BuildContext context, {required String libraryName, required int siteCount, String? siteName})`.
- l10n: `sharedLibrary_add_confirm_title` ("Add {name} to {library}?"), `sharedLibrary_add_confirm_titleMany` ("Add {count} sites to {library}?"), `sharedLibrary_add_confirm_shared` ("Every member will see: name, location, depths, description, hazards, access, entry and exit, mooring, parking, site types, tags, species and features."), `sharedLibrary_add_confirm_private` ("Stays yours: your notes and rating. Dives and photos never leave your personal library."), `sharedLibrary_add_confirm_action` ("Add").

- [ ] **Step 1: Write the failing widget test**

```dart
testWidgets('lists what is shared and what stays private', (tester) async {
  bool? answer;
  await tester.pumpWidget(testApp(
    locale: const Locale('en'),
    child: Builder(builder: (context) => TextButton(
      onPressed: () async => answer = await confirmAddToLibrary(
        context, libraryName: 'Reef Survey', siteCount: 1, siteName: 'Blue Hole'),
      child: const Text('go'),
    )),
  ));
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
  expect(find.text('Add Blue Hole to Reef Survey?'), findsOneWidget);
  expect(find.textContaining('your notes and rating'), findsOneWidget);
  await tester.tap(find.text('Add'));
  await tester.pumpAndSettle();
  expect(answer, isTrue);
});
```

and in `site_detail_library_actions_test.dart`, that cancelling the confirmation never calls the publisher (the existing fake publisher records pushes): `expect(publisher.pushes, isEmpty)`.

- [ ] **Step 2: Run to see it fail** (`flutter test` on both files; Expected: FAIL, missing function and text).

- [ ] **Step 3: Implement**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Before a personal site joins a shared site library (issue #2567): what
/// every member will see, and what stays the diver's own.
Future<bool> confirmAddToLibrary(
  BuildContext context, {
  required String libraryName,
  required int siteCount,
  String? siteName,
}) async {
  final l10n = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        siteCount == 1 && siteName != null
            ? l10n.sharedLibrary_add_confirm_title(siteName, libraryName)
            : l10n.sharedLibrary_add_confirm_titleMany(siteCount, libraryName),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.sharedLibrary_add_confirm_shared),
          const SizedBox(height: 12),
          Text(l10n.sharedLibrary_add_confirm_private),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(MaterialLocalizations.of(dialogContext).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.sharedLibrary_add_confirm_action),
        ),
      ],
    ),
  );
  return ok ?? false;
}
```

Call it at the three push sites right after the library id is chosen, resolving the library name from the store (`ref.read(sharedLibraryStoreProvider).getLibrary(libraryId)`), and return early on `false`. Add the five strings to all eleven ARB files and run `flutter gen-l10n`.

- [ ] **Step 4: Run tests** (both files plus `test/features/shared_library`; Expected: PASS).

- [ ] **Step 5: Commit** `feat(shared-library): confirm what is shared before adding a site`

### Task 4: Separate keys per library

**Files:**
- Modify: `lib/core/services/shared_library/library_account_setup.dart`
- Modify: `lib/core/services/shared_library/shared_library_transport.dart` (`isValidPrefix` refuses a reserved first segment)
- Modify: `lib/features/shared_library/presentation/pages/connect_shared_library_page.dart` (folder field first; saves pass the folder)
- Modify: 11 ARB files (`sharedLibrary_connect_reservedFolder`: "A library folder cannot start with sites, members, suggestions or backups.")
- Test: `test/core/services/shared_library/library_account_setup_test.dart`, `test/core/services/shared_library/shared_library_transport_test.dart`, `test/features/shared_library/presentation/pages/connect_shared_library_page_test.dart`

**Interfaces:**
- Produces: `Future<ConnectedAccount> saveS3(S3Config server, {required String folder})`, `Future<ConnectedAccount> saveWebDav(WebDavConfig server, {required String folder})`; `SharedLibraryLayout.reservedFolders` = `{'sites', 'members', 'suggestions', 'backups'}`; `SharedLibraryTransport.isValidPrefix` returns false for a reserved first segment.

- [ ] **Step 1: Write the failing tests**

```dart
test('two libraries on one bucket keep separate keys', () async {
  final a = await setup.saveS3(s3(key: 'AKIAONE'), folder: 'reef');
  final b = await setup.saveS3(s3(key: 'AKIATWO'), folder: 'wrecks');
  expect(a.id, isNot(b.id));
  final ka = jsonDecode((await credentials.read(a.id))!) as Map;
  final kb = jsonDecode((await credentials.read(b.id))!) as Map;
  expect(ka['accessKeyId'], 'AKIAONE');
  expect(kb['accessKeyId'], 'AKIATWO');
  expect(ka['prefix'], 'submersion-sites/reef/');
  expect(a.label, 'submersion-sync @ s3.eu-west-1.amazonaws.com (submersion-sites/reef)');
});
```

```dart
test('a folder starting with a library subfolder is refused', () {
  for (final bad in ['sites', 'members/x', 'suggestions', 'backups/old']) {
    expect(SharedLibraryTransport.isValidPrefix(bad), isFalse, reason: bad);
  }
  expect(SharedLibraryTransport.isValidPrefix('reef/sites'), isTrue);
});
```

Widget test: the folder field (`Key('library-prefix')`) is above the account dropdown, and Save account passes the typed folder (the recording setup records `folder`).

- [ ] **Step 2: Run to see them fail.**

- [ ] **Step 3: Implement**

`LibraryAccountSetup`:

```dart
  static String _libraryFolder(String folder) {
    final f = folder.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    return f.isEmpty
        ? SharedLibraryLayout.librariesDir
        : '${SharedLibraryLayout.librariesDir}/$f';
  }

  Future<domain.ConnectedAccount> saveS3(S3Config server, {required String folder}) async {
    final where = _libraryFolder(folder);
    final config = server.copyWith(prefix: '$where/');
    final account = await _accounts.ensure(
      kind: AccountKind.s3,
      naturalKey: s3NaturalKey(config),
      label: '${config.bucket} @ ${config.displayHost} ($where)',
    );
    await _credentials.write(account.id, jsonEncode(config.toJson()));
    return account;
  }
```

`saveWebDav` likewise with `folder: where` and label `'${config.displayLabel} ($where)'`; drop `_folderNote`. In the transport:

```dart
  static bool isValidPrefix(String prefix) {
    final segments = prefix.split('/').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (segments.any((s) => s == '.' || s == '..')) return false;
    return segments.isEmpty || !SharedLibraryLayout.reservedFolders.contains(segments.first);
  }
```

On the connect page move the folder `TextField` and its helper above the dropdown in both the list and the empty-state branches, pass `folder: _prefix.text.trim()` to both saves, and show `sharedLibrary_connect_reservedFolder` from `_runProbe` and `_saveAccount` when `isValidPrefix` fails on a reserved segment (keep the dot-segment message for `.` and `..`).

- [ ] **Step 4: Run tests** (the three files plus `test/features/shared_library`; Expected: PASS).

- [ ] **Step 5: Commit** `feat(shared-library): give every library its own storage keys`

### Task 5: Storage setup guide in the app

**Files:**
- Create: `lib/features/shared_library/presentation/widgets/storage_setup_sheet.dart`
- Create: `lib/features/shared_library/domain/storage_policy_examples.dart`
- Modify: `connect_shared_library_page.dart` (a "How to set up storage" `TextButton` under the folder field)
- Modify: 11 ARB files
- Test: `test/features/shared_library/presentation/widgets/storage_setup_sheet_test.dart`, `test/features/shared_library/domain/storage_policy_examples_test.dart`

**Interfaces:**
- Produces: `String s3FullAccessPolicy({required String bucket, required String folder})`, `String s3ReaderPolicy({required String bucket, required String folder})` (pretty JSON), `Future<void> showStorageSetupSheet(BuildContext context, {required String folder})`.
- l10n: `sharedLibrary_setup_action` ("How to set up storage"), `sharedLibrary_setup_title`, `sharedLibrary_setup_where` ("Libraries live in submersion-sites/<folder>/ at the top of the bucket or server."), `sharedLibrary_setup_keys` ("Give owners and editors keys that read and write the library folder. Give everyone else keys that read the library folder and write only members/ and suggestions/."), `sharedLibrary_setup_s3Full`, `sharedLibrary_setup_s3Reader`, `sharedLibrary_setup_webdav` ("WebDAV: share the folder read-only with readers, and members/ and suggestions/ writable where your server allows it (Nextcloud share permissions)."), `sharedLibrary_setup_copy` ("Copy"), `sharedLibrary_setup_copied` ("Policy copied").

- [ ] **Step 1: Write the failing tests**

```dart
test('the reader policy writes only members and suggestions', () {
  final json = jsonDecode(s3ReaderPolicy(bucket: 'b', folder: 'reef')) as Map;
  final statements = (json['Statement'] as List).cast<Map>();
  final put = statements.firstWhere((s) => (s['Action'] as List).contains('s3:PutObject'));
  expect(put['Resource'], [
    'arn:aws:s3:::b/submersion-sites/reef/members/*',
    'arn:aws:s3:::b/submersion-sites/reef/suggestions/*',
  ]);
  final list = statements.firstWhere((s) => (s['Action'] as List).contains('s3:ListBucket'));
  expect(list['Condition'], {'StringLike': {'s3:prefix': ['submersion-sites/reef/*']}});
});

test('the full policy reads and writes the library folder', () {
  final json = jsonDecode(s3FullAccessPolicy(bucket: 'b', folder: 'reef')) as Map;
  final rw = (json['Statement'] as List).cast<Map>().firstWhere(
    (s) => (s['Action'] as List).contains('s3:DeleteObject'));
  expect(rw['Resource'], ['arn:aws:s3:::b/submersion-sites/reef/*']);
});
```

Widget test: tapping "How to set up storage" opens the sheet; tapping the reader policy's Copy puts JSON containing `submersion-sites/reef/members/*` on the clipboard (mock `SystemChannels.platform` `Clipboard.setData` with `tester.binding.defaultBinaryMessenger.setMockMethodCallHandler`, cleared in `addTearDown`).

- [ ] **Step 2: Run to see them fail.**

- [ ] **Step 3: Implement**

```dart
import 'dart:convert';

String _prefixOf(String folder) {
  final f = folder.trim().replaceAll(RegExp(r'^/+|/+$'), '');
  return f.isEmpty ? 'submersion-sites/' : 'submersion-sites/$f/';
}

const _encoder = JsonEncoder.withIndent('  ');

/// Owners and editors: read and write everything in the library folder.
String s3FullAccessPolicy({required String bucket, required String folder}) {
  final prefix = _prefixOf(folder);
  return _encoder.convert({
    'Version': '2012-10-17',
    'Statement': [
      {
        'Effect': 'Allow',
        'Action': ['s3:ListBucket'],
        'Resource': ['arn:aws:s3:::$bucket'],
        'Condition': {'StringLike': {'s3:prefix': ['$prefix*']}},
      },
      {
        'Effect': 'Allow',
        'Action': ['s3:GetObject', 's3:PutObject', 's3:DeleteObject'],
        'Resource': ['arn:aws:s3:::$bucket/$prefix*'],
      },
    ],
  });
}

/// Readers: read the library folder, write only their card and suggestions.
String s3ReaderPolicy({required String bucket, required String folder}) {
  final prefix = _prefixOf(folder);
  return _encoder.convert({
    'Version': '2012-10-17',
    'Statement': [
      {
        'Effect': 'Allow',
        'Action': ['s3:ListBucket'],
        'Resource': ['arn:aws:s3:::$bucket'],
        'Condition': {'StringLike': {'s3:prefix': ['$prefix*']}},
      },
      {
        'Effect': 'Allow',
        'Action': ['s3:GetObject'],
        'Resource': ['arn:aws:s3:::$bucket/$prefix*'],
      },
      {
        'Effect': 'Allow',
        'Action': ['s3:PutObject', 's3:DeleteObject'],
        'Resource': [
          'arn:aws:s3:::$bucket/${prefix}members/*',
          'arn:aws:s3:::$bucket/${prefix}suggestions/*',
        ],
      },
    ],
  });
}
```

`showStorageSetupSheet` is a `showModalBottomSheet(isScrollControlled: true)` with a `ListView`: the where and keys paragraphs, then for each policy a title, a `SelectableText` in a monospace `Container`, and a Copy `TextButton.icon` calling `Clipboard.setData` and a `SnackBar(sharedLibrary_setup_copied)`; then the WebDAV paragraph. The bucket placeholder is the selected S3 account's bucket when one is selected, else `your-bucket`.

- [ ] **Step 4: Run tests** (Expected: PASS).

- [ ] **Step 5: Commit** `feat(shared-library): show how to set up the storage`

### Task 6: Schema for keys, trust and backups

**Files:**
- Modify: `lib/core/database/tables/shared_library_tables.dart`
- Modify: `lib/core/database/migrations/helpers/shared_library_migrations.dart`
- Modify: `lib/core/database/database.dart` (register `SharedLibraryBackups` in `@DriftDatabase(tables: ...)`)
- Regenerate: Drift codegen (`codegen.sh` in the scratchpad: `dart run build_runner build --delete-conflicting-outputs`)
- Test: `test/core/database/shared_library_schema_test.dart`

**Interfaces:**
- Produces columns: `shared_library_memberships.signing_public_key`, `signing_private_key`, `library_key_id`, `library_key` (nullable TEXT, base64); `shared_libraries.roles_rejected` (BOOL default false), `pending_roles_json` (TEXT null), `encrypted` (BOOL default false), `key_id` (TEXT null), `last_auto_backup_at` (INT null); table `shared_library_backups` (`backup_id` TEXT PK, `library_id` TEXT, `created_at` INT, `note` TEXT default '', `pinned` BOOL default false, `automatic` BOOL default false, `site_count` INT, `member_count` INT, `size_bytes` INT, `local_path` TEXT null, `in_storage` BOOL default false, `before_restore` BOOL default false).

- [ ] **Step 1: Write the failing schema test**

```dart
test('v289 carries keys, trust state and backups', () async {
  final db = await createTestDatabase();
  final cols = (String t) async => (await db.customSelect("PRAGMA table_info('$t')").get())
      .map((r) => r.read<String>('name')).toSet();
  expect(await cols('shared_library_memberships'),
      containsAll(['signing_public_key', 'signing_private_key', 'library_key_id', 'library_key']));
  expect(await cols('shared_libraries'),
      containsAll(['roles_rejected', 'pending_roles_json', 'encrypted', 'key_id', 'last_auto_backup_at']));
  expect(await cols('shared_library_backups'), contains('backup_id'));
});

test('a database already at 290 gains them through the backstop', () async {
  // open a v290 database built without the new columns (drop them via
  // a fixture created with the old helper), reopen, and expect the columns.
});
```

(The second test follows the file's existing "backstop" pattern: create the old tables with raw DDL, set `user_version = 290`, open, assert.)

- [ ] **Step 2: Run to see them fail.**

- [ ] **Step 3: Implement**

Tables: add the columns as nullable `text()` / `boolean().withDefault(const Constant(false))()` / `integer().nullable()()` with doc comments, and:

```dart
/// An owner's library backup known to this device (issue #2567).
/// Device-local: the storage copy has its own index.
@DataClassName('SharedLibraryBackupRow')
class SharedLibraryBackups extends Table {
  TextColumn get backupId => text()();
  TextColumn get libraryId => text()();
  IntColumn get createdAt => integer()();
  TextColumn get note => text().withDefault(const Constant(''))();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  BoolColumn get automatic => boolean().withDefault(const Constant(false))();
  BoolColumn get beforeRestore => boolean().withDefault(const Constant(false))();
  IntColumn get siteCount => integer().withDefault(const Constant(0))();
  IntColumn get memberCount => integer().withDefault(const Constant(0))();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();
  TextColumn get localPath => text().nullable()();
  BoolColumn get inStorage => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {backupId};
}
```

Helper: add `sharedLibraryBackups` to the table list and a column pass:

```dart
    Future<void> addColumns(String table, Map<String, String> columns) async {
      final rows = await customSelect("PRAGMA table_info('$table')").get();
      if (rows.isEmpty) return;
      final have = rows.map((c) => c.read<String>('name')).toSet();
      for (final e in columns.entries) {
        if (!have.contains(e.key)) {
          await customStatement('ALTER TABLE $table ADD COLUMN ${e.key} ${e.value}');
        }
      }
    }

    await addColumns('shared_library_memberships', {
      'signing_public_key': 'TEXT',
      'signing_private_key': 'TEXT',
      'library_key_id': 'TEXT',
      'library_key': 'TEXT',
    });
    await addColumns('shared_libraries', {
      'roles_rejected': 'INTEGER NOT NULL DEFAULT 0 CHECK (roles_rejected IN (0, 1))',
      'pending_roles_json': 'TEXT',
      'encrypted': 'INTEGER NOT NULL DEFAULT 0 CHECK (encrypted IN (0, 1))',
      'key_id': 'TEXT',
      'last_auto_backup_at': 'INTEGER',
    });
```

Update the rung comment in `rungs_v231_onward.dart` and the backstop comment to say the helper also carries these (Ruling 2). Regenerate Drift code.

- [ ] **Step 4: Run** `flutter test test/core/database` (Expected: PASS) and `flutter analyze`.

- [ ] **Step 5: Commit** `feat(shared-library): store keys, role trust and backups`

---
## Part B: signed edits and owner approval

### Task 7: Signing primitives

**Files:**
- Create: `lib/core/services/shared_library/crypto/canonical_json.dart`
- Create: `lib/core/services/shared_library/crypto/library_signer.dart`
- Create: `lib/core/services/shared_library/crypto/library_recovery.dart`
- Test: `test/core/services/shared_library/crypto/canonical_json_test.dart`, `library_signer_test.dart`, `library_recovery_test.dart`

**Interfaces:**
- Produces:
  - `String canonicalJson(Object? value)`: map keys sorted at every depth, no whitespace, numbers as `jsonEncode` writes them.
  - `String sha256Hex(List<int> bytes)`.
  - `class LibrarySigningKey { final String publicKey; final String privateKey; }` (base64; `privateKey` is the 32-byte Ed25519 seed).
  - `abstract final class LibrarySigner { static Future<LibrarySigningKey> generate(); static Future<LibrarySigningKey> fromSeed(List<int> seed); static Future<String> sign(LibrarySigningKey key, List<int> message); static Future<bool> verify({required String publicKey, required List<int> message, required String? signature}); static String fingerprint(String publicKey); }`
  - `class LibraryRecoveryKey { final String code; final LibrarySigningKey key; final String salt; final KdfParams kdf; Map<String, dynamic> toRolesJson(); }` and `abstract final class LibraryRecovery { static Future<LibraryRecoveryKey> create({KdfParams kdf}); static Future<LibrarySigningKey> derive({required String code, required String salt, required KdfParams kdf}); }`

- [ ] **Step 1: Write the failing tests**

```dart
test('canonical JSON sorts keys at every depth', () {
  expect(canonicalJson({'b': 1, 'a': {'d': [3, {'f': 1, 'e': 2}], 'c': null}}),
      '{"a":{"c":null,"d":[3,{"e":2,"f":1}]},"b":1}');
});

test('a signature verifies only for its key and message', () async {
  final key = await LibrarySigner.generate();
  final other = await LibrarySigner.generate();
  final sig = await LibrarySigner.sign(key, utf8.encode('hello'));
  expect(await LibrarySigner.verify(publicKey: key.publicKey, message: utf8.encode('hello'), signature: sig), isTrue);
  expect(await LibrarySigner.verify(publicKey: key.publicKey, message: utf8.encode('hellO'), signature: sig), isFalse);
  expect(await LibrarySigner.verify(publicKey: other.publicKey, message: utf8.encode('hello'), signature: sig), isFalse);
  expect(await LibrarySigner.verify(publicKey: key.publicKey, message: utf8.encode('hello'), signature: null), isFalse);
  expect(await LibrarySigner.verify(publicKey: key.publicKey, message: utf8.encode('hello'), signature: 'not base64!'), isFalse);
});

test('a key rebuilt from its seed is the same key', () async {
  final key = await LibrarySigner.generate();
  final again = await LibrarySigner.fromSeed(base64Decode(key.privateKey));
  expect(again.publicKey, key.publicKey);
});

test('fingerprints are four groups of four upper-case hex digits', () async {
  final key = await LibrarySigner.generate();
  expect(LibrarySigner.fingerprint(key.publicKey), matches(RegExp(r'^[0-9A-F]{4}( [0-9A-F]{4}){3}$')));
});

test('a recovery code derives the same signing key', () async {
  const fast = KdfParams(m: 1024, t: 1);
  final made = await LibraryRecovery.create(kdf: fast);
  final again = await LibraryRecovery.derive(code: made.code, salt: made.salt, kdf: fast);
  expect(again.publicKey, made.key.publicKey);
  final spaced = made.code.toUpperCase().replaceAll(' ', '  ');
  expect((await LibraryRecovery.derive(code: spaced, salt: made.salt, kdf: fast)).publicKey, made.key.publicKey);
});
```

- [ ] **Step 2: Run to see them fail** (Expected: missing files).

- [ ] **Step 3: Implement**

```dart
// canonical_json.dart
import 'dart:convert';

import 'package:crypto/crypto.dart';

/// JSON with map keys sorted at every depth and no whitespace: the bytes a
/// signature covers (issue #2567), identical on every device.
String canonicalJson(Object? value) => jsonEncode(_sorted(value));

Object? _sorted(Object? v) {
  if (v is Map) {
    final keys = v.keys.map((k) => '$k').toList()..sort();
    return {for (final k in keys) k: _sorted(v[k])};
  }
  if (v is List) return [for (final e in v) _sorted(e)];
  return v;
}

String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();
```

```dart
// library_signer.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hash;
import 'package:cryptography/cryptography.dart';

/// A member's Ed25519 key pair, base64 (issue #2567). The private half is
/// the 32-byte seed.
class LibrarySigningKey {
  const LibrarySigningKey({required this.publicKey, required this.privateKey});

  final String publicKey;
  final String privateKey;
}

abstract final class LibrarySigner {
  static final _ed = Ed25519();

  static Future<LibrarySigningKey> generate() async => _from(await _ed.newKeyPair());

  static Future<LibrarySigningKey> fromSeed(List<int> seed) async =>
      _from(await _ed.newKeyPairFromSeed(seed));

  static Future<LibrarySigningKey> _from(SimpleKeyPair pair) async => LibrarySigningKey(
    publicKey: base64Encode((await pair.extractPublicKey()).bytes),
    privateKey: base64Encode(await pair.extractPrivateKeyBytes()),
  );

  static Future<String> sign(LibrarySigningKey key, List<int> message) async {
    final pair = await _ed.newKeyPairFromSeed(base64Decode(key.privateKey));
    final sig = await _ed.sign(message, keyPair: pair);
    return base64Encode(sig.bytes);
  }

  /// False for a missing, malformed or wrong signature: an unverifiable
  /// edit is treated exactly like a forged one.
  static Future<bool> verify({
    required String publicKey,
    required List<int> message,
    required String? signature,
  }) async {
    if (signature == null) return false;
    try {
      final pub = SimplePublicKey(base64Decode(publicKey), type: KeyPairType.ed25519);
      return await _ed.verify(message, signature: Signature(base64Decode(signature), publicKey: pub));
    } on FormatException {
      return false;
    } on ArgumentError {
      return false;
    }
  }

  static String fingerprint(String publicKey) {
    final hex = hash.sha256.convert(base64Decode(publicKey)).toString().substring(0, 16).toUpperCase();
    return [for (var i = 0; i < 16; i += 4) hex.substring(i, i + 4)].join(' ');
  }
}
```

```dart
// library_recovery.dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/crypto/recovery_code.dart';

/// The library recovery code and the owner-level signing key it stands for
/// (issue #2567). The key lives on no device: the code becomes it only when
/// typed in.
class LibraryRecoveryKey {
  const LibraryRecoveryKey({required this.code, required this.key, required this.salt, required this.kdf});

  final String code;
  final LibrarySigningKey key;
  final String salt;
  final KdfParams kdf;

  Map<String, dynamic> toRolesJson() => {'publicKey': key.publicKey, 'salt': salt, 'kdf': kdf.toJson()};
}

abstract final class LibraryRecovery {
  static Future<LibraryRecoveryKey> create({KdfParams kdf = const KdfParams()}) async {
    final code = RecoveryCode.generate();
    final r = Random.secure();
    final salt = base64Encode(Uint8List.fromList([for (var i = 0; i < 16; i++) r.nextInt(256)]));
    return LibraryRecoveryKey(code: code, key: await derive(code: code, salt: salt, kdf: kdf), salt: salt, kdf: kdf);
  }

  static Future<LibrarySigningKey> derive({required String code, required String salt, required KdfParams kdf}) async {
    final seed = await Keyslots.deriveKek(
      secret: RecoveryCode.normalize(code),
      salt: base64Decode(salt),
      kdf: kdf,
    );
    return LibrarySigner.fromSeed(await seed.extractBytes());
  }
}
```

- [ ] **Step 4: Run tests** (Expected: PASS).

- [ ] **Step 5: Commit** `feat(shared-library): add signing and recovery keys`

### Task 8: One signing key per profile, carried by personal sync

**Files:**
- Modify: `lib/core/services/shared_library/shared_library_models.dart` (`SharedLibraryMembership` gains `signingKey` (`LibrarySigningKey?`), `libraryKeyId`, `libraryKey`)
- Modify: `lib/core/services/shared_library/shared_library_store.dart` (`upsertMembership` coalesces key columns; new `signingKeyForDiver`, `setSigningKeyForDiver`, `setLibraryKey`)
- Modify: `lib/core/services/sync/sync_service.dart` (`_keepLibraryMembershipKeys`, beside `_keepLibrarySiteLinks`)
- Modify: `lib/core/services/shared_library/shared_library_membership_service.dart` (`create` and `join` call `ensureSigningKey`)
- Test: `test/core/services/shared_library/shared_library_store_test.dart`, `test/core/services/sync/shared_library_membership_sync_test.dart`

**Interfaces:**
- Produces: `Future<LibrarySigningKey?> signingKeyForDiver(String diverId)`, `Future<LibrarySigningKey> ensureSigningKey(String diverId)` (store; returns the profile's key from any membership row, or generates one and writes it to every row of the profile), `Future<void> setLibraryKey({required String diverId, required String libraryId, String? keyId, String? key})`.

- [ ] **Step 1: Write the failing tests**

```dart
test('a profile has one signing key across its memberships', () async {
  await store.upsertMembership(_m('m1', libraryId: 'A'));
  final key = await store.ensureSigningKey('d1');
  await store.upsertMembership(_m('m2', libraryId: 'B'));
  expect((await store.signingKeyForDiver('d1'))!.publicKey, key.publicKey);
  expect((await store.membership(diverId: 'd1', libraryId: 'B'))!.signingKey!.publicKey, key.publicKey);
});

test('a keyless row never erases a key', () async {
  await store.upsertMembership(_m('m1', libraryId: 'A'));
  final key = await store.ensureSigningKey('d1');
  await store.upsertMembership(_m('m1', libraryId: 'A')); // no key on the model
  expect((await store.signingKeyForDiver('d1'))!.publicKey, key.publicKey);
});
```

In `shared_library_membership_sync_test.dart`: an incoming synced membership row with null key columns, applied over a local row that has keys, keeps the local keys; an incoming row with keys fills a keyless local row.

- [ ] **Step 2: Run to see them fail.**

- [ ] **Step 3: Implement**

Store (sketch of the coalescing write; `_db` is the store's database):

```dart
  Future<void> upsertMembership(SharedLibraryMembership m) async {
    final existing = await (_db.select(_db.sharedLibraryMemberships)..where((t) => t.id.equals(m.id))).getSingleOrNull();
    final profileKey = m.signingKey ?? await signingKeyForDiver(m.diverId);
    // ...existing companion fields, plus:
    //   signingPublicKey: Value(profileKey?.publicKey ?? existing?.signingPublicKey),
    //   signingPrivateKey: Value(profileKey?.privateKey ?? existing?.signingPrivateKey),
    //   libraryKeyId: Value(m.libraryKeyId ?? existing?.libraryKeyId),
    //   libraryKey: Value(m.libraryKey ?? existing?.libraryKey),
  }

  Future<LibrarySigningKey?> signingKeyForDiver(String diverId) async {
    final row = await (_db.select(_db.sharedLibraryMemberships)
          ..where((t) => t.diverId.equals(diverId) & t.signingPrivateKey.isNotNull())
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;
    return LibrarySigningKey(publicKey: row.signingPublicKey!, privateKey: row.signingPrivateKey!);
  }

  Future<LibrarySigningKey> ensureSigningKey(String diverId) async {
    final have = await signingKeyForDiver(diverId);
    if (have != null) return have;
    final made = await LibrarySigner.generate();
    await (_db.update(_db.sharedLibraryMemberships)..where((t) => t.diverId.equals(diverId))).write(
      SharedLibraryMembershipsCompanion(
        signingPublicKey: Value(made.publicKey),
        signingPrivateKey: Value(made.privateKey),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
    await _markMembershipsPending(diverId); // the existing pending-HLC stamping used by upsertMembership
    return made;
  }
```

Clearing a library key on "encryption off" goes through `setLibraryKey(keyId: null, key: null)`, an explicit write that is the one path allowed to null those columns.

Sync service: in the apply path for `sharedLibraryMemberships` (the record loop at `sync_service.dart:1543`), before applying each record, if the local row has non-null `signingPrivateKey`/`libraryKey` and the incoming record's are null, copy the local values into the record, exactly as `_keepLibrarySiteLinks` does for `sharedLibraryId`. Name it `_keepLibraryMembershipKeys` with a doc comment saying why.

Membership service: `create` and `join` call `await _store.ensureSigningKey(diverId)` after `upsertMembership`.

- [ ] **Step 4: Run** `flutter test test/core/services/shared_library test/core/services/sync` (Expected: PASS).

- [ ] **Step 5: Commit** `feat(shared-library): give each profile a signing key`

### Task 9: Signed roles and the trust rules

**Files:**
- Modify: `lib/core/services/shared_library/shared_library_models.dart` (`SharedLibraryRoles` gains `version`, `approvedKeys`, `recovery`, `reset`, `signedBy`, `signature`; `RolesRecovery` value class)
- Create: `lib/core/services/shared_library/crypto/roles_trust.dart`
- Modify: `lib/core/services/shared_library/shared_library_store.dart` (`setLibraryStatus` gains `rolesRejected`, `pendingRoles`, `clearPendingRoles`)
- Modify: `lib/core/services/shared_library/shared_library_service.dart` (step 2 judges roles)
- Modify: `lib/core/services/shared_library/shared_library_membership_service.dart` (`create` returns `CreatedLibrary`, writes signed roles v1 with recovery; `join` trusts self-consistent roles; `setRole` signs version + 1)
- Modify: `connect_shared_library_page.dart` (shows the recovery code after Create in a dialog with Copy and "I have stored it")
- Modify: `shared_library_page.dart` (warning banner when `rolesRejected`)
- Modify: 11 ARB files (`sharedLibrary_recovery_title`, `sharedLibrary_recovery_body`, `sharedLibrary_recovery_stored`, `sharedLibrary_roles_rejected`)
- Test: `test/core/services/shared_library/crypto/roles_trust_test.dart`, `shared_library_membership_service_test.dart`, `shared_library_service_test.dart`, `connect_shared_library_page_test.dart`

**Interfaces:**
- Produces:
  - `SharedLibraryRoles.unsignedJson()` (everything but `signedBy`/`signature`), `Future<SharedLibraryRoles> SharedLibraryRoles.signed({required String signedBy, required LibrarySigningKey key})` (sets both), `SharedLibraryRoles copyWith({...})`.
  - `enum RolesVerdict { trusted, rejected, resetPending }`
  - `Future<RolesVerdict> judgeRoles({required SharedLibraryRoles trusted, required SharedLibraryRoles incoming})`
  - `Future<bool> isSelfConsistent(SharedLibraryRoles roles)`
  - `class CreatedLibrary { final SharedLibrary library; final String recoveryCode; }`
  - `SharedLibraryLayout.formatVersion = 2` (this task bumps it; Task 14 adds the refusal of 1).

- [ ] **Step 1: Write the failing trust tests**

```dart
late LibrarySigningKey owner, editor, stranger;
late LibraryRecoveryKey recovery;

setUpAll(() async {
  owner = await LibrarySigner.generate();
  editor = await LibrarySigner.generate();
  stranger = await LibrarySigner.generate();
  recovery = await LibraryRecovery.create(kdf: const KdfParams(m: 1024, t: 1));
});

Future<SharedLibraryRoles> v1() => SharedLibraryRoles(
  version: 1,
  owners: const {'o'},
  approvedKeys: {'o': owner.publicKey},
  recovery: RolesRecovery.fromJson(recovery.toRolesJson()),
).signed(signedBy: 'o', key: owner);

test('an owner can move the roles forward', () async {
  final trusted = await v1();
  final next = await trusted.copyWith(version: 2, editors: {'e'}, approvedKeys: {...trusted.approvedKeys, 'e': editor.publicKey})
      .signed(signedBy: 'o', key: owner);
  expect(await judgeRoles(trusted: trusted, incoming: next), RolesVerdict.trusted);
});

test('a rollback to an older signed version is refused', () async {
  final trusted = await (await v1()).copyWith(version: 5).signed(signedBy: 'o', key: owner);
  expect(await judgeRoles(trusted: trusted, incoming: await v1()), RolesVerdict.rejected);
});

test('someone who is not an owner cannot sign roles', () async {
  final trusted = await v1();
  final forged = await trusted.copyWith(version: 2, owners: {'o', 'x'}, approvedKeys: {...trusted.approvedKeys, 'x': stranger.publicKey})
      .signed(signedBy: 'x', key: stranger);
  expect(await judgeRoles(trusted: trusted, incoming: forged), RolesVerdict.rejected);
});

test('a tampered file fails its signature', () async {
  final trusted = await v1();
  final next = await trusted.copyWith(version: 2).signed(signedBy: 'o', key: owner);
  final tampered = next.copyWith(editors: {'x'}); // keeps the old signature
  expect(await judgeRoles(trusted: trusted, incoming: tampered), RolesVerdict.rejected);
});

test('the recovery key signs like an owner', () async {
  final trusted = await v1();
  final next = await trusted.copyWith(version: 2, owners: {'n'}, approvedKeys: {'n': stranger.publicKey})
      .signed(signedBy: 'recovery', key: recovery.key);
  expect(await judgeRoles(trusted: trusted, incoming: next), RolesVerdict.trusted);
});

test('a reset asks the member', () async {
  final trusted = await v1();
  final reset = await const SharedLibraryRoles(owners: {'n'}).copyWith(version: 2, reset: true, approvedKeys: {'n': stranger.publicKey})
      .signed(signedBy: 'n', key: stranger);
  expect(await judgeRoles(trusted: trusted, incoming: reset), RolesVerdict.resetPending);
});

test('a joining device trusts only self-consistent roles', () async {
  expect(await isSelfConsistent(await v1()), isTrue);
  final bogus = await (await v1()).copyWith(owners: {'x'}).signed(signedBy: 'o', key: owner);
  expect(await isSelfConsistent(bogus), isFalse); // 'o' signed but is no owner in it
});
```

Service tests: a sync that meets a `roles.json` signed by a non-owner keeps the trusted roles (`library.roles` unchanged) and sets `rolesRejected`; one signed by an owner replaces them and clears the flag. Membership tests: `create` returns a recovery code and writes roles v1 signed by the creator with `approvedKeys[me]` and `recovery`; `setRole` writes version + 1 signed by the acting owner.

- [ ] **Step 2: Run to see them fail.**

- [ ] **Step 3: Implement**

`roles_trust.dart`:

```dart
import 'dart:convert';

import 'package:submersion/core/services/shared_library/crypto/canonical_json.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';

enum RolesVerdict { trusted, rejected, resetPending }

/// The signer's key as [authority] knows it: an owner's approved key, or
/// the recovery key; null when [authority] gives the signer no right to
/// sign roles.
String? _signerKey(SharedLibraryRoles authority, String? signedBy) {
  if (signedBy == null) return null;
  if (signedBy == SharedLibraryRoles.recoverySigner) return authority.recovery?.publicKey;
  if (!authority.owners.contains(signedBy)) return null;
  return authority.approvedKeys[signedBy];
}

Future<bool> _verifiedBy(SharedLibraryRoles roles, String? key) async =>
    key != null &&
    await LibrarySigner.verify(
      publicKey: key,
      message: utf8.encode(canonicalJson(roles.unsignedJson())),
      signature: roles.signature,
    );

/// Whether [incoming] may replace [trusted] on this device (issue #2567).
Future<RolesVerdict> judgeRoles({
  required SharedLibraryRoles trusted,
  required SharedLibraryRoles incoming,
}) async {
  if (incoming.version > trusted.version &&
      await _verifiedBy(incoming, _signerKey(trusted, incoming.signedBy))) {
    return RolesVerdict.trusted;
  }
  if (incoming.reset && await isSelfConsistent(incoming)) {
    return RolesVerdict.resetPending;
  }
  return RolesVerdict.rejected;
}

/// Signed by an owner or the recovery key of the same file: what a joining
/// device, with nothing trusted yet, accepts.
Future<bool> isSelfConsistent(SharedLibraryRoles roles) =>
    _verifiedBy(roles, _signerKey(roles, roles.signedBy));
```

`SharedLibraryRoles`: add fields with `const` defaults (`version = 0`, `approvedKeys = const {}`, `recovery`, `reset = false`, `signedBy`, `signature`), `static const recoverySigner = 'recovery'`, `unsignedJson()` writing `owners` and `editors` sorted, `toJson()` = unsigned plus `signedBy`/`signature`, `fromJson` reading all (unknown keys ignored), `copyWith`, and `signed(...)`:

```dart
  Future<SharedLibraryRoles> signed({required String signedBy, required LibrarySigningKey key}) async {
    final unsigned = copyWith(signedBy: signedBy, clearSignature: true);
    final sig = await LibrarySigner.sign(key, utf8.encode(canonicalJson(unsigned.unsignedJson())));
    return unsigned.copyWith(signature: sig);
  }
```

`signedBy` is part of `unsignedJson()` so a signature cannot be re-attributed. Service step 2 becomes: read `incoming`; if `library.roles.version == 0` (first sync after join) accept when `isSelfConsistent`; else `judgeRoles`; `trusted` stores it and clears `rolesRejected`; `rejected` sets `rolesRejected` and keeps the trusted roles for every role decision below; `resetPending` stores `pendingRoles` (Task 13 answers it). Every later use of `roles` in `_syncOnce` uses the trusted roles.

Membership service `create`: `final recovery = await LibraryRecovery.create(); final me = await _store.signingKeyForDiver(diverId) ?? await LibrarySigner.generate();` (the profile may have no membership row yet, so the key is passed on the new membership model as `signingKey: me` and stored by `upsertMembership`, which also copies it to the profile's other rows); roles `version: 1, owners: {memberId}, approvedKeys: {memberId: me.publicKey}, recovery: RolesRecovery.fromJson(recovery.toRolesJson())`, signed by `memberId`; returns `CreatedLibrary(library: ..., recoveryCode: recovery.code)`. `join`: read roles; refuse with `UntrustedRolesError` when not `isSelfConsistent`; store them as trusted. `setRole`: `roles.copyWith(version: roles.version + 1, ...)` signed with the acting owner's key.

Connect page: after `create`, `await showRecoveryCodeDialog(context, code)` (a non-dismissible `AlertDialog` with the code in `SelectableText`, a Copy button, and `sharedLibrary_recovery_stored` as the only close action) before navigating. Library page: a `MaterialBanner`-style `Card` with `sharedLibrary_roles_rejected` when `library.rolesRejected`.

- [ ] **Step 4: Run** the four test files plus `test/core/services/shared_library` (Expected: PASS).

- [ ] **Step 5: Commit** `feat(shared-library): sign the roles and trust only owners' changes`

### Task 10: Signed member cards and owner approval

**Files:**
- Modify: `shared_library_models.dart` (`SharedLibraryMember` gains `publicKey`, `signature`, and `bool cardVerified`; `toJson`/`fromJson`)
- Modify: `shared_library_transport.dart` (`listMembers` verifies each card's self-signature and sets `cardVerified`)
- Modify: `shared_library_service.dart` (writes the own card signed, with `publicKey`, whenever the key or name differs)
- Modify: `shared_library_membership_service.dart` (`approveMember`, `rejectMember`)
- Modify: `lib/features/shared_library/presentation/pages/shared_library_members_page.dart` (Pending section for owners; readers see approved members only)
- Modify: `shared_library_providers.dart` (`libraryMembersProvider` exposes approval: `MemberStatus { approved, pending }`)
- Modify: 11 ARB files (`sharedLibrary_members_pending`, `sharedLibrary_members_approve`, `sharedLibrary_members_reject`, `sharedLibrary_members_fingerprint` ("Key {fingerprint}"), `sharedLibrary_members_rejectConfirm`)
- Test: `shared_library_transport_test.dart`, `shared_library_membership_service_test.dart`, `shared_library_members_page_test.dart`

**Interfaces:**
- Produces: `bool isApproved(SharedLibraryMember m, SharedLibraryRoles roles)` (= `m.cardVerified && roles.approvedKeys[m.memberId] == m.publicKey`); `Future<void> approveMember({required String libraryId, required String memberId, required String diverId})`; `Future<void> rejectMember({...same})`.

- [ ] **Step 1: Write the failing tests**

Transport: a card whose `displayName` was edited after signing reads with `cardVerified == false`. Membership service: `approveMember` by an owner writes roles version + 1 with `approvedKeys[memberId]` set to the card's key; by a non-owner throws `StateError`; `rejectMember` deletes the card and removes any approval. Members page: with roles approving only `o`, a card `p` shows under "Pending approval" with its fingerprint and Approve; tapping Approve calls the service (fake records the call).

- [ ] **Step 2: Run to see them fail.**

- [ ] **Step 3: Implement**

Card message: `canonicalJson({'memberId': id, 'displayName': name, 'joinedAt': iso, 'publicKey': key})`; the card stores `signature`. `listMembers` sets `cardVerified` with `LibrarySigner.verify`. `approveMember` re-reads roles from the folder (as `setRole` does), requires the actor to be an owner, reads the member's card, refuses an unverified card, writes `roles.copyWith(version: v + 1, approvedKeys: {...roles.approvedKeys, memberId: card.publicKey!})` signed by the actor. Members page: split `members` into approved and pending with `isApproved`; owners see a "Pending approval" header and a `ListTile` per pending member with `subtitle: Text(l10n.sharedLibrary_members_fingerprint(LibrarySigner.fingerprint(m.publicKey!)))` and two `TextButton`s.

- [ ] **Step 4: Run tests** (Expected: PASS).

- [ ] **Step 5: Commit** `feat(shared-library): approve members' signing keys`

### Task 11: Signed fields, verified on pull

**Files:**
- Modify: `shared_library_models.dart` (`FieldClock` gains `String? sig`, kept out of `props`, and `FieldClock copyWith({String? sig})`; `toJson` writes it when set; `fromJson` reads it; the store's `clocksJson` keeps it)
- Create: `lib/core/services/shared_library/crypto/field_signatures.dart`
- Modify: `shared_library_service.dart` (verify before merge, sign before upload, re-read on approval)
- Modify: `shared_library_store.dart` (`clearRemoteStamps(String libraryId)`)
- Test: `test/core/services/shared_library/crypto/field_signatures_test.dart`, `shared_library_service_test.dart`

**Interfaces:**
- Produces:
  - `List<int> fieldSignatureMessage({required String libraryId, required String siteId, required String field, required FieldClock clock, required Object? value})`
  - `Future<SiteDocument> signOwnFields(SiteDocument doc, {required String libraryId, required String memberId, required LibrarySigningKey key})` (signs every clock of `memberId` without `sig`)
  - `Future<SiteDocument> dropUnverified(SiteDocument remote, {required SiteDocument local, required String libraryId, required Map<String, String> approvedKeys})` (removes each remote field, value and clock, that is newer than local and fails verification; `deleted` likewise, reverting to local's `deleted`)

- [ ] **Step 1: Write the failing tests**

```dart
test('a signed field verifies; a changed value does not', () async {
  final key = await LibrarySigner.generate();
  final clock = FieldClock(hlc: Hlc(10, 0, 'm1'), memberId: 'm1');
  var doc = SiteDocument(id: 's1', fields: {'name': 'A'}, clocks: {'name': clock});
  doc = await signOwnFields(doc, libraryId: 'L', memberId: 'm1', key: key);
  final local = SiteDocument(id: 's1');
  final kept = await dropUnverified(doc, local: local, libraryId: 'L', approvedKeys: {'m1': key.publicKey});
  expect(kept.fields['name'], 'A');
  final forged = SiteDocument(id: 's1', fields: {'name': 'B'}, clocks: doc.clocks);
  final dropped = await dropUnverified(forged, local: local, libraryId: 'L', approvedKeys: {'m1': key.publicKey});
  expect(dropped.fields.containsKey('name'), isFalse);
});

test('an unapproved signer is dropped', () async { /* key not in approvedKeys */ });
test('a field not newer than local is not checked', () async { /* local holds the same clock: kept without verify */ });
test('a forged tombstone is dropped', () async { /* deleted: true with a bad sig keeps local deleted false */ });
```

Service tests:

```dart
test('a forged field is ignored and rewritten by the next honest upload', () async {
  // member m1 (approved) uploads name 'A'; overwrite the file with name 'X'
  // under a newer clock claiming m1 and no valid sig; sync m1's device:
  // local name stays 'A' and the file holds 'A' again with a valid sig.
});

test('approval re-reads held edits', () async {
  // member p (pending) uploads name 'P'; owner device syncs: name unchanged;
  // owner approves p; owner syncs: name is 'P'.
});

test('verifying 500 sites takes under 10 s', () async {
  // 500 documents x 20 signed fields; time dropUnverified over all; expect
  // the stopwatch below 10 s (pure Dart on the CI runner).
}, timeout: const Timeout(Duration(minutes: 2)));
```

- [ ] **Step 2: Run to see them fail.**

- [ ] **Step 3: Implement**

```dart
List<int> fieldSignatureMessage({
  required String libraryId,
  required String siteId,
  required String field,
  required FieldClock clock,
  required Object? value,
}) => utf8.encode([
  'ssl-field:v1',
  libraryId,
  siteId,
  field,
  clock.hlc.toString(),
  clock.memberId,
  sha256Hex(utf8.encode(canonicalJson(value))),
].join('\n'));

Object? _valueOf(SiteDocument d, String field) =>
    field == SiteDocument.deletedField ? d.deleted : d.fields[field];

Future<SiteDocument> signOwnFields(SiteDocument doc, {required String libraryId, required String memberId, required LibrarySigningKey key}) async {
  final clocks = {...doc.clocks};
  for (final e in doc.clocks.entries) {
    if (e.value.memberId != memberId || e.value.sig != null) continue;
    final sig = await LibrarySigner.sign(key, fieldSignatureMessage(
      libraryId: libraryId, siteId: doc.id, field: e.key, clock: e.value, value: _valueOf(doc, e.key)));
    clocks[e.key] = e.value.copyWith(sig: sig);
  }
  return doc.copyWith(clocks: clocks);
}

Future<SiteDocument> dropUnverified(SiteDocument remote, {required SiteDocument local, required String libraryId, required Map<String, String> approvedKeys}) async {
  final fields = {...remote.fields};
  final clocks = {...remote.clocks};
  var deleted = remote.deleted;
  for (final e in remote.clocks.entries) {
    final mine = local.clocks[e.key];
    final newer = mine == null || e.value.hlc.compareTo(mine.hlc) > 0;
    if (!newer) continue;
    final key = approvedKeys[e.value.memberId];
    final ok = key != null && await LibrarySigner.verify(
      publicKey: key,
      message: fieldSignatureMessage(libraryId: libraryId, siteId: remote.id, field: e.key, clock: e.value, value: _valueOf(remote, e.key)),
      signature: e.value.sig,
    );
    if (ok) continue;
    clocks.remove(e.key);
    if (e.key == SiteDocument.deletedField) {
      deleted = local.deleted;
    } else {
      fields.remove(e.key);
    }
  }
  // A field with a value but no clock is unverifiable too.
  fields.removeWhere((name, _) => !clocks.containsKey(name) && !local.fields.containsKey(name));
  return SiteDocument(id: remote.id, deleted: deleted, fields: fields, clocks: clocks, extra: remote.extra);
}
```

Service: in `_mergeRemote`, `final checked = await dropUnverified(remote, local: local, libraryId: library.id, approvedKeys: trustedRoles.approvedKeys);` and merge `checked`; because a dropped field leaves local winning, `localWon` marks the site dirty and the push writes the honest value back. Before `t.writeSite(doc)`, `doc = await signOwnFields(doc, libraryId: libraryId, memberId: membership.memberId, key: myKey)` where `myKey = await _store.ensureSigningKey(diverId)`; store the signed clocks back into the state in `_recordUpload` (the clocks sent carry `sig`). When step 2 trusts new roles whose `approvedKeys` differ from the old, call `_store.clearRemoteStamps(libraryId)` before the pull so every document is re-read. If the benchmark exceeds 10 s, move `dropUnverified` for the whole pull batch into `Isolate.run` (pure function over plain maps) and keep the test.

- [ ] **Step 4: Run** `flutter test test/core/services/shared_library` (Expected: PASS, benchmark under 10 s).

- [ ] **Step 5: Commit** `feat(shared-library): sign every edit and ignore unverified ones`

### Task 12: Signed suggestions

**Files:**
- Modify: `shared_library_store.dart` (`SharedSiteSuggestion` gains `signedBy`, `signature`; `toJson`/`fromJson`)
- Modify: `suggestion_service.dart` (`propose` signs), `shared_library_service.dart` (`_pullSuggestions` keeps only verified ones)
- Test: `suggestion_service_test.dart`, `shared_library_service_test.dart`

- [ ] **Step 1: Failing tests**: a proposed suggestion's uploaded JSON verifies against the proposer's key; an owner's pull skips a suggestion whose note was altered after signing, and one from an unapproved member, and picks the latter up after approval.
- [ ] **Step 2: Run to see them fail.**
- [ ] **Step 3: Implement**: message `canonicalJson(json minus signature)` with `signedBy` = memberId; `_pullSuggestions` verifies with `trustedRoles.approvedKeys[json['memberId']]` and `continue`s on failure (the file stays for later); approval clears the stored incoming ids so they are re-read (`clearRemoteStamps` covers suggestions by also deleting held incoming rows whose author was pending).
- [ ] **Step 4: Run tests** (Expected: PASS).
- [ ] **Step 5: Commit** `feat(shared-library): sign suggestions`

### Task 13: When an owner is lost

**Files:**
- Modify: `shared_library_membership_service.dart` (`recoverOwnership`, `reissueRecoveryCode`, `resetOwnership`, `acceptReset`, `declineReset`)
- Modify: `shared_library_page.dart` (one-owner warning, Recover ownership, New recovery code, Reset ownership, reset prompt banner)
- Create: `lib/features/shared_library/presentation/widgets/recovery_code_dialog.dart` (`showRecoveryCodeDialog`, `promptRecoveryCode`)
- Modify: 11 ARB files (`sharedLibrary_owner_onlyOne`, `sharedLibrary_owner_recover`, `sharedLibrary_owner_recoverPrompt`, `sharedLibrary_owner_wrongCode`, `sharedLibrary_owner_newCode`, `sharedLibrary_owner_reset`, `sharedLibrary_owner_resetConfirm`, `sharedLibrary_owner_resetPrompt` ("Ownership of {library} was reset by {name} ({fingerprint}). Accept?"), `sharedLibrary_owner_resetAccept`, `sharedLibrary_owner_resetDecline`, `sharedLibrary_owner_resetDeclined`)
- Test: `shared_library_membership_service_test.dart`, `shared_library_page_test.dart`, `shared_library_service_test.dart`

**Interfaces:**
- Produces: `Future<void> recoverOwnership({required String libraryId, required String diverId, required String code})` (throws `WrongRecoveryCodeError`), `Future<String> reissueRecoveryCode({required String libraryId, required String diverId})`, `Future<void> resetOwnership({required String libraryId, required String diverId})`, `Future<void> acceptReset(String libraryId)`, `Future<void> declineReset(String libraryId)`.

- [ ] **Step 1: Failing tests**

```dart
test('the recovery code brings back an owner', () async {
  final created = await service.create(/* ... d1 ... */);
  // a second profile d2 joins, the owner's key is lost (new key for d1 is
  // pending); d2 recovers with the code: roles v2 signed by 'recovery'
  // make d2 an owner, and d1's device (trusting v1) accepts v2.
});
test('a wrong code is refused', () async { /* throws WrongRecoveryCodeError, roles unchanged */ });
test('a new code replaces the old one', () async { /* old code no longer verifies */ });
test('a reset needs each member's yes', () async {
  // reset by d2 with full keys; d1's sync stores pendingRoles, role stays
  // reader-capped (read-only); acceptReset makes them trusted; declineReset
  // keeps the old roles and marks the library read-only.
});
```

Page tests: one owner shows the warning; a pending reset shows the prompt with the name and fingerprint; tapping Accept calls `acceptReset`.

- [ ] **Step 2: Run to see them fail.**
- [ ] **Step 3: Implement**: `recoverOwnership` reads roles, derives `LibraryRecovery.derive(code, salt, kdf)` from `roles.recovery`, compares the public key (mismatch: `WrongRecoveryCodeError`), then writes `roles.copyWith(version: v + 1, owners: {...owners, me}, approvedKeys: {...approvedKeys, me: myKey})` signed with the derived key as `recoverySigner`. `reissueRecoveryCode` (owner) creates a new `LibraryRecovery`, writes roles v + 1 with the new `recovery` signed by the owner, and (when the library is encrypted, Task 17) replaces the recovery keyslot; returns the code. `resetOwnership` writes `SharedLibraryRoles(version: trusted.version + 1, owners: {me}, approvedKeys: {me: myKey}, reset: true)` signed by me (its recovery is cleared; the new owner issues a new code next). `acceptReset` moves `pendingRoles` to trusted and clears the flag; `declineReset` clears `pendingRoles`, sets `readOnlyDetected`, and stores a `resetDeclined` marker in `lastError` so the banner can reopen the question (`pendingRoles` is re-stored by the next sync while the reset file stands). The library page lays these out as a "Ownership" section visible to everyone, with owner-only actions gated by `libraryRoleProvider`.
- [ ] **Step 4: Run tests** (Expected: PASS).
- [ ] **Step 5: Commit** `feat(shared-library): recover ownership with a code or the members' consent`

---
## Part C: encryption

### Task 14: Format version 2 (manifest and info.json)

**Files:**
- Modify: `shared_library_models.dart` (`SharedLibraryLayout.infoFile = 'info.json'`, `keyslotsFile = 'keyslots.json'`, `backupsDir = 'backups'`)
- Modify: `shared_library_transport.dart` (`readInfo`/`writeInfo`, `readKeyslots`/`writeKeyslots`/`deleteKeyslots`)
- Modify: `shared_library_membership_service.dart` (`LibraryProbe` gains `retired`, `encrypted`, `keyId`; `create` writes the v2 manifest without the name and `info.json` with it)
- Modify: `shared_library_service.dart` (a manifest below version 2 fails with `SharedLibrarySyncStatus.retired`)
- Modify: `connect_shared_library_page.dart`, `shared_library_page.dart` (show `sharedLibrary_retired`: "This library was made by a test build of Submersion. Create it again.")
- Modify: 11 ARB files
- Test: `shared_library_membership_service_test.dart`, `shared_library_service_test.dart`, `connect_shared_library_page_test.dart`

- [ ] **Step 1: Failing tests**: `create` writes `manifest.json` = `{id, formatVersion: 2, encrypted: false, createdBy, createdAt}` and `info.json` = `{name}`; a probe of a version-1 manifest returns `retired: true`; a sync of a version-1 library returns `retired`; the connect page shows the retired text and no Join.
- [ ] **Step 2: Run to see them fail.**
- [ ] **Step 3: Implement** the layout constants, transport methods (`_readJson(await _rootId(), infoFile)` and so on, through the cipher once Task 15 lands), probe fields, and the refusal.
- [ ] **Step 4: Run tests** (Expected: PASS).
- [ ] **Step 5: Commit** `feat(shared-library): move libraries to format version 2`

### Task 15: LibraryCipher in the transport

**Files:**
- Create: `lib/core/services/shared_library/crypto/library_cipher.dart`
- Modify: `shared_library_transport.dart` (every read and write except `manifest.json` and `keyslots.json` passes through the cipher; mismatch tracking)
- Test: `test/core/services/shared_library/crypto/library_cipher_test.dart`, `shared_library_transport_test.dart`

**Interfaces:**
- Produces:
  - `class LibraryCipher { LibraryCipher({required String keyId, required SecretKey libraryKey}); final String keyId; static Future<LibraryCipher> generate(); Future<String> exportKey(); static Future<LibraryCipher> fromExported({required String keyId, required String key}); Future<Uint8List> seal(String path, Uint8List plain); Future<Uint8List> open(String path, Uint8List bytes); static bool isSealed(Uint8List bytes); static String keyIdOf(Uint8List bytes); Future<KeyslotFile> keyslots({required String passphrase, required String recoveryCode, KdfParams kdf}); static Future<LibraryCipher?> unlock(KeyslotFile file, String secret); }`
  - `class LibraryLockedException implements Exception { final String keyId; }` (a sealed file and no matching key)
  - Transport: `LibraryCipher? cipher` and `bool encrypting` (set by the service from the manifest), `Set<String> mismatchedPaths` (files read in the wrong form: plain in an encrypted library, sealed in a plain one, or sealed under another key), `Future<void> rewrite(String path)` (re-reads and writes it back in the current form).

- [ ] **Step 1: Failing tests**

```dart
test('sealed files open only at their own path and key', () async {
  final c = await LibraryCipher.generate();
  final bytes = await c.seal('sites/site-s1.json', utf8.encode('{"id":"s1"}') as Uint8List);
  expect(LibraryCipher.isSealed(bytes), isTrue);
  expect(utf8.decode(await c.open('sites/site-s1.json', bytes)), '{"id":"s1"}');
  await expectLater(c.open('sites/site-s2.json', bytes), throwsA(isA<EnvelopeCorruptException>()));
  final other = await LibraryCipher.generate();
  await expectLater(other.open('sites/site-s1.json', bytes), throwsA(isA<LibraryLockedException>()));
});

test('keyslots unlock with the passphrase or the recovery code', () async {
  const fast = KdfParams(m: 1024, t: 1);
  final c = await LibraryCipher.generate();
  final file = await c.keyslots(passphrase: 'correct horse battery', recoveryCode: 'alpha bravo', kdf: fast);
  expect((await LibraryCipher.unlock(file, 'correct horse battery'))!.keyId, c.keyId);
  expect(await LibraryCipher.unlock(file, 'ALPHA  bravo'), isNotNull);
  expect(await LibraryCipher.unlock(file, 'wrong'), isNull);
});
```

Transport tests (fake provider): with `cipher` set and `encrypting = true`, `writeSite` stores sealed bytes and `readSite` returns the document; a plain site file read in that state returns the document and lands in `mismatchedPaths`; with `encrypting = false` and no cipher, reading a sealed file throws `LibraryLockedException`; `manifest.json` and `keyslots.json` are always plain; `rewrite` turns a plain file sealed.

- [ ] **Step 2: Run to see them fail.**
- [ ] **Step 3: Implement**

```dart
class LibraryCipher {
  LibraryCipher({required this.keyId, required SecretKey libraryKey}) : _libraryKey = libraryKey;

  final String keyId;
  final SecretKey _libraryKey;
  SecretKey? _dataKey;

  static Future<LibraryCipher> generate() async {
    final r = Random.secure();
    return LibraryCipher(
      keyId: const Uuid().v4(),
      libraryKey: SecretKey([for (var i = 0; i < 32; i++) r.nextInt(256)]),
    );
  }

  Future<SecretKey> _data() async => _dataKey ??= await Keyslots.deriveSubKey(_libraryKey, info: 'ssl:v1:data');

  static bool isSealed(Uint8List bytes) => SyncEnvelope.hasMagic(bytes);
  static String keyIdOf(Uint8List bytes) => SyncEnvelope.libraryKeyIdOf(bytes);

  Future<Uint8List> seal(String path, Uint8List plain) async => SyncEnvelope.seal(
    plaintext: plain, dataKey: await _data(), libraryKeyId: keyId, filename: path);

  Future<Uint8List> open(String path, Uint8List bytes) async {
    if (keyIdOf(bytes) != keyId.toLowerCase()) throw LibraryLockedException(keyIdOf(bytes));
    return SyncEnvelope.open(envelope: bytes, dataKey: await _data(), expectedLibraryKeyId: keyId, filename: path);
  }

  Future<String> exportKey() async => base64Encode(await _libraryKey.extractBytes());

  static Future<LibraryCipher> fromExported({required String keyId, required String key}) async =>
      LibraryCipher(keyId: keyId, libraryKey: SecretKey(base64Decode(key)));

  Future<KeyslotFile> keyslots({required String passphrase, required String recoveryCode, KdfParams kdf = const KdfParams()}) async =>
      KeyslotFile(version: 1, libraryKeyId: keyId, slots: [
        await Keyslots.createSlot(type: 'passphrase', secret: passphrase, mlk: _libraryKey, kdf: kdf),
        await Keyslots.createSlot(type: 'recovery', secret: RecoveryCode.normalize(recoveryCode), mlk: _libraryKey, kdf: kdf),
      ]);

  static Future<LibraryCipher?> unlock(KeyslotFile file, String secret) async {
    final key = await Keyslots.tryUnwrap(file: file, secret: secret);
    return key == null ? null : LibraryCipher(keyId: file.libraryKeyId, libraryKey: key);
  }
}
```

Transport: route every byte read through `Future<Uint8List> _open(String path, Uint8List raw)` (sealed: needs `cipher`, else `LibraryLockedException`; records `path` in `mismatchedPaths` when the form or key id disagrees with `encrypting`/`cipher.keyId`) and every write through `_seal(String path, Uint8List plain)` (sealed iff `encrypting`). Paths: `info.json`, `roles.json`, `members/<file>`, `sites/<file>`, `suggestions/<file>`, using the file's basename. `readSite(fileId)` keeps its signature and derives the path from the id's basename.

- [ ] **Step 4: Run tests** (Expected: PASS).
- [ ] **Step 5: Commit** `feat(shared-library): seal library files with the library key`

### Task 16: Joining and unlocking an encrypted library

**Files:**
- Modify: `shared_library_membership_service.dart` (`probe` reports `encrypted`; `join` takes `String? secret`; `unlockLibrary({libraryId, diverId, secret})`)
- Modify: `shared_library_service.dart` (manifest `encrypted`: needs the membership's key for `keyId`; missing or wrong key returns `SharedLibrarySyncStatus.locked` with no uploads)
- Modify: `shared_library_providers.dart` (transport factory sets `cipher` from the membership's `libraryKeyId`/`libraryKey`)
- Modify: `connect_shared_library_page.dart` (passphrase field when the probe says encrypted; shows the name after unlocking)
- Modify: `shared_library_page.dart` and `shared_libraries_page.dart` (locked banner with "Enter passphrase")
- Modify: 11 ARB files (`sharedLibrary_encrypted_probe`, `sharedLibrary_encrypted_passphrase`, `sharedLibrary_encrypted_wrong`, `sharedLibrary_encrypted_locked` ("Enter the passphrase for {library}."), `sharedLibrary_encrypted_changed` ("This library's passphrase changed. Enter the new one."), `sharedLibrary_encrypted_unlock`)
- Test: `shared_library_membership_service_test.dart`, `shared_library_service_test.dart`, `connect_shared_library_page_test.dart`, `shared_library_page_test.dart`

- [ ] **Step 1: Failing tests**: probing an encrypted library returns `encrypted: true` with no name; `join` with the wrong passphrase throws `WrongPassphraseError` and stores nothing; with the right one stores `libraryKeyId`/`libraryKey` on the membership and the name from `info.json`; a sync with no key returns `locked` and uploads nothing (fake provider `uploadAttempts` unchanged); `unlockLibrary` then makes the sync succeed; the connect page shows the passphrase field and Join only after Check with the right passphrase.
- [ ] **Step 2: Run to see them fail.**
- [ ] **Step 3: Implement** as listed; the key is stored with `setLibraryKey` and so reaches the profile's other devices by personal sync (Ruling 1). When a sync finds the manifest not encrypted while the membership still holds a library key, it clears it with `setLibraryKey(keyId: null, key: null)`, so members' devices drop the key after an owner turns encryption off.
- [ ] **Step 4: Run tests** (Expected: PASS).
- [ ] **Step 5: Commit** `feat(shared-library): join and unlock encrypted libraries`

### Task 17: Turning encryption on and off, and changing the passphrase

**Files:**
- Create: `lib/core/services/shared_library/library_encryption_service.dart`
- Modify: `shared_library_service.dart` (owner devices rewrite `mismatchedPaths` after the pull)
- Modify: `shared_library_providers.dart` (`libraryEncryptionServiceProvider`, `// no-tick:`)
- Modify: `shared_library_page.dart` (owners: "Encryption" section with Turn on, Turn off, Change passphrase; each confirms, shows progress, then the new recovery code where one is made)
- Modify: 11 ARB files (`sharedLibrary_encryption_title`, `_on`, `_off`, `_change`, `_onConfirm`, `_offConfirm`, `_changeConfirm`, `_progress` ("Rewriting {done} of {total} files"), `_passphraseRules`)
- Test: `test/core/services/shared_library/library_encryption_service_test.dart`, `shared_library_page_test.dart`

**Interfaces:**
- Produces: `class LibraryEncryptionService { Future<String> turnOn({required String libraryId, required String diverId, required String passphrase, void Function(int done, int total)? progress}); Future<void> turnOff({...}); Future<String> changePassphrase({required String libraryId, required String diverId, required String passphrase, ...}); }` (each owner-only, under `SyncCoordinator.run`; `turnOn` and `changePassphrase` return the new recovery code).

- [ ] **Step 1: Failing tests**

```dart
test('turning it on seals every file and a member can still read', () async { /* ... */ });
test('a late plain upload is converted', () async {
  // turn on; then, as a member whose device has not seen the switch yet,
  // write a plain site file directly; the next owner sync rewrites it
  // sealed (transport mismatchedPaths drives the rewrite).
});
test('turning it off leaves every file plain and removes keyslots', () async { /* ... */ });
test('a new passphrase locks out the old key', () async {
  // member A holds the old key; owner changes the passphrase; A's sync is
  // locked and uploads nothing; A unlocks with the new passphrase and syncs.
});
test('a non-owner cannot change encryption', () async { /* StateError */ });
```

- [ ] **Step 2: Run to see them fail.**
- [ ] **Step 3: Implement**

`turnOn`: owner check (trusted roles, as `setRole`), `final cipher = await LibraryCipher.generate(); final recovery = await LibraryRecovery.create();` write `keyslots.json` (`cipher.keyslots(passphrase:, recoveryCode: recovery.code)`), then roles v + 1 with the new `recovery` signed by the owner, then the manifest with `encrypted: true, keyId`, then store the key on the membership, set `t.cipher = cipher; t.encrypting = true;` and rewrite every listed file (`info.json`, `roles.json`, members, sites, suggestions) reporting progress; return `recovery.code`. `turnOff`: manifest `encrypted: false` (no `keyId`) first, then rewrite every file plain, delete `keyslots.json`, `setLibraryKey(null)`. `changePassphrase`: as `turnOn` with a fresh cipher, opening each file with the old cipher (from the membership) and sealing with the new one. The sync service, when the device's trusted role is owner, calls `t.rewrite(path)` for each `mismatchedPaths` entry after the pull. Passphrase rules: reuse the encrypted-sync validator (`lib/features/settings/.../encryption` passphrase strength check; find it with `grep -rn "passphrase" lib/features/settings/presentation/widgets | head`).

- [ ] **Step 4: Run tests** (Expected: PASS).
- [ ] **Step 5: Commit** `feat(shared-library): encrypt a library and change its passphrase`

---

## Part D: backup and restore

### Task 18: The backup file

**Files:**
- Create: `lib/core/services/shared_library/backup/library_backup_archive.dart`
- Modify: `shared_library_transport.dart` (`Future<Map<String, Uint8List>> snapshot()` returns every stored file as raw bytes keyed by path; `Future<void> writeRaw(String path, Uint8List bytes)`; `Future<void> deleteRaw(String path)`)
- Test: `test/core/services/shared_library/backup/library_backup_archive_test.dart`, `shared_library_transport_test.dart`

**Interfaces:**
- Produces:
  - `class LibraryBackupHeader { backupId, libraryId, String? name, createdAt, createdBy, createdByKey, appVersion, formatVersion, automatic, note, siteCount, memberCount, contentSha256, signature; toJson; fromJson }`
  - `abstract final class LibraryBackupArchive { static Future<Uint8List> build({required Map<String, Uint8List> files, required LibraryBackupHeader header, required LibrarySigningKey key}); static Future<LibraryBackupContents> read(Uint8List zip); }`
  - `class LibraryBackupContents { final LibraryBackupHeader header; final Map<String, Uint8List> files; }`
  - `class BackupRefusedError implements Exception { final String reason; }` (`hash`, `signature`, `notABackup`)

- [ ] **Step 1: Failing tests**: build then read round-trips the files and header; flipping one byte of a site entry throws `BackupRefusedError('hash')`; editing the note in `backup.json` throws `BackupRefusedError('signature')`; a zip without `backup.json` throws `notABackup`; `contentSha256` is independent of entry order.
- [ ] **Step 2: Run to see them fail.**
- [ ] **Step 3: Implement**: `contentSha256` = SHA-256 over, for each path in sorted order, `utf8(path) + 0x00 + sha256(bytes)`; signature by `key` over `canonicalJson(header.toJson() minus signature)`; `read` verifies the hash, then the signature with `header.createdByKey`, and (in Task 21) the restore also requires `createdByKey` to be an owner's approved key in the backup's own `roles.json` when that file is readable. Zip with `ZipEncoder`/`ZipDecoder` from `archive`.
- [ ] **Step 4: Run tests** (Expected: PASS).
- [ ] **Step 5: Commit** `feat(shared-library): pack a library into a signed backup file`

### Task 19: Backups on the device and in storage

**Files:**
- Create: `lib/core/services/shared_library/backup/library_backup_service.dart`
- Create: `lib/core/services/shared_library/backup/library_backup_record.dart` (`LibraryBackupRecord`: id, libraryId, createdAt, note, pinned, automatic, beforeRestore, siteCount, memberCount, sizeBytes, `onDevice`, `inStorage`)
- Modify: `shared_library_transport.dart` (`listBackups`, `writeBackup`, `readBackup`, `deleteBackup`, `readBackupIndex`, `writeBackupIndex` under `backups/`; `snapshot` skips `backups/`)
- Modify: `shared_library_store.dart` (backup rows: `putBackup`, `backups(libraryId)`, `deleteBackup`)
- Test: `test/core/services/shared_library/backup/library_backup_service_test.dart`

**Interfaces:**
- Produces: `class LibraryBackupService { Future<LibraryBackupRecord> backUp({required String libraryId, required String diverId, String note = '', bool automatic = false, bool beforeRestore = false}); Future<List<LibraryBackupRecord>> list({required String libraryId}); Future<void> setPinned(String backupId, {required String libraryId, required String diverId, required bool pinned}); Future<void> delete(String backupId, {required String libraryId, required String diverId, required bool fromDevice, required bool fromStorage}); Future<String> exportPath(String backupId, {required String libraryId}); Future<LibraryBackupRecord> import({required String libraryId, required String path}); }`. Device files live at `p.join(await BackupService.defaultBackupsDirectoryPath(), 'shared-libraries', libraryId, '<file name>')`.

- [ ] **Step 1: Failing tests** (fake provider, temp backups directory under `Directory.systemTemp`, restored in `addTearDown`): `backUp` writes the zip to the device and to `backups/`, records it, and updates `backups/index.json` signed by the owner; `list` merges device rows and the storage index by id with the right `onDevice`/`inStorage`; pin and note round trip through both; delete from one place keeps the other; import of a valid file adds a device-only row; import of a backup of another library is refused; a non-owner cannot back up (`StateError`).
- [ ] **Step 2: Run to see them fail.**
- [ ] **Step 3: Implement** with the archive from Task 18; counts from the snapshot (`sites/` and `members/` entries); file name `submersion-sites-<folder or library>-<yyyy-mm-dd-hhmm>.zip` (folder sanitized with `[^A-Za-z0-9._-]` to `-`).
- [ ] **Step 4: Run tests** (Expected: PASS).
- [ ] **Step 5: Commit** `feat(shared-library): keep library backups on the device and in storage`

### Task 20: Automatic daily backups

**Files:**
- Modify: `library_backup_service.dart` (`Future<bool> backUpIfDue({required String libraryId, required String diverId, DateTime? now})`, `Future<void> prune({required String libraryId, required String diverId})`)
- Modify: `lib/features/shared_library/presentation/providers/shared_library_sync_notifier.dart` (after a healthy sync of a library where the profile is owner, call `backUpIfDue`; failures are logged, never surfaced as sync errors)
- Test: `library_backup_service_test.dart`, `shared_library_sync_notifier_test.dart`

- [ ] **Step 1: Failing tests**: due after 24 h since this device's `last_auto_backup_at`; not due when the storage index holds a backup under 20 h old (another owner's); pruning keeps the newest 7 unpinned per location and never a pinned or `beforeRestore` pinned one; the notifier calls `backUpIfDue` only for owners and only after a healthy sync.
- [ ] **Step 2: Run to see them fail.**
- [ ] **Step 3: Implement** as specified; `prune` runs after each automatic backup.
- [ ] **Step 4: Run tests** (Expected: PASS).
- [ ] **Step 5: Commit** `feat(shared-library): back up libraries daily on owners' devices`

### Task 21: Restore

**Files:**
- Create: `lib/core/services/shared_library/backup/library_restore_service.dart`
- Test: `test/core/services/shared_library/backup/library_restore_service_test.dart`

**Interfaces:**
- Produces: `class LibraryRestoreService { Future<void> restore({required String libraryId, required String diverId, required String backupId, String? oldSecret, void Function(int done, int total)? progress}); Future<void> restoreInto({required ConnectedAccount account, required String prefix, required String diverId, required String path, String? secret}); }`; `class BackupNeedsOldKeyError implements Exception { final String keyId; }`.

- [ ] **Step 1: Failing tests**

```dart
test('restore brings back sites, deletes newer ones and wins everywhere', () async {
  // owner backs up with sites A, B; then A is renamed, B deleted, C added;
  // restore; owner's local rows: A original name, B back, C gone; a second
  // member device syncs and sees the same.
});
test('restore wins with a slow clock', () async {
  // the restoring device's MemberClock `now` returns a time before every
  // stamp in the library; restored fields still win on the other device.
});
test('roles come back and later members are pending again', () async { /* ... */ });
test('a before-restore backup is made and pinned', () async { /* ... */ });
test('a backup sealed under an old key asks for it', () async {
  // backup, change passphrase, restore without oldSecret:
  // BackupNeedsOldKeyError; with the old passphrase: succeeds, files sealed
  // under the current key.
});
test('restore into an empty folder keeps the library id', () async { /* ... */ });
test('a backup whose creator is not an owner in it is refused', () async { /* ... */ });
```

- [ ] **Step 2: Run to see them fail.**
- [ ] **Step 3: Implement** under `SyncCoordinator.run`: (1) `backUp(beforeRestore: true)` then `setPinned(true)`; (2) open the backup's files with the old cipher when sealed (from the membership if its `keyId` matches, else `LibraryCipher.unlock(backup keyslots, oldSecret)` or `BackupNeedsOldKeyError`); (3) seed a `MemberClock` with the newest clock found in both the current library documents and the backup (`receive` each), so `next()` is after all of them even with a slow device clock; (4) for each backup site document, re-stamp every field and `deleted` with `clock.next()` under the owner, `signOwnFields`, write through the transport (current cipher); (5) every current site not in the backup gets a tombstone re-stamped and signed; (6) roles from the backup, `version: trusted.version + 1`, owner kept in `owners` with its current key approved, signed; (7) member cards and suggestions written back raw (their own signatures stand), others deleted; (8) clear the device's remote stamps so its next pull re-reads everything; (9) record `lastSyncAt`. `restoreInto` writes a fresh manifest (same id) and the above into the empty folder, then `join`s it, warning through a return flag when `probe` of the library's old location still finds it.
- [ ] **Step 4: Run tests** (Expected: PASS).
- [ ] **Step 5: Commit** `feat(shared-library): restore a library from a backup`

### Task 22: The Backups page

**Files:**
- Create: `lib/features/shared_library/presentation/pages/library_backups_page.dart`
- Create: `lib/features/shared_library/presentation/widgets/library_backup_tile.dart`
- Modify: `lib/core/router/app_router.dart` (`/settings/shared-libraries/:libraryId/backups`, name `sharedLibraryBackups`)
- Modify: `shared_library_page.dart` (owners: "Backups" `ListTile` to the page)
- Modify: `shared_library_providers.dart` (`libraryBackupServiceProvider`, `libraryRestoreServiceProvider`, `libraryBackupsProvider` family, refreshed after each action)
- Modify: 11 ARB files (`sharedLibrary_backups_title`, `_backUpNow`, `_import`, `_note`, `_automatic`, `_beforeRestore`, `_onDevice`, `_inStorage`, `_both`, `_summary` ("{sites} sites, {size}"), `_pin`, `_unpin`, `_delete`, `_deleteWhere`, `_export`, `_restore`, `_restoreConfirm`, `_restoreDone`, `_empty`, `_importRefused`)
- Test: `test/features/shared_library/presentation/pages/library_backups_page_test.dart`

- [ ] **Step 1: Failing widget tests** with a fake backup service: rows show date (diver's date format via `settingsProvider`), note, sites and size, Automatic tag and location; Pin toggles; Delete with both copies asks where; Restore asks for confirmation naming the date and calls `restore`; a `BackupNeedsOldKeyError` opens the passphrase prompt and retries with it; Back up now with a note calls `backUp(note:)`; Import picks a file (fake `FilePicker` via `file_picker_platform_interface`, restored in `addTearDown`) and calls `import`; Export calls the share sheet (fake `SharePlatform`, restored in `addTearDown`). Readers opening the route see nothing but a "Owners only" message.
- [ ] **Step 2: Run to see them fail.**
- [ ] **Step 3: Implement** the page as a `Scaffold` with an `AppBar` (title, Import action), a header `FilledButton.tonalIcon` Back up now, and a `ListView` of `LibraryBackupTile` (pin `IconButton` with `Icons.push_pin`/`push_pin_outlined` like `BackupHistoryTile`, a `PopupMenuButton` for Export, Restore, Delete). Keep the file under 400 lines; dialogs in their own functions.
- [ ] **Step 4: Run tests** (Expected: PASS), then `test/architecture` and `test/shared`.
- [ ] **Step 5: Commit** `feat(shared-library): list, restore and manage library backups`

---

## Part E: docs and finish

### Task 23: User guide, spec alignment and final checks

**Files:**
- Create: `docs/user/shared-site-libraries.md`
- Modify: `docs/user/_sidebar.md`, `docs/user/README.md` (link)
- Test: `scripts/check_docs_links.py` (CI's docs link check)

- [ ] **Step 1:** Write the guide: what a shared site library is; connecting (folder, account, Check, Join or Create, recovery code); roles and approval (fingerprints, Pending); what stays private; encryption (on, off, change passphrase, limits); owner loss (recovery code, second owner, reset); backups (where, automatic, restore, export and import); the storage setup guide with both example S3 policies and the WebDAV notes. Plain sentences, no em dashes, no earlier name.
- [ ] **Step 2:** Run `python3.14 scripts/check_docs_links.py` and the naming guard (Expected: PASS).
- [ ] **Step 3:** Full verification: `dart format .`, `flutter analyze`, `flutter test test/core/services/shared_library test/features/shared_library test/features/dive_sites test/core/services/sync test/core/database test/architecture test/shared` (Expected: all pass).
- [ ] **Step 4:** After screenshots of every changed screen (connect page with the folder first and the setup sheet, add confirmation, Members with Pending, library page with Ownership and Encryption sections, Backups page), named `<nn>-<screen>-after.png` in the scratchpad, sent to the user in one SendUserFile call.
- [ ] **Step 5:** Commit `docs(shared-library): user guide for shared site libraries`; update the PR body's Follow-ups and Screenshots lists; reset the review count to 0/2.
