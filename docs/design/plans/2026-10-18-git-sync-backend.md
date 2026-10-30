# Git Sync Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in one session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A sixth sync backend, "Git", that stores Submersion's sync files and cloud backups on a dedicated branch of a repository on any Git host, over HTTPS with a token.

**Architecture:** A small pure-Dart Git client (object encoding, pkt-line, pack read and write, smart HTTP v2 fetch and v0 push) sits under `lib/core/services/cloud_storage/git/`. A `GitBranchSession` turns file operations into commits on one branch, with an index file for sizes and times, safety rules, conditional deletes and history resets. `GitStorageProvider` implements the existing `CloudStorageProvider` seam, so the sync engine, encryption and backups work unchanged. A new optional `DeferredWriteProvider` interface lets callers flush batched deletes.

**Tech Stack:** Dart, Flutter, Riverpod, `package:http` over `dart:io` `HttpClient` (via the WebDAV TLS helper), `package:crypto` (SHA-1), `package:archive` 4.0.9 (`Inflate.stream`), `dart:io` `ZLibEncoder` for deflate, `flutter_secure_storage` via `FallbackSecureStorage`.

**Spec:** `docs/design/specs/2026-10-18-git-sync-backend-design.md`. Issue #3511.

## Global Constraints

- No native code, no new native dependency, no dependency on an installed `git` in production code. Tests may require `git`.
- HTTPS only; `http://` addresses are refused. Credentials embedded in the URL are refused.
- Default branch name `submersion-sync`. Commit email `sync@submersion.invalid`.
- Sync folder `Submersion Sync` (`CloudStorageProviderMixin.syncFolderName`); backup folder `Submersion Backups` (`BackupService`'s `_cloudBackupFolder`).
- Branch root files: `README.md`, `.submersion/branch.json`, `.submersion/index.json`.
- History reset threshold `256 * 1024 * 1024` deleted bytes.
- Push pacing waits at most 10 s; a whole upload finishes or throws its own typed error within 45 s; `deleteFile` does no network I/O.
- Never write to a branch that exists without `.submersion/branch.json`.
- A public repository is allowed only while encrypted sync is on.
- With encrypted sync on, commit author and message use `Submersion` plus the first eight characters of the device id, never the device display name.
- Git is not a media store backend and not offered for the shared library.
- Every user-facing string goes in all 11 ARB files (`ar de en es fr he hu it nl pt zh`), each translated; ARB files are feature-grouped, insert next to a neighbouring key of the same group.
- No emojis, no em-dashes, no AI attribution anywhere. `dart format .` before every commit. Stage explicit paths only.
- Files 200 to 400 lines typical, 800 max.
- Tests restore any process-wide state they replace (CI bundles test files in one isolate).

## Review Focus

1. **A push whose reply is lost** (connection drops after the server accepted it). The retry must notice the tip already is, or already contains, our change and report success, not commit a duplicate or a spurious error. Test in Task 6.
2. **Repository address variants**: web URL without `.git`, trailing slash, `.git/`, uppercase host, GitLab subgroup paths (`gitlab.com/group/sub/repo`), a `www.` prefix on github.com. All normalize to one clone URL and one account identity. Test in Task 7.
3. **A server with protocol v0 only, or without `filter`** (older Gitea, some Bitbucket paths). Fetch falls back, and blob reads still work. Test in Task 5, against `git http-backend` configured each way.
4. **Invalid branch names** (`sync dev`, `sync..dev`, `-x`, `refs/heads/x`, a trailing `/` or `.lock`). These are rejected in the form with a clear message, never sent to the server. Test in Task 7.
5. **A pasted token with surrounding whitespace or a trailing newline** is trimmed. A token containing inner whitespace is rejected as invalid. Test in Task 7.

---

## File Structure

Create under `lib/core/services/cloud_storage/git/`:

| File | Responsibility |
| --- | --- |
| `git_object_id.dart` | `GitObjectId` (20-byte SHA-1), `GitObjectType`, `hashGitObject` |
| `git_objects.dart` | Tree and commit encode/decode, `GitTreeEntry`, `GitCommit` |
| `pkt_line.dart` | pkt-line encode and a streaming reader |
| `pack_inflater.dart` | Inflate one zlib stream at an offset and report bytes consumed |
| `pack_reader.dart` | Parse a pack, resolve OFS/REF deltas, write objects to a store |
| `pack_writer.dart` | Write an undeltified pack from object sources |
| `git_object_store.dart` | `GitObjectStore` interface, memory and file-backed LRU stores |
| `git_errors.dart` | `GitErrorCode`, `GitException`, `GitUntrustedCertificateException` |
| `git_remote.dart` | `GitRemote` (clone URL, username, token, pin) |
| `git_http_transport.dart` | Discovery, ls-refs, fetch, push, anonymous probe |
| `git_branch_files.dart` | `GitIndex`, `GitBranchMeta`, README text, JSON codecs |
| `git_tree_editor.dart` | Apply path puts/deletes to a root tree, producing new tree objects |
| `git_branch_session.dart` | Open/create/adopt, refresh, commit with retry, reset, blob reads |
| `git_config.dart` | `GitConfig`, normalization, validation, host detection |
| `git_credentials_store.dart` | Keychain persistence of `GitConfig` |

Create elsewhere:

| File | Responsibility |
| --- | --- |
| `lib/core/services/cloud_storage/deferred_write_provider.dart` | `DeferredWriteProvider`, `HistoryResettable`, `flushDeferredWrites`, `resetHistoryNow` helpers |
| `lib/core/services/cloud_storage/git_storage_provider.dart` | `GitStorageProvider` |
| `lib/core/services/accounts/adapters/git_account_adapter.dart` | `GitAccountAdapter` (SyncCapable only) |
| `lib/features/settings/presentation/providers/git_providers.dart` | Riverpod providers for the page and tile |
| `lib/features/settings/presentation/pages/git_config_page.dart` | The setup screen |
| `lib/features/settings/presentation/widgets/git_provider_tile.dart` | Cloud sync list row |
| `lib/features/settings/presentation/widgets/git_host_note.dart` | Host-specific token help |
| `lib/features/settings/presentation/widgets/git_error_text.dart` | Localized error text |
| `test/helpers/git_http_backend_server.dart` | Loopback HTTP server running stock `git http-backend` as CGI |
| `test/fixtures/git/` | Pack fixtures produced by stock git, plus `regenerate.sh` |

Modify: `cloud_storage_provider.dart` (no change to the interface itself), `encrypting_cloud_storage_provider.dart`, `cloud_provider_instances.dart`, `sync_repository.dart` (enum + lookup), `account_kind.dart`, `account_identity.dart`, `account_providers.dart`, `sync_providers.dart`, `sync_service.dart`, `sync_encryption_service.dart` callers, `backup_service.dart`, `media_store_service.dart`, `cloud_sync_page.dart`, `backup_sync_step.dart`, `app_router.dart`, `encryption_settings_section.dart`, the 11 ARB files, `.github/workflows` test job (Task 12).

---

### Task 1: Git object model

**Files:**
- Create: `lib/core/services/cloud_storage/git/git_object_id.dart`, `lib/core/services/cloud_storage/git/git_objects.dart`
- Test: `test/core/services/cloud_storage/git/git_objects_test.dart`

**Interfaces:**
- Produces:
  - `enum GitObjectType { commit(1), tree(2), blob(3), tag(4); final int packCode; String get wireName; static GitObjectType fromPackCode(int) }`
  - `final class GitObjectId { GitObjectId(Uint8List bytes) /* asserts length 20 */; factory GitObjectId.fromHex(String hex); String get hex; static final GitObjectId zero; operator ==, hashCode, toString => hex }`
  - `GitObjectId hashGitObject(GitObjectType type, List<int> body)`: SHA-1 of `'<wireName> <len>\0' + body`.
  - `const int kGitModeFile = 0x81A4 /* 100644 */; const int kGitModeTree = 0x4000 /* 40000 */;`
  - `final class GitTreeEntry { const GitTreeEntry({required String name, required int mode, required GitObjectId id}); bool get isTree; }`
  - `Uint8List encodeTree(Iterable<GitTreeEntry> entries)`: sorts by Git's rule (names compared as bytes, with tree names compared as if followed by `/`), mode in octal without leading zero.
  - `List<GitTreeEntry> decodeTree(Uint8List body)`
  - `final class GitCommit { const GitCommit({required GitObjectId tree, required List<GitObjectId> parents, required String authorName, required String authorEmail, required DateTime when, required String message}); Uint8List encode(); static GitCommit decode(Uint8List body); }`: author and committer identical, timezone `+0000`, `when` in UTC seconds, message ends with `\n`.

- [ ] **Step 1: Write the failing tests**

```dart
test('empty blob and empty tree hash to Git\'s well-known ids', () {
  expect(hashGitObject(GitObjectType.blob, []).hex,
      'e69de29bb2d1d6434b8b29ae775ad8c2e48c5391');
  expect(hashGitObject(GitObjectType.tree, encodeTree(const [])).hex,
      '4b825dc642cb6eb9a060e54bf8d69288fbee4904');
});
test('blob "hello\\n" hashes like git hash-object', () {
  expect(hashGitObject(GitObjectType.blob, utf8.encode('hello\n')).hex,
      'ce013625030ba8dba906f756967f9e9ca394464a');
});
test('tree sorts a directory after a same-prefixed file the way Git does', () {
  // Git orders "a.b" (file) before "a" (tree, compared as "a/") before "a0".
  final blob = hashGitObject(GitObjectType.blob, []);
  final names = decodeTree(encodeTree([
    GitTreeEntry(name: 'a0', mode: kGitModeFile, id: blob),
    GitTreeEntry(name: 'a', mode: kGitModeTree, id: blob),
    GitTreeEntry(name: 'a.b', mode: kGitModeFile, id: blob),
  ])).map((e) => e.name);
  expect(names, ['a.b', 'a', 'a0']);
});
test('tree and commit bytes match stock git', () async { /* see Step 1b */ });
test('commit round-trips through encode and decode', () { /* tree, 0 and 1 parents, message */ });
```

Step 1b: the "match stock git" test writes a blob, a two-entry tree and a commit with `git hash-object -w`, `git mktree` and `git commit-tree` (env `GIT_AUTHOR_DATE`/`GIT_COMMITTER_DATE` fixed to `1700000000 +0000`, name and email fixed) in a temp repo under `Directory.systemTemp.createTempSync()`. It asserts our ids are equal. When `git` is not on PATH, it fails if `Platform.environment['CI'] == 'true'` and skips otherwise.

- [ ] **Step 2: Run to verify they fail.** `flutter test test/core/services/cloud_storage/git/git_objects_test.dart`. Expected: compile errors (types not defined).
- [ ] **Step 3: Implement both files.** Use `sha1` from `package:crypto`.
- [ ] **Step 4: Run to verify they pass.** Same command, all PASS.
- [ ] **Step 5: Commit** `feat(sync): Git object ids, trees and commits` (stage the two lib files and the test).

### Task 2: pkt-line codec

**Files:**
- Create: `lib/core/services/cloud_storage/git/pkt_line.dart`
- Test: `test/core/services/cloud_storage/git/pkt_line_test.dart`

**Interfaces:**
- Produces:
  - `sealed class Pkt` with `final class PktData extends Pkt { final Uint8List bytes; String get text /* utf8, trailing \n stripped */ }`, `PktFlush` (`0000`), `PktDelim` (`0001`), `PktResponseEnd` (`0002`).
  - `Uint8List pktData(List<int> payload)`, `Uint8List pktText(String line) /* appends \n */`, `const pktFlushBytes`, `const pktDelimBytes`.
  - `final class PktLineReader { PktLineReader(Stream<List<int>> source); Future<Pkt?> next() /* null at end of stream */; Future<Uint8List> readRemaining(); }`
  - `Stream<List<int>> demuxSideBand(PktLineReader reader, {void Function(String progress)? onProgress})`: yields band-1 payloads until flush; band 2 goes to `onProgress`; band 3 throws `GitException(GitErrorCode.server, ...)` with the message.

- [ ] **Step 1: Failing tests:** `pktText('# service=git-upload-pack')` encodes to `'001e# service=git-upload-pack\n'`. The reader splits a stream delivered in 1-byte chunks into the same packets. `0000`/`0001`/`0002` map to the three markers. A length below 4 other than the markers, or above `65520`, throws `GitException(GitErrorCode.unexpected)`. The side-band demux returns band-1 bytes in order, and a band-3 packet throws with its text.
- [ ] **Step 2: Run, verify FAIL.** `flutter test test/core/services/cloud_storage/git/pkt_line_test.dart`
- [ ] **Step 3: Implement.** The reader keeps a `BytesBuilder(copy: false)` buffer over a `StreamIterator`. `GitException` comes from Task 5's `git_errors.dart`; create that file now with the enum and class from Task 5's Interfaces, since this task needs it.
- [ ] **Step 4: Run, verify PASS.**
- [ ] **Step 5: Commit** `feat(sync): Git pkt-line codec`.

### Task 3: Pack reading

**Files:**
- Create: `lib/core/services/cloud_storage/git/pack_inflater.dart`, `pack_reader.dart`, `git_object_store.dart`
- Create fixtures: `test/fixtures/git/regenerate.sh`, `test/fixtures/git/*.pack` with a `README.md` stating how they were made
- Test: `test/core/services/cloud_storage/git/pack_reader_test.dart`, `git_object_store_test.dart`

**Interfaces:**
- Consumes: Task 1 types.
- Produces:
  - `({Uint8List data, int consumed}) inflateAt(Uint8List buf, int offset, {int? expectedSize})`: inflates one zlib stream starting at `offset`. `consumed` is the exact byte count of that zlib stream, including its 2-byte header and 4-byte Adler-32 trailer. Built on `archive`'s `Inflate.stream(InputMemoryStream(buf)..position = offset)`. Correct the read-ahead: after inflation, subtract the whole bytes still held in the bit buffer, then verify the Adler-32 at the corrected position. If the check fails, scan forward at most 4 bytes for a matching Adler-32. If none matches, throw `GitException(GitErrorCode.unexpected)`.
  - `abstract interface class GitObjectStore { Future<GitStoredObject?> get(GitObjectId id); Future<void> put(GitStoredObject object); Future<bool> has(GitObjectId id); }` with `final class GitStoredObject { final GitObjectId id; final GitObjectType type; final Uint8List body; }`.
  - `final class MemoryGitObjectStore implements GitObjectStore`.
  - `final class FileGitObjectStore implements GitObjectStore { FileGitObjectStore(Directory root, {int maxBytes = 256 * 1024 * 1024}); }`: one file per object at `<root>/<hex[0..2]>/<hex[2..]>`, holding a 1-byte type code followed by the raw body. Least-recently-used eviction above `maxBytes`, using file access order kept in memory and rebuilt from `stat` on first use.
  - `Future<List<GitObjectId>> readPack(Uint8List pack, GitObjectStore store)`: verifies `PACK` v2 header and trailing SHA-1, and stores every object (deltas resolved against objects earlier in the pack or already in `store`). Returns ids in pack order. Throws `GitException(GitErrorCode.unexpected)` on any malformed input.

- [ ] **Step 1: Generate fixtures.** `regenerate.sh` builds a temp repo with stock git (fixed author/date env). It contains 40 small text files, one 2 MB random-ish binary, and a second commit editing 10 files. It produces:
  - `full.pack`: `git pack-objects --stdout` of everything, which has OFS deltas;
  - `thin_refdelta.pack`: `--thin` against the first commit, with `--no-delta-base-offset`, which has REF deltas;
  - `expected_ids.txt`: every object id from `git verify-pack -v`.

  Run it once and commit its outputs.
- [ ] **Step 2: Failing tests:**
  - `readPack(full.pack)` stores exactly the ids in `expected_ids.txt`, each re-hashing to its own id.
  - `thin_refdelta.pack` resolves when the store is pre-seeded with the first commit's objects from `full.pack`. It throws `GitException` when it isn't.
  - A pack with one flipped trailer byte throws.
  - `inflateAt` over a buffer holding 200 consecutive tiny zlib streams (made with `ZLibEncoder`) returns each `consumed` exactly. This is the classic read-ahead failure.
  - `FileGitObjectStore` evicts the least recently read object once over `maxBytes`, and survives a new instance on the same directory.
- [ ] **Step 3: Run, verify FAIL.**
- [ ] **Step 4: Implement.** Delta application per Git's format: varint source and target sizes, copy ops (bit 0x80) and insert ops. Reject a delta whose result size mismatches.
- [ ] **Step 5: Run, verify PASS.** Run both test files.
- [ ] **Step 6: Commit** `feat(sync): Git pack reader and object store`.

### Task 4: Pack writing

**Files:**
- Create: `lib/core/services/cloud_storage/git/pack_writer.dart`
- Test: `test/core/services/cloud_storage/git/pack_writer_test.dart`

**Interfaces:**
- Consumes: Tasks 1 and 3.
- Produces:
  - `final class PackEntrySource { PackEntrySource.bytes(GitObjectType type, Uint8List body); PackEntrySource.file(GitObjectType type, File file, int size); final GitObjectType type; final int size; Stream<List<int>> open(); }`
  - `Stream<List<int>> writePack(List<PackEntrySource> entries)`: header, each object as a type/size varint header plus a deflate stream (`ZLibEncoder`), then the SHA-1 of everything written. It streams file-backed entries without buffering the whole file.
  - `Future<GitObjectId> hashFileBlob(File file)`: streaming blob hash.

- [ ] **Step 1: Failing tests:**
  - A pack of a blob, a tree and a commit read back with `readPack` gives the same three ids.
  - A file-backed 3 MB blob streams, and its id equals `hashFileBlob`.
  - With `git` available: `git index-pack --stdin` in a bare temp repo accepts our pack and `git cat-file -t <id>` gives each type. This follows the Task 1 rule for CI versus skip.
- [ ] **Step 2: Run, verify FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run, verify PASS.**
- [ ] **Step 5: Commit** `feat(sync): Git pack writer`.

### Task 5: Smart HTTP transport and the test server

**Files:**
- Create: `lib/core/services/cloud_storage/git/git_errors.dart` (if not created in Task 2), `git_remote.dart`, `git_http_transport.dart`
- Create: `test/helpers/git_http_backend_server.dart`
- Test: `test/core/services/cloud_storage/git/git_http_transport_test.dart`

**Interfaces:**
- Produces:
  - `enum GitErrorCode { invalidConfig, unauthorized, forbidden, notFound, notGit, unreachable, untrustedCertificate, staleTip, protectedBranch, tooLarge, rateLimited, branchHasOtherContent, publicRepoUnencrypted, server, unexpected }`
  - `class GitException extends CloudStorageException { GitException(String message, {required this.code, this.statusCode, this.host, this.sizeBytes, this.serverReason, Object? cause}); final GitErrorCode code; ... }`
  - `class GitUntrustedCertificateException extends GitException { GitUntrustedCertificateException(this.certificate, {Object? cause}); final WebDavCertificateDetails certificate; }`
  - `final class GitRemote { const GitRemote({required Uri cloneUrl, required String username, required String token, String? pinnedCertSha256}); String get host; int get port; }`
  - `final class GitRefAdvertisement { final int protocolVersion /* 2 or 0 */; final String? headSymref /* e.g. 'refs/heads/main', null for an empty repo */; final GitObjectId? branchTip; final bool supportsFilter; final bool supportsShallow; }`
  - `class GitHttpTransport {`
    - `GitHttpTransport(GitRemote remote, {http.Client? client});` The default client is `createWebDavHttpClient(CertificateTrustRecorder(expectedHost: remote.host, expectedPort: remote.port, pinnedSha256: remote.pinnedCertSha256))`.
    - `Future<GitRefAdvertisement> lsRefs(String branch);`
    - `Future<void> fetch(List<GitObjectId> wants, GitObjectStore into, {int depth = 1, bool blobless = false, Set<GitObjectId> haves = const {}});`
    - `Future<void> fetchBlobs(List<GitObjectId> ids, GitObjectStore into);` This is v2 `fetch` with `want <blob>`. Where unsupported, it throws `GitException(GitErrorCode.unexpected)` so the caller can refetch the tip without filter.
    - `Future<void> push({required String branch, required GitObjectId? oldTip, required GitObjectId newTip, required Stream<List<int>> pack});` A history reset is just a push whose `newTip` does not descend from `oldTip`; the old/new ids carry the compare-and-swap, so there is no separate force flag on the wire. It parses `report-status` and maps `ng` reasons:
      - `fetch first`, `non-fast-forward`, `stale info` or `failed to lock` map to `staleTip`;
      - `protected branch`, `pre-receive hook declined` with "protected", or `denied` with "force" map to `protectedBranch`;
      - "too large", "exceeds" or "size" map to `tooLarge`;
      - anything else maps to `server` with `serverReason`.
    - `Future<void> checkPushAccess();` This is authenticated `GET info/refs?service=git-receive-pack`.
    - `Future<bool?> isPubliclyReadable();` An anonymous `GET info/refs?service=git-upload-pack` returns true on 200 with a Git content type, false on 401/403/404, and null otherwise.
    - `void close(); }`
  - HTTP mapping:
    - 401 maps to `unauthorized`, 403 to `forbidden` and 404 to `notFound`.
    - 429, or a 403 with `Retry-After`, maps to `rateLimited`.
    - 413 maps to `tooLarge`.
    - A 200 whose content type is not `application/x-git-*` maps to `notGit`.
    - Socket and timeout errors map to `unreachable` with the host.
    - A TLS rejection recorded by the trust recorder maps to `GitUntrustedCertificateException`.
    - Basic auth uses `username:token`.
  - Test server: `Future<GitTestServer> startGitTestServer({bool allowFilter = true, bool protocolV2 = true, String? requireUser, String? requirePassword, bool anonymousRead = false})`, returning `{Uri baseUrl; Directory reposRoot; Future<Directory> createBareRepo(String name, {bool withMainCommit = false}); Future<void> close();}`. The server binds `InternetAddress.loopbackIPv4` on port 0 and pipes each request to `git http-backend` as CGI. CGI environment:
    - `GIT_PROJECT_ROOT`, `GIT_HTTP_EXPORT_ALL=1`, `PATH_INFO`, `REQUEST_METHOD`, `QUERY_STRING`, `CONTENT_TYPE`;
    - `GIT_PROTOCOL` from the request header;
    - `REMOTE_USER` when auth passed.

    Repo config: `http.receivepack true`, `uploadpack.allowFilter`, `uploadpack.allowAnySHA1InWant true`, and `protocol.version` per the flags.

    Plain HTTP on loopback is allowed only in tests: `GitHttpTransport` accepts `http://127.0.0.1`. The `https`-only rule lives in `GitConfig.validate`, not the transport.

- [ ] **Step 1: Failing tests** (all against `startGitTestServer`; each test closes its server in `addTearDown`):
  - `lsRefs` on an empty repo reports `branchTip == null`. On a repo with `main`, it reports `headSymref == 'refs/heads/main'`.
  - Pushing a pack (Task 4) that creates `refs/heads/submersion-sync`, then `lsRefs('submersion-sync')`, gives the new tip. Stock `git log` in the bare repo shows the commit.
  - A second push with a stale `oldTip` throws `GitException` with `code == staleTip`.
  - A blobless fetch of the tip stores the commit and trees but not blobs, and `fetchBlobs` then stores the blob.
  - With `allowFilter: false`, `fetch(blobless: true)` still succeeds (falls back to a full depth-1 fetch). **(Review Focus 3)**
  - With `protocolV2: false`, `lsRefs` reports `protocolVersion == 0`, and fetch and push both work. **(Review Focus 3)**
  - With `requireUser`, a wrong token maps to `unauthorized`, and `checkPushAccess` succeeds with the right one.
  - With `anonymousRead: true`, `isPubliclyReadable()` is true, and false without it.
  - An address that serves plain HTML maps to `notGit`. A closed port maps to `unreachable`.
- [ ] **Step 2: Run, verify FAIL.**
- [ ] **Step 3: Implement the server helper, then the transport.**
  - v2 fetch request: `command=fetch`, delim, `thin-pack`, `ofs-delta`, `deepen 1`, optional `filter blob:none`, `want` lines, `done`, flush.
  - Response: read sections until `packfile`, then de-multiplex band 1 into a buffer and call `readPack`.
  - v0 fallback: the classic `want ... capabilities` upload-pack negotiation with `deepen 1`.
- [ ] **Step 4: Run, verify PASS.**
- [ ] **Step 5: Commit** `feat(sync): Git smart HTTP transport`.

### Task 6: Branch session

**Files:**
- Create: `lib/core/services/cloud_storage/git/git_branch_files.dart`, `git_tree_editor.dart`, `git_branch_session.dart`
- Test: `test/core/services/cloud_storage/git/git_branch_session_test.dart` (against the Task 5 server), `git_tree_editor_test.dart`

**Interfaces:**
- Consumes: Tasks 1 to 5.
- Produces:
  - `final class GitIndexEntry { final GitObjectId blobId; final int size; final int modifiedMs; }`; `final class GitIndex { final Map<String, GitIndexEntry> entries; Uint8List encode() /* UTF-8 JSON, keys sorted, {"version":1,"files":{path:{"blob":hex,"size":n,"mtime":ms}}} */; static GitIndex decode(Uint8List); }`
  - `final class GitBranchMeta { const GitBranchMeta({this.formatVersion = 1, this.deletedBytesSinceReset = 0, this.lastResetAtMs}); Uint8List encode(); static GitBranchMeta decode(Uint8List); GitBranchMeta copyWith(...); }`
  - `const String kGitMetaPath = '.submersion/branch.json'; const String kGitIndexPath = '.submersion/index.json'; const String kGitReadmePath = 'README.md'; const int kGitHistoryResetThresholdBytes = 256 * 1024 * 1024;`
  - `Future<({GitObjectId root, List<PackEntrySource> newObjects})> editTree(GitObjectStore store, GitObjectId? root, {required Map<String, ({GitObjectId id, PackEntrySource? source})> puts, required Set<String> deletes})`: paths use `/`; intermediate trees are created or removed as needed; unchanged subtrees are reused by id.
  - `final class GitCommitIdentity { const GitCommitIdentity({required this.name, required this.messageLabel}); }`
  - `final class GitBranchSnapshot { final GitObjectId tip; final GitObjectId rootTree; final GitIndex index; final GitBranchMeta meta; final bool isDefaultBranch; }`
  - `final class GitChange { GitChange({this.puts = const {}, this.deletes = const {}}); final Map<String, GitPut> puts; final Map<String, GitObjectId> deletes /* path -> blob id seen when listed */; }`; `final class GitPut { GitPut.bytes(Uint8List data); GitPut.file(File file); }`
  - `class GitBranchSession {`
    - `GitBranchSession({required GitHttpTransport transport, required GitObjectStore store, required String branch, required Future<GitCommitIdentity> Function() identity, DateTime Function()? clock, Duration Function(int attempt)? retryDelay, int maxAttempts = 4, int resetThresholdBytes = kGitHistoryResetThresholdBytes});`
    - `Future<GitBranchSnapshot> open();` Applies the safety rules:
      - creates a parentless commit with README, meta and index when the branch is absent (including an empty repo);
      - adopts the branch when its tip tree has `kGitMetaPath`;
      - otherwise throws `GitException(code: branchHasOtherContent)`.
    - `Future<GitBranchSnapshot> refresh();` Runs `lsRefs`, and a blobless fetch only when the tip moved.
    - `GitBranchSnapshot? get current;`
    - `Future<GitBranchSnapshot> commit(GitChange change, {required String messagePrefix /* 'Sync' or 'Backup' */});`
    - `Future<Uint8List> readFile(String path);`
    - `Future<void> readFileTo(String path, File destination);`
    - `Future<bool> resetHistoryIfDue({bool force = false});`
    - `}`
  - `commit` semantics:
    - Build on `current`. Drop each delete whose current index entry's blob id differs from the one recorded, or whose path is gone.
    - Write the new index (puts carry `size` and `modifiedMs = clock()`), and add the removed and replaced blob sizes plus the old index blob's size to `deletedBytesSinceReset`.
    - Push. On `staleTip`, `refresh()` and rebuild from the same `GitChange`, up to `maxAttempts`, then rethrow.
    - **Lost-reply rule:** before rebuilding after any push error other than `staleTip`, call `refresh()`. If the new tip's index already maps every put path to the put's blob id and lacks every applied delete path, treat the commit as done. **(Review Focus 1)**
    - A change that alters nothing after delete-dropping makes no commit and returns `current`.
  - Reset semantics: due when `meta.deletedBytesSinceReset >= kGitHistoryResetThresholdBytes` or `force`. Push a parentless commit of the current root tree with meta zeroed and `lastResetAtMs = clock()`, `oldTip = current.tip`. On `staleTip` return false (try again after the next sync). On `protectedBranch` rethrow.

- [ ] **Step 1: Failing tests:**
  - `open()` on an empty repo creates the branch with the three root files and returns `isDefaultBranch == true`. A second session on another store adopts it.
  - `open()` with branch `main` on a repo whose `main` has a user commit throws `branchHasOtherContent`, and the bare repo's `main` is unchanged (same tip via `git rev-parse`). This is the anti-goal 1 test.
  - `commit` with a put makes the file listable from a fresh session with the right size and `modifiedMs`.
  - Two sessions commit different paths concurrently. Both succeed, and the final tree holds both. This is the stale-tip rebuild.
  - A delete recorded with an old blob id is dropped after a peer rewrote the path. The file survives.
  - Lost reply: wrap the transport so `push` sends, then throws `GitException(unreachable)`. `commit` returns success, and `git rev-list --count` shows exactly one new commit. **(Review Focus 1)**
  - Reset: after puts and deletes pushing the counter past a threshold injected at 1 KB through a constructor parameter `resetThresholdBytes` (default `kGitHistoryResetThresholdBytes`), `resetHistoryIfDue()` returns true. Then `git rev-list --count refs/heads/submersion-sync` is 1, the tree is unchanged, and the meta counter is 0.
  - Reset racing a peer commit returns false and loses no data.
  - Tree editor: putting `Submersion Sync/a` into an empty root creates the subtree. Deleting the last file in a directory removes the directory entry. An untouched subtree keeps its id.
- [ ] **Step 2: Run, verify FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run, verify PASS.**
- [ ] **Step 5: Commit** `feat(sync): Git branch session with safety rules and history reset`.

### Task 7: Configuration, host detection, credentials

**Files:**
- Create: `lib/core/services/cloud_storage/git/git_config.dart`, `git_credentials_store.dart`
- Modify: `lib/core/services/accounts/account_identity.dart` (add `gitNaturalKey`)
- Test: `test/core/services/cloud_storage/git/git_config_test.dart`, `git_credentials_store_test.dart`

**Interfaces:**
- Produces:
  - `const String kDefaultGitBranch = 'submersion-sync';`
  - `enum GitHostKind { github, gitlab, bitbucket, giteaLike, other }` and `GitHostKind detectGitHost(Uri cloneUrl)`. Rules:
    - `github.com` maps to github;
    - `gitlab.com`, or a host containing `gitlab`, maps to gitlab;
    - `bitbucket.org` maps to bitbucket;
    - `codeberg.org`, `gitea.com`, or a host containing `gitea` or `forgejo`, maps to giteaLike;
    - anything else maps to other.
  - `class GitConfig { factory GitConfig({required String repoUrl, required String username, required String token, String branch = kDefaultGitBranch, String? pinnedCertSha256}); final Uri cloneUrl; final String username; final String token; final String branch; final String? pinnedCertSha256; String? validate(); GitRemote toRemote(); String get displayLabel /* '<owner/path> @ <host>' */; String get repoPath; GitHostKind get hostKind; Map<String, Object?> toJson(); factory GitConfig.fromJson(Map<String, Object?>); GitConfig copyWith(...); toString() never prints the token }`
  - Normalization:
    - trim;
    - lowercase the host;
    - drop `www.` for github.com;
    - strip trailing `/`;
    - append `.git` when the last segment lacks it;
    - keep every path segment (GitLab subgroups);
    - token trimmed of surrounding whitespace;
    - username trimmed.
  - `validate()` returns an English message, or null. It refuses:
    - a scheme other than `https`;
    - an empty host or path;
    - userinfo in the URL;
    - a query or fragment;
    - an empty username or token;
    - a token with inner whitespace;
    - an invalid branch name under Git's ref rules: no space, `~^:?*[\`, `..`, `@{`, or control characters; not starting with `-` or `/` and not ending with `/`, `.` or `.lock`; not starting with `refs/`; not empty.
  - `class GitCredentialsStore { GitCredentialsStore({FlutterSecureStorage? storage, String? storageKey}); static const String storageKey = 'sync_git_config'; Future<GitConfig?> load(); Future<void> save(GitConfig); Future<void> clear(); }` and `GitConfig? decodeGitConfig(String? raw)` (never throws).
  - `String gitNaturalKey(GitConfig config) => '${config.cloneUrl}|${config.branch}';`

- [ ] **Step 1: Failing tests:**
  - These all normalize to `https://github.com/you/dive-log.git` **(Review Focus 2)**:
    - `https://github.com/you/dive-log`
    - `https://GitHub.com/you/dive-log/`
    - `https://www.github.com/you/dive-log.git`
    - `https://github.com/you/dive-log.git/`
  - `https://gitlab.com/group/sub/repo` normalizes to `.../group/sub/repo.git` with `hostKind == gitlab`.
  - `detectGitHost` gives the expected kind for one URL per rule.
  - `'  ghp_abc\n'` trims to `ghp_abc`, and `'ghp a'` fails validation **(Review Focus 5)**.
  - Each invalid branch name fails, and `submersion-sync` and `sync/dev` pass **(Review Focus 4)**.
  - `http://` fails, and so does `https://u:p@host/r`.
  - JSON round-trips, `toString` omits the token, and a corrupt blob decodes to null.
- [ ] **Step 2: Run, verify FAIL.**
- [ ] **Step 3: Implement.** The store follows `WebDavCredentialsStore` (`FallbackSecureStorage`).
- [ ] **Step 4: Run, verify PASS.**
- [ ] **Step 5: Commit** `feat(sync): Git backend configuration and credentials`.

### Task 8: GitStorageProvider and the deferred-write seam

**Files:**
- Create: `lib/core/services/cloud_storage/deferred_write_provider.dart`, `lib/core/services/cloud_storage/git_storage_provider.dart`
- Modify: `lib/core/services/cloud_storage/encrypting_cloud_storage_provider.dart` (forward both interfaces to `inner`)
- Test: `test/core/services/cloud_storage/git_storage_provider_test.dart`, `test/core/services/cloud_storage/deferred_write_provider_test.dart`, and extend `encrypting_cloud_storage_provider_test.dart`

**Interfaces:**
- Produces:
  - `abstract interface class DeferredWriteProvider { Future<void> flush(); }`
  - `abstract interface class HistoryResettable { Future<void> resetHistoryNow(); }`
  - `Future<void> flushDeferredWrites(CloudStorageProvider p)`: calls `flush()` when `p is DeferredWriteProvider`, else returns.
  - `Future<void> resetHistoryNowIfSupported(CloudStorageProvider p)`: when `p is HistoryResettable`, flushes and then resets.
  - `EncryptingCloudStorageProvider` implements both, forwarding to `inner` when `inner` supports them.
  - `typedef GitSessionFactory = GitBranchSession Function(GitConfig config);`
  - `class GitStorageProvider with CloudStorageProviderMixin implements CloudStorageProvider, DeferredWriteProvider, HistoryResettable {`
    - Constructor: `GitStorageProvider({GitCredentialsStore? store, GitSessionFactory? sessionFactory, Future<GitCommitIdentity> Function()? identity, Future<bool> Function()? encryptionEnabled, Duration deleteQuietPeriod = const Duration(seconds: 5), Duration maxPacingWait = const Duration(seconds: 10), Duration uploadBudget = const Duration(seconds: 45)});`
    - `providerName => 'Git'; providerId => 'git';`
    - `Future<GitConfig?> loadConfig(); Future<void> saveConfig(GitConfig); void forgetCachedConfig();`
    - `Future<GitConnectionReport> testConnection(GitConfig config);`
    - `DateTime? get lastKnownResetAt; String? get lastKnownBranch;` These come from the latest snapshot, with no network.
    - `}`
  - `final class GitConnectionReport { final bool branchExists; final bool willBecomeDefault; final bool isPublic; }`
  - Mapping (`fileId` is the tree path; `folderId` is a top-level directory name):
    - `getOrCreateSyncFolder()` returns `'Submersion Sync'` (no network beyond `open()`).
    - `createFolder(name, parentFolderId:)` returns `parent/name` (folders exist implicitly).
    - `listFiles` reads the index under `folderId ?? 'Submersion Sync'` (direct children only, `namePattern` is a substring as in WebDAV), hiding pending deletes, after one `refresh()`.
    - `getFileInfo` and `fileExists` read the index.
    - `uploadFile`/`uploadFileFromPath` commit one put, with message prefix `Backup` when the folder is `Submersion Backups`, else `Sync`.
    - `downloadFile`/`downloadToFile` use `readFile`/`readFileTo`.
    - `deleteFile` records `path -> blob id from the current index` in the pending set and arms the quiet-period timer.
    - `flush()` commits all pending deletes in one commit and then runs `resetHistoryIfDue()`.
    - `resetHistoryNow()` runs `flush()`, then `resetHistoryIfDue(force: true)`.
    - Uploads fold any pending deletes into their own commit.
  - Pacing: no two pushes start less than 10 s apart. An upload waits for its slot at most `maxPacingWait`, then proceeds. The whole upload is wrapped in `uploadBudget`, throwing `GitException(unreachable)` on expiry.
  - `authenticate()`: loads the config (throws `invalidConfig` when absent) and `open()`s the session. Before the first push of the process, it runs the public check: if `isPubliclyReadable() == true` and `encryptionEnabled()` is false, it throws `GitException(code: publicRepoUnencrypted)` and every write method throws the same until the next successful check.
  - `testConnection`: `validate()`, `checkPushAccess()`, `lsRefs(branch)`. If the branch exists, it fetches the tip tree and checks for `kGitMetaPath` (throwing `branchHasOtherContent` if missing). Then `isPubliclyReadable()`. It saves nothing.
  - `isAuthenticated()` is presence only (no network), as WebDAV.
  - `signOut()` clears the store and invalidates.

- [ ] **Step 1: Failing tests** (provider over the Task 5 server, with a `GitSessionFactory` building sessions on a `MemoryGitObjectStore`):
  - Upload then `listFiles(folderId: 'Submersion Sync')` from a second provider instance shows the file with `sizeBytes` and `modifiedTime` from the index.
  - `deleteFile` makes no push (`git rev-list --count` unchanged) and hides the file from `listFiles` and `fileExists` at once. `flush()` pushes one commit removing it.
  - Ten `deleteFile` calls then `flush()` give exactly one commit.
  - Pending deletes fold into the next upload's commit.
  - The quiet-period timer flushes on its own (inject `deleteQuietPeriod: Duration(milliseconds: 50)`, real async with `runAsync` or plain `test`).
  - `uploadFileFromPath` of a 3 MB file into `Submersion Backups` commits with a message starting `Backup from`.
  - Public repo (`anonymousRead: true`) with `encryptionEnabled: () async => false`: the first upload throws `publicRepoUnencrypted`, and the bare repo has no new commit. With encryption on it succeeds.
  - `testConnection` reports `willBecomeDefault: true` on an empty repo, throws `branchHasOtherContent` for `main` with content, and maps a bad token to `unauthorized`.
  - `flushDeferredWrites` on a non-deferred fake is a no-op. On `EncryptingCloudStorageProvider(GitStorageProvider)` it reaches the inner flush.
  - Identity: with `encryptionEnabled` true and an identity source naming the device "Eric's iPhone", the commit author is `Submersion 1234abcd` and the message contains no display name.
- [ ] **Step 2: Run, verify FAIL.**
- [ ] **Step 3: Implement.** The identity default reads the device id and display name from `SyncRepository`, plus `SyncPreferences.syncEncryptionEnabled`. When encryption is on, it gives `GitCommitIdentity(name: 'Submersion ${deviceId.substring(0, 8)}', messageLabel: 'Submersion ${deviceId.substring(0, 8)}')`; otherwise it uses the display name for both.
- [ ] **Step 4: Run, verify PASS.**
- [ ] **Step 5: Commit** `feat(sync): Git storage provider`.

### Task 9: Flush and reset at the existing call sites

**Files:**
- Modify:
  - `lib/core/services/sync/sync_service.dart`: wrap `performSync` and `rebuildBackendFromThisDevice`, `executeLibraryReplace` and `adoptReplacedLibrary` so a `finally` calls `flushDeferredWrites(provider)`. This is best effort with a 20 s timeout, logged and never thrown. Also make `_deleteListedFiles` flush before it returns its `SyncCleanupOutcome`, and make `cleanupOldBackend` call `resetHistoryNowIfSupported(provider)` after its deletes.
  - `lib/core/services/sync/crypto/sync_encryption_service.dart` and the plaintext-backup removal caller in `lib/features/backup/data/services/backup_service.dart` (around line 1737): after removing plaintext copies, call `resetHistoryNowIfSupported`.
  - `backup_service.dart` lines around 560 and 1141 (backup deletes shown to the user): `flushDeferredWrites` before returning.
  - The library-wipe path (`executeLibraryReplace` wipes the cloud folder): `resetHistoryNowIfSupported` after the wipe.
- Test: extend `test/core/services/sync/` with `sync_service_flush_test.dart`, and extend the backup service tests.

**Interfaces:**
- Consumes: `flushDeferredWrites`, `resetHistoryNowIfSupported` (Task 8).

- [ ] **Step 1: List every `deleteFile` caller.** Run `grep -rn "\.deleteFile(" lib`. Record each caller in the commit message body as flushed by the end-of-run `finally` or flushed explicitly. As of this plan they are:
  - `sync_service.dart` 4277, 4539, 4583;
  - `sync_device_footprints.dart` 219;
  - `changeset_writer.dart` 623;
  - `sync_encryption_service.dart` 162;
  - `device_retirement.dart` 75;
  - `backup_service.dart` 560, 1141, 1737;
  - `shared_library_transport.dart`, which is out of scope (Git is never its provider).
- [ ] **Step 2: Failing tests:**
  - With a recording fake that implements `DeferredWriteProvider` and `HistoryResettable`, `performSync` calls `flush` exactly once even when the sync throws midway.
  - `cleanupOldBackend` calls `resetHistoryNow` once.
  - The backup service's delete-backup path calls `flush` before completing.
  - The plaintext purge calls `resetHistoryNow`.
- [ ] **Step 3: Run, verify FAIL.**
- [ ] **Step 4: Implement.**
- [ ] **Step 5: Run those tests plus `test/core/services/sync/` and `test/features/backup/`, verify PASS.**
- [ ] **Step 6: Commit** `feat(sync): flush deferred deletes and reset Git history after privacy deletes`.

### Task 10: Backend wiring

**Files:**
- Modify:
  - `lib/core/data/repositories/sync_repository.dart`: add `git` to `CloudProviderType`. `getCloudProvider` returns null for an unknown name instead of `googledrive`.
  - `lib/core/services/accounts/account_kind.dart`: `AccountKind.git` and both mappings.
  - `lib/core/services/cloud_storage/cloud_provider_instances.dart`: `_gitProvider`, `GitStorageProvider get gitProviderInstance`, and the switch arm.
  - `lib/core/services/accounts/adapters/git_account_adapter.dart` (create): mirrors `WebDavAccountAdapter` minus `MediaStoreCapable`.
  - `lib/core/providers/account_providers.dart`: register it.
  - `lib/core/services/accounts/account_deduplicator.dart`: a Git arm beside WebDAV's.
  - `lib/features/settings/presentation/providers/sync_providers.dart`:
    - `ensureAccountForProviderType` treats `git` as an instance kind like WebDAV, using `gitNaturalKey`;
    - `_mirrorLegacyCredentials` maps `AccountKind.git => GitCredentialsStore.storageKey`;
    - `signOut` treats `git` like `s3`/`webdav`;
    - line 1330's `firstWhere` gets `orElse` handling, logging and skipping an unknown id;
    - invalidate `gitConfigProvider` on sign-out.
  - `lib/features/settings/presentation/providers/git_providers.dart` (create): `gitStorageProviderInstanceProvider`, `gitConfigProvider`, `gitCredentialsStoreProvider`.
  - `lib/features/media_store/data/media_store_service.dart`: the `git` arm returns null, with a comment that Git is not a media store.
  - `lib/core/services/sync/sync_initializer.dart` and the headless provider path: confirm `git` resolves through `cloudProviderInstanceFor`; add an arm where a switch requires it.
  - Every other exhaustive switch the analyzer reports after adding the enum values.
- Test: extend `test/core/services/accounts/` with `git_account_adapter_test.dart`. Extend `sync_providers_account_dedup_test.dart` with a Git case. Add `sync_repository` unknown-name test.

- [ ] **Step 1: Failing tests:**
  - `SyncRepository.getCloudProvider()` with stored name `'nonsense'` returns null.
  - `AccountKind.fromCloudProviderType(CloudProviderType.git) == AccountKind.git`.
  - `ensureAccountForProviderType(CloudProviderType.git, ...)` returns the same account id for the same `GitConfig` twice, and a different one after the branch changes.
  - `GitAccountAdapter.disconnect` clears the sync blob only when the account is the sync endpoint.
  - `buildMediaObjectStore(CloudProviderType.git)` returns null.
- [ ] **Step 2: Run, verify FAIL.**
- [ ] **Step 3: Implement.** Then `flutter analyze`, and fix every non-exhaustive switch it lists.
- [ ] **Step 4: Run the new tests, then `test/core/services/accounts/`, `test/features/settings/presentation/providers/` and `test/features/media_store/`, verify PASS.**
- [ ] **Step 5: Commit** `feat(sync): wire the Git backend into providers and accounts`.

### Task 11: Setup screen, tile, wizard, strings, encryption guard

**Files:**
- Create: `git_config_page.dart`, `git_provider_tile.dart`, `git_host_note.dart`, `git_error_text.dart` (paths in File Structure)
- Modify:
  - `cloud_sync_page.dart`: tile after WebDAV, display-name arms;
  - `backup_sync_step.dart`: a Git tile after WebDAV, the `_providerName` arm `'Git'`, opening `GitConfigPage` the way `_openWebDavConfig` does;
  - `app_router.dart`: a `git-config` route beside `webdav-config`;
  - `encryption_settings_section.dart`;
  - all 11 `lib/l10n/arb/app_*.arb`, then `flutter gen-l10n`.
- Test: `test/features/settings/presentation/git_config_page_test.dart`, `test/features/settings/presentation/widgets/git_host_note_test.dart`, extend `cloud_sync_page_test.dart`, `backup_sync_step_test.dart`, and the encryption section's test.

**Interfaces:**
- Consumes: `GitStorageProvider.testConnection/saveConfig/loadConfig/lastKnownResetAt` (Task 8), `GitConfig` (Task 7), `gitConfigProvider` (Task 10), `showWebDavTrustDialog` (existing), `GitUntrustedCertificateException.certificate`.
- Produces: route `/settings/cloud-sync/git-config`; `Key('git-provider-tile')`.
- Page behaviour:
  - **Fields:** repository address, username, access token (obscured), branch (default `submersion-sync`).
  - **Helpers:** the copy is fixed by the spec:
    - address: "The HTTPS address you would clone from";
    - branch: "Submersion keeps this branch to itself and resets its history now and then, so the repository stays small. Your other branches are never touched."
  - **Host note:** `GitHostNote(hostKind)` updates as the address changes, showing the spec's per-host token text and a "How to create a token" link. The link opens the host's token documentation with `url_launcher`:
    - github: `https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens`
    - gitlab: `https://docs.gitlab.com/user/profile/personal_access_tokens/`
    - bitbucket: `https://support.atlassian.com/bitbucket-cloud/docs/using-api-tokens/`
    - giteaLike: `https://forgejo.org/docs/latest/user/token-scope/`
    - other: no link
  - **Buttons:** Test connection, Save, and Remove configuration (only when saved). The removal confirmation says the address and token are removed from this device and the repository is kept.
  - **Results:**
    - Success snack: "Connected. Submersion will create the branch {branch}." or "Connected to the Submersion branch {branch}." When `willBecomeDefault`, it adds that the branch will become the repository's default and suggests a repository used only for Submersion.
    - Save runs the same checks first. When `isPublic && !encryptionOn`, Save is refused with a dialog explaining the repository is public and offering "Turn on encryption", which pushes the existing encryption setup.
    - An untrusted certificate shows `showWebDavTrustDialog` and, on accept, retries with the pin.
  - **Tile:**
    - title "Git";
    - subtitle `config.displayLabel` and branch, or "Any Git host";
    - a second line "History last reset {date}" when `lastKnownResetAt` is known, with the date formatted with the app's date formatter and the user's settings;
    - same select/edit behaviour as `WebDavProviderTile`.
  - **Encryption guard:** in `encryption_settings_section.dart`, before `service.disable(`, when the selected provider is Git and `gitStorageProviderInstanceProvider.isPubliclyReadable` for the saved config is true, show a dialog saying encryption must stay on for a public repository, and return.
  - **Error text:** one localized string per `GitErrorCode`, each saying what to do next, following the spec's list. `tooLarge` names the size in MB, `unreachable` the host, and `protectedBranch` "Allow force push on the {branch} branch in the host's branch protection settings".
  - **Data health:** confirm `data_section_content.dart` and the health strip treat Git like WebDAV (no type-specific branch needed); add an arm wherever the analyzer requires one.
- [ ] **Step 1: Failing widget tests** (fake provider over an in-memory store, no network):
  - Typing `https://github.com/you/r` shows the GitHub note, and `https://gitlab.example.org/g/r` the GitLab one.
  - Save with an empty token shows the validation message and calls nothing.
  - Test connection with each `GitErrorCode` the fake throws shows that code's localized text.
  - Save on a public repo with encryption off shows the refusal dialog, and `saveConfig` is not called.
  - A `willBecomeDefault` success shows the default-branch note.
  - `CloudSyncPage` lists a `git-provider-tile`, and tapping its gear pushes `/settings/cloud-sync/git-config`.
  - `BackupSyncStep` shows a Git tile.
  - Turning encryption off with Git on a public repo shows the guard dialog, and `disable` is not called.
- [ ] **Step 2: Run, verify FAIL.**
- [ ] **Step 3: Add the strings to `app_en.arb` (group `settings_gitConfig_*`, `settings_cloudSync_provider_git_*`), translate into the other 10 ARB files, then `flutter gen-l10n`.**
- [ ] **Step 4: Implement the widgets and wiring.**
- [ ] **Step 5: Run the new and extended tests, plus `test/l10n/` (ARB guards), `test/architecture/` and `test/shared/`, verify PASS.**
- [ ] **Step 6: Commit** `feat(settings): Git setup screen, provider tile and strings`.

### Task 12: CI interop guarantee, docs, final checks

**Files:**
- Modify: the Linux test workflow under `.github/workflows/` that runs `flutter test` (find it with `grep -ln "flutter test" .github/workflows/*.yml`): ensure `git` is present (`git --version` step) and set `CI=true` (already set by GitHub Actions; assert it in the step).
- Create: `test/core/services/cloud_storage/git/git_interop_presence_test.dart`. It fails when `CI == 'true'` and `git` is not on PATH, so the interop tests can never silently skip in CI.
- Modify: user docs, if a sync backends page exists under `docs/` (check with `grep -rln "WebDAV" docs --include=*.md`). Add a short Git section: which token to create per host, the dedicated branch, history resets, the public-repo rule.
- Test: the presence test.

- [ ] **Step 1: Write the presence test, run it locally (PASS with git installed).**
- [ ] **Step 2: Update the workflow and docs.**
- [ ] **Step 3: Full verification:**
  - `dart format .`
  - `flutter analyze` (zero issues, infos included)
  - `flutter test test/core/services/cloud_storage/ test/core/services/sync/ test/core/services/accounts/ test/features/settings/ test/features/backup/ test/features/media_store/ test/features/setup_wizard/ test/architecture/ test/shared/ test/l10n/`

  Logs go to the scratchpad, and each run is checked for its exit status, not piped through grep.
- [ ] **Step 4: Commit** `ci(sync): require git for the Git backend interop tests` (plus `docs(sync): ...` if docs changed, as its own commit).
