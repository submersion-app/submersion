/// A lock held across every tab of the same origin while a sync runs.
///
/// Native builds have one process per app and a lock within it already
/// (`SyncCoordinator`), so the native file runs the body as it is. Two
/// browser tabs are two processes sharing one database: the web file holds
/// a Web Lock of the given name around the body, so two tabs never publish
/// at once and reuse one changeset sequence.
///
/// `withCrossTabLockIfAvailable` is the housekeeping form: it runs its body
/// only when nobody holds the lock, and says whether it did. Web Locks are
/// not reentrant, so a step that may run inside a sync asks that way.
library;

export 'package:submersion/core/platform/cross_tab_lock_io.dart'
    if (dart.library.js_interop) 'package:submersion/core/platform/cross_tab_lock_web.dart';

/// The lock name every tab's sync runs under.
const String kSyncCrossTabLock = 'submersion-sync';
