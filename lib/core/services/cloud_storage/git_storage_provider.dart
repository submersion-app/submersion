import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/deferred_write_provider.dart';
import 'package:submersion/core/services/cloud_storage/git/git_branch_files.dart';
import 'package:submersion/core/services/cloud_storage/git/git_branch_session.dart';
import 'package:submersion/core/services/cloud_storage/git/git_config.dart';
import 'package:submersion/core/services/cloud_storage/git/git_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/git/git_errors.dart';
import 'package:submersion/core/services/cloud_storage/git/git_http_transport.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_id.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_store.dart';
import 'package:submersion/core/services/cloud_storage/git/git_reset_records.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/crypto/sync_envelope.dart';
import 'package:submersion/core/services/sync/sync_device_metadata.dart';
import 'package:submersion/core/services/sync/sync_preferences.dart';

typedef GitTransportFactory = GitHttpTransport Function(GitConfig config);
typedef GitStoreFactory = Future<GitObjectStore> Function(GitConfig config);
typedef GitDeviceSource =
    Future<({String deviceId, String? deviceName})> Function();

/// Who commits say they are from. Commit metadata is never encrypted, so
/// under encrypted sync the device's display name stays out of it.
GitCommitIdentity gitCommitIdentityFor({
  required String deviceId,
  required String? deviceName,
  required bool encrypted,
}) {
  final short = deviceId.length > 8 ? deviceId.substring(0, 8) : deviceId;
  final neutral = 'Submersion $short';
  final name = encrypted || deviceName == null || deviceName.trim().isEmpty
      ? neutral
      : deviceName.trim();
  return GitCommitIdentity(name: name, messageLabel: name);
}

/// What Test connection found, for the setup screen.
final class GitConnectionReport {
  const GitConnectionReport({
    required this.branchExists,
    required this.willBecomeDefault,
    required this.isPublic,
  });

  final bool branchExists;

  /// Creating the branch will make it the repository's default (the
  /// repository is empty).
  final bool willBecomeDefault;

  /// Anyone can read the repository without signing in.
  final bool isPublic;
}

/// Git implementation of [CloudStorageProvider], for any smart-HTTP host.
///
/// - A fileId is a path on the sync branch (`Submersion Sync/x.json`); a
///   folderId is a top-level directory name.
/// - Uploads are committed and pushed before they return. Deletes are
///   deferred and batched into one commit ([flush]), since the sync engine
///   tolerates a file that outlives its delete for a while.
/// - Nothing unencrypted is written to a public repository, the keyslot
///   file aside.
class GitStorageProvider
    with CloudStorageProviderMixin
    implements CloudStorageProvider, DeferredWriteProvider, HistoryResettable {
  GitStorageProvider({
    GitCredentialsStore? store,
    GitTransportFactory? transportFactory,
    GitStoreFactory? storeFactory,
    GitDeviceSource? device,
    Future<bool> Function()? encryptionEnabled,
    this.deleteQuietPeriod = const Duration(seconds: 5),
    this.maxPacingWait = const Duration(seconds: 10),
    this.minPushSpacing = const Duration(seconds: 10),
    this.uploadBudget = const Duration(seconds: 45),
    this.resetThresholdBytes = kGitHistoryResetThresholdBytes,
    this.allowLoopbackHttp = false,
  }) : _store = store ?? GitCredentialsStore(),
       _transportFactory =
           transportFactory ?? ((c) => GitHttpTransport(c.toRemote())),
       _storeFactory = storeFactory ?? _defaultStore,
       _device = device ?? _defaultDevice,
       _encryptionEnabled = encryptionEnabled ?? _defaultEncryptionEnabled;

  static final _log = LoggerService.forClass(GitStorageProvider);

  static const String backupFolderName = 'Submersion Backups';

  /// [providerId], for code that must treat Git differently: its listing
  /// times are each writer's own clock, not the host's.
  static const String id = 'git';

  /// The one file allowed into a public repository before encryption is on.
  static const String _keyslotPath =
      '${CloudStorageProviderMixin.syncFolderName}/${KeyslotFile.cloudFileName}';

  final GitCredentialsStore _store;
  final GitTransportFactory _transportFactory;
  final GitStoreFactory _storeFactory;
  final GitDeviceSource _device;
  final Future<bool> Function() _encryptionEnabled;
  final Duration deleteQuietPeriod;
  final Duration maxPacingWait;
  final Duration minPushSpacing;

  /// How long a sync upload may take once its push starts, stretched for a
  /// large payload (see [GitHttpTransport.deadlineAtLeast]).
  final Duration uploadBudget;

  /// Deleted bytes after which the branch history is reset.
  final int resetThresholdBytes;

  /// Accept plain http to this machine. Tests only: see
  /// [GitConfig.problems].
  final bool allowLoopbackHttp;

  GitConfig? _cachedConfig;
  GitBranchSession? _session;
  Future<GitBranchSession>? _starting;
  int _generation = 0;
  bool? _knownPublic;
  ({String deviceId, String? deviceName})? _knownDevice;
  DateTime? _lastPushStart;
  Timer? _deleteTimer;
  Future<void> _lock = Future.value();

  /// path -> blob id seen when the delete was asked for, or null when this
  /// instance had not seen the path (deleted whatever it holds).
  final Map<String, GitObjectId?> _pendingDeletes = {};

  /// Pending deletes whose push failed. They still go with the next commit,
  /// but are listed again, since they are still on the branch: a caller that
  /// retries must find them to delete them anew.
  final Set<String> _unpushedDeletes = {};

  /// Whether [path] is left out of listings: deleted here, not yet pushed,
  /// and no push of it has failed.
  bool _hidden(String path) =>
      _pendingDeletes.containsKey(path) && !_unpushedDeletes.contains(path);

  static Future<GitObjectStore> _defaultStore(GitConfig config) async {
    final support = await getApplicationSupportDirectory();
    final key = sha1.convert(utf8.encode(gitNaturalKey(config))).toString();
    return FileGitObjectStore(
      Directory(p.join(support.path, 'git_objects', key)),
    );
  }

  static Future<({String deviceId, String? deviceName})>
  _defaultDevice() async {
    final repo = SyncRepository();
    final id = await repo.getDeviceId();
    final name = (await SyncDeviceMetadata(repo).resolve()).name;
    return (deviceId: id, deviceName: name);
  }

  static Future<bool> _defaultEncryptionEnabled() async => SyncPreferences(
    await SharedPreferences.getInstance(),
  ).syncEncryptionEnabled;

  @override
  String get providerName => 'Git';

  @override
  String get providerId => id;

  @override
  Future<bool> isAvailable() async => true;

  /// Presence only, no network (UI rebuild paths call this).
  @override
  Future<bool> isAuthenticated() async => (await _loadConfig()) != null;

  Future<GitConfig?> loadConfig() => _loadConfig();

  Future<void> saveConfig(GitConfig config) async {
    await _store.save(config);
    _invalidate();
  }

  /// Drops the cached config and session, for when the stored config was
  /// changed or removed by someone other than this provider.
  void forgetCachedConfig() => _invalidate();

  @override
  Future<void> signOut() async {
    await _store.clear();
    _invalidate();
  }

  @override
  Future<String?> getUserEmail() async => (await _loadConfig())?.displayLabel;

  /// History reset outcomes for each repository and branch, as seen by any
  /// provider in this process. Process-wide because the active sync provider
  /// is built per account, apart from the settings singleton that the Cloud
  /// sync page reads; the page follows [GitResetRecords.changes].
  static final GitResetRecords resetRecords = GitResetRecords();

  /// Whether the host refused the last history reset of [config]'s branch
  /// (branch protection); the Cloud sync page says how to allow it.
  static bool resetRefusedFor(GitConfig config) =>
      resetRecords.statusFor(gitNaturalKey(config)).refused;

  /// When [config]'s branch was last reset, as far as this process has
  /// seen; no network.
  static DateTime? lastKnownResetFor(GitConfig config) =>
      resetRecords.statusFor(gitNaturalKey(config)).lastResetAt;

  /// When this provider's branch was last reset; no network.
  DateTime? get lastKnownResetAt {
    final config = _cachedConfig;
    return config == null ? null : lastKnownResetFor(config);
  }

  void _noteSnapshot(GitBranchSession session) {
    final ms = session.current?.meta.lastResetAtMs;
    final config = _cachedConfig;
    if (ms == null || config == null) return;
    resetRecords.noteReset(
      gitNaturalKey(config),
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
    );
  }

  void dispose() {
    _deleteTimer?.cancel();
    _invalidate();
  }

  // ---- Session --------------------------------------------------------------

  Future<GitConfig?> _loadConfig() async {
    final cached = _cachedConfig;
    if (cached != null) return cached;
    final generation = _generation;
    final loaded = await _store.load();
    if (generation != _generation) return _cachedConfig;
    return _cachedConfig = loaded;
  }

  Future<GitConfig> _requireConfig() async {
    final config = await _loadConfig();
    if (config == null) {
      throw GitException(
        'Git is not configured. Open the Git settings and enter your repository.',
        code: GitErrorCode.invalidConfig,
      );
    }
    return config;
  }

  /// The session, built once however many callers arrive first.
  Future<GitBranchSession> _requireSession() async {
    final existing = _session;
    if (existing != null) return existing;
    final pending = _starting;
    if (pending != null) return pending;
    final start = _startSession();
    _starting = start;
    try {
      return await start;
    } finally {
      if (identical(_starting, start)) _starting = null;
    }
  }

  Future<GitBranchSession> _startSession() async {
    while (true) {
      final generation = _generation;
      final config = await _requireConfig();
      final existing = _session;
      if (existing != null) return existing;
      final store = await _storeFactory(config);
      if (generation != _generation) continue;
      return _session = GitBranchSession(
        transport: _transportFactory(config),
        store: store,
        branch: config.branch,
        identity: _identity,
        resetThresholdBytes: resetThresholdBytes,
      );
    }
  }

  /// Who commits say they are from. The device is looked up once per
  /// session; the encryption setting every time, since it decides whether
  /// the device name may appear at all.
  Future<GitCommitIdentity> _identity() async {
    final device = _knownDevice ??= await _device();
    return gitCommitIdentityFor(
      deviceId: device.deviceId,
      deviceName: device.deviceName,
      encrypted: await _encryptionEnabled(),
    );
  }

  /// The session with its branch open. Opening may create the branch, but a
  /// new branch holds only the README and Submersion's own marker files, so
  /// it needs no public-repository check; data uploads do.
  Future<GitBranchSession> _opened() async {
    final session = await _requireSession();
    if (session.current == null) await session.open();
    return session;
  }

  /// The branch as the host has it now: opened on a new session, refreshed
  /// otherwise, so either way the refs are read once.
  Future<(GitBranchSession, GitBranchSnapshot)> _latest() async {
    final session = await _requireSession();
    final snap = session.current == null
        ? await session.open()
        : await session.refresh();
    return (session, snap);
  }

  void _invalidate() {
    _generation++;
    _session?.transport.close();
    _session = null;
    _starting = null;
    _cachedConfig = null;
    _knownPublic = null;
    _knownDevice = null;
    _pendingDeletes.clear();
    _unpushedDeletes.clear();
  }

  /// Writes queued or running in [_serial].
  int _writesInFlight = 0;

  /// Runs [action] after every write started before it, one at a time.
  Future<T> _serial<T>(Future<T> Function() action) {
    _writesInFlight++;
    final result = _lock.then((_) => action());
    void done() => _writesInFlight--;
    _lock = result.then((_) => done(), onError: (_) => done());
    return result;
  }

  /// Refuses to write plaintext to a repository anyone can read.
  ///
  /// Whether [put] is sealed is read from its first bytes (every encrypted
  /// sync file and `.sbe` backup starts with the SBE1 magic), never from the
  /// encryption setting: a locked device, or a sync begun before encryption
  /// was turned on, can still hand over plaintext. Whether the repository is
  /// public is asked once per session. An unclear answer (rate limit, server
  /// error, timeout) holds the upload back and is asked again next time,
  /// since guessing "private" could publish the data.
  Future<void> _ensurePublicSafe(
    GitBranchSession session,
    String path,
    GitPut put,
  ) async {
    // The keyslot file holds only a wrapped key, so it may land in a public
    // repository: without it, encryption could never be turned on.
    if (path == _keyslotPath) return;
    final head = await put.head(SyncEnvelope.magic.length);
    if (SyncEnvelope.hasMagic(head)) return;
    final bool public;
    try {
      public = _knownPublic ??= await session.transport.checkPubliclyReadable();
    } on GitException catch (e) {
      throw GitException(
        'Could not check whether the repository is public, so nothing '
        'unencrypted is uploaded yet.',
        code: e.code,
        host: e.host,
        cause: e,
      );
    }
    if (!public) return;
    throw GitException(
      path.startsWith('$backupFolderName/')
          ? 'The repository is public. Turn on backup encryption or make the '
                'repository private.'
          : 'The repository is public. Turn on encrypted sync or make the '
                'repository private.',
      code: GitErrorCode.publicRepoUnencrypted,
    );
  }

  Future<void> _pace() async {
    final last = _lastPushStart;
    if (last != null) {
      var wait = minPushSpacing - DateTime.now().difference(last);
      if (wait > maxPacingWait) wait = maxPacingWait;
      if (wait > Duration.zero) await Future<void>.delayed(wait);
    }
    _lastPushStart = DateTime.now();
  }

  @override
  Future<void> authenticate() async {
    final session = await _requireSession();
    await session.open();
    _log.info('Git branch ${session.branch} opened');
  }

  /// Validates unsaved [config] against the host without writing anything.
  Future<GitConnectionReport> testConnection(GitConfig config) async {
    final error = config.validate(allowLoopbackHttp: allowLoopbackHttp);
    if (error != null) {
      throw GitException(error, code: GitErrorCode.invalidConfig);
    }
    final transport = _transportFactory(config);
    try {
      await transport.checkPushAccess();
      final session = GitBranchSession(
        transport: transport,
        store: MemoryGitObjectStore(),
        branch: config.branch,
        identity: _identity,
      );
      final found = await session.inspect();
      final public = await transport.isPubliclyReadable();
      return GitConnectionReport(
        branchExists: found.exists,
        willBecomeDefault: found.willBecomeDefault,
        isPublic: public == true,
      );
    } finally {
      transport.close();
    }
  }

  /// Whether the saved repository can be read without signing in; null when
  /// there is no config or the host's answer is unclear.
  Future<bool?> isPubliclyReadable() async {
    final config = await _loadConfig();
    if (config == null) return null;
    final transport = _transportFactory(config);
    try {
      return await transport.isPubliclyReadable();
    } finally {
      transport.close();
    }
  }

  // ---- Writes ---------------------------------------------------------------

  Future<UploadResult> _write(
    String path,
    GitPut put, {
    required String messagePrefix,
  }) {
    final pushing = Completer<Duration>();
    final run = _serial(() async {
      final session = await _opened();
      await _ensurePublicSafe(session, path, put);
      // An older delete of this path rides along: the commit replaces the
      // file rather than deleting it, and the delete is cleared only once
      // that lands. If the upload fails, the delete still happens.
      await _pace();
      pushing.complete(
        GitHttpTransport.deadlineAtLeast(uploadBudget, await put.length()),
      );
      await _commitWithDeletes(
        session,
        puts: {path: put},
        messagePrefix: messagePrefix,
      );
      return UploadResult(fileId: path, uploadTime: DateTime.now().toUtc());
    });
    // Sync files are small and the engine's callers wrap them in their own
    // short timeouts, so they get a budget. Backups are large; a budget
    // would give up on a slow link while the push still lands, leaving a
    // copy the backup history never tracks.
    if (path.startsWith('$backupFolderName/')) return run;
    return _withinBudget(
      run,
      pushing.future,
      'The upload to the Git host took too long.',
    );
  }

  /// [run], or a [TimeoutException] with [message] once its push has run
  /// longer than its budget. Time spent behind earlier writes and waiting
  /// for pacing does not count, as [pushing] completes, with the budget,
  /// only when the push starts. A timeout rather than a failure: the push
  /// may still land, and the sync engine keeps its upload nonce for that
  /// case.
  Future<T> _withinBudget<T>(
    Future<T> run,
    Future<Duration> pushing,
    String message,
  ) {
    final result = Completer<T>();
    Timer? timer;
    unawaited(
      pushing.then((budget) {
        if (result.isCompleted) return;
        timer = Timer(budget, () {
          if (result.isCompleted) return;
          result.completeError(TimeoutException(message, budget));
        });
      }),
    );
    unawaited(
      run.then(
        (value) {
          timer?.cancel();
          if (!result.isCompleted) result.complete(value);
        },
        onError: (Object e, StackTrace stack) {
          timer?.cancel();
          if (!result.isCompleted) result.completeError(e, stack);
        },
      ),
    );
    return result.future;
  }

  /// Commits [puts] together with every pending delete. Deletes that landed
  /// are done; when the push fails they stay pending and are listed again.
  Future<void> _commitWithDeletes(
    GitBranchSession session, {
    Map<String, GitPut> puts = const {},
    required String messagePrefix,
  }) async {
    final deletes = Map<String, GitObjectId?>.of(_pendingDeletes);
    try {
      await session.commit(
        GitChange(puts: puts, deletes: deletes),
        messagePrefix: messagePrefix,
      );
    } on Object {
      _unpushedDeletes.addAll(deletes.keys.where(_pendingDeletes.containsKey));
      rethrow;
    }
    _noteSnapshot(session);
    for (final MapEntry(:key, :value) in deletes.entries) {
      if (_pendingDeletes[key] == value) {
        _pendingDeletes.remove(key);
        _unpushedDeletes.remove(key);
      }
    }
  }

  String _pathIn(String? folderId, String filename) =>
      '${folderId ?? CloudStorageProviderMixin.syncFolderName}/$filename';

  String _prefixFor(String path) =>
      path.startsWith('$backupFolderName/') ? 'Backup' : 'Sync';

  @override
  Future<UploadResult> uploadFile(
    Uint8List data,
    String filename, {
    String? folderId,
  }) {
    final path = _pathIn(folderId, filename);
    return _write(path, GitPut.bytes(data), messagePrefix: _prefixFor(path));
  }

  @override
  Future<UploadResult> uploadFileFromPath(
    String sourcePath,
    String filename, {
    String? folderId,
  }) {
    final path = _pathIn(folderId, filename);
    return _write(
      path,
      GitPut.file(File(sourcePath)),
      messagePrefix: _prefixFor(path),
    );
  }

  /// Records the delete; no network. The file disappears from listings at
  /// once and from the branch on the next commit or [flush].
  @override
  Future<void> deleteFile(String fileId) async {
    // A caller may delete by id without listing first (backup pruning on a
    // provider built for this account): record it unconditionally then.
    _pendingDeletes[fileId] = _session?.current?.index.entries[fileId]?.blobId;
    _unpushedDeletes.remove(fileId);
    _deleteTimer?.cancel();
    _deleteTimer = Timer(deleteQuietPeriod, () {
      unawaited(
        flush().catchError((Object e) {
          _log.warning(
            'Deferred Git delete failed; a later sweep retries',
            error: e,
          );
        }),
      );
    });
  }

  @override
  Future<void> flush({Duration? timeout}) {
    // Nothing deferred, and another write holds the branch: waiting for it
    // would only run the due-reset check, which the next flush runs anyway.
    if (_pendingDeletes.isEmpty && _writesInFlight > 0) return Future.value();
    final pushing = Completer<Duration>();
    final run = _serial(() async {
      _deleteTimer?.cancel();
      final deleting = _pendingDeletes.isNotEmpty;
      if (deleting) await _pace();
      // From here on the flush is doing its own work: opening the branch,
      // pushing, and the reset check all count against [timeout].
      if (timeout != null) pushing.complete(timeout);
      // Deletes recorded without a loaded branch still have to reach it.
      final session = deleting ? await _opened() : _session;
      if (session == null) return;
      if (_pendingDeletes.isNotEmpty) {
        await _commitWithDeletes(session, messagePrefix: 'Sync');
      }
      if (session.current != null) {
        // Best effort: the deletes above already landed, so a reset that
        // fails must not make the caller report them as failed. A due reset
        // is tried again on the next flush.
        try {
          await _resetIfDue(session, force: false);
        } on GitException catch (e) {
          _log.warning('History reset not done; retried later', error: e);
        }
      }
    });
    if (timeout == null) return run;
    return _withinBudget(
      run,
      pushing.future,
      'Pushing deletes to the Git host took too long.',
    );
  }

  /// Resets [session]'s history when due (or always, with [force]) and
  /// records the outcome for the Cloud sync page: a reset the host refuses
  /// as a protected branch is shown there, since it otherwise only logs.
  Future<void> _resetIfDue(
    GitBranchSession session, {
    required bool force,
  }) async {
    final config = _cachedConfig;
    final key = config == null ? null : gitNaturalKey(config);
    try {
      final reset = await session.resetHistoryIfDue(force: force);
      if (reset && key != null) resetRecords.noteRefused(key, refused: false);
      _noteSnapshot(session);
    } on GitException catch (e) {
      if (e.code == GitErrorCode.protectedBranch && key != null) {
        resetRecords.noteRefused(key, refused: true);
      }
      rethrow;
    }
  }

  @override
  Future<void> resetHistoryNow() async {
    await flush();
    await _serial(() async {
      await _resetIfDue(await _opened(), force: true);
    });
  }

  // ---- Reads ----------------------------------------------------------------

  @override
  Future<String> getOrCreateSyncFolder() async {
    await _opened();
    return CloudStorageProviderMixin.syncFolderName;
  }

  /// Folders exist implicitly on Git: a path is enough.
  @override
  Future<String> createFolder(
    String folderName, {
    String? parentFolderId,
  }) async =>
      parentFolderId == null ? folderName : '$parentFolderId/$folderName';

  @override
  Future<List<CloudFileInfo>> listFiles({
    String? folderId,
    String? namePattern,
  }) async {
    final (session, snap) = await _latest();
    _noteSnapshot(session);
    final prefix = '${folderId ?? CloudStorageProviderMixin.syncFolderName}/';
    final out = <CloudFileInfo>[];
    for (final MapEntry(:key, :value) in snap.index.entries.entries) {
      if (!key.startsWith(prefix)) continue;
      final name = key.substring(prefix.length);
      if (name.contains('/')) continue;
      if (_hidden(key)) continue;
      if (namePattern != null && !name.contains(namePattern)) continue;
      out.add(_info(key, name, value.size, value.modifiedMs));
    }
    return out;
  }

  CloudFileInfo _info(String path, String name, int size, int modifiedMs) =>
      CloudFileInfo(
        id: path,
        name: name,
        modifiedTime: DateTime.fromMillisecondsSinceEpoch(
          modifiedMs,
          isUtc: true,
        ),
        sizeBytes: size,
      );

  @override
  Future<CloudFileInfo?> getFileInfo(String fileId) async {
    if (_hidden(fileId)) return null;
    final (_, snap) = await _latest();
    final entry = snap.index.entries[fileId];
    if (entry == null) return null;
    return _info(
      fileId,
      p.posix.basename(fileId),
      entry.size,
      entry.modifiedMs,
    );
  }

  @override
  Future<bool> fileExists(String fileId) async =>
      (await getFileInfo(fileId)) != null;

  Future<GitBranchSession> _sessionHolding(String fileId) async {
    if (_hidden(fileId)) {
      throw GitException('$fileId was deleted.', code: GitErrorCode.notFound);
    }
    final session = await _opened();
    if (session.current?.index.entries.containsKey(fileId) != true) {
      await session.refresh();
    }
    return session;
  }

  @override
  Future<Uint8List> downloadFile(String fileId) async =>
      (await _sessionHolding(fileId)).readFile(fileId);

  @override
  Future<void> downloadToFile(String fileId, String destinationPath) async =>
      (await _sessionHolding(fileId)).readFileTo(fileId, File(destinationPath));
}
