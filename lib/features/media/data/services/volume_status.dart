import 'dart:io';

/// Classifies whether the VOLUME a path lives on is currently mounted, so
/// "file on an unmounted network share" can be told apart from "file
/// deleted" (program spec section 8).
///
/// Mount-root heuristics per platform:
/// - macOS: `/Volumes/<name>/...` (external and network mounts); anything
///   else is the always-mounted system volume.
/// - Windows: `X:\...` drive roots and `\\server\share\...` UNC roots.
/// - Linux: `/mnt/<name>`, `/media/<name>` (legacy single-segment mounts),
///   `/media/<user>/<name>`, `/run/media/<user>/<name>`.
///
/// The existence probe is injectable so tests never touch the real
/// filesystem. Only the volume ROOT is probed - a missing file on a
/// mounted volume stays "deleted".
class VolumeStatus {
  VolumeStatus({Future<bool> Function(String path)? directoryExists})
    : _directoryExists =
          directoryExists ?? ((path) => Directory(path).exists());

  /// Async so an offline network mount cannot block the UI isolate while
  /// the probe waits on the filesystem.
  final Future<bool> Function(String path) _directoryExists;

  /// The mount root governing [path], or null when the path lives on the
  /// system volume (always considered mounted).
  String? volumeRootOf(String path, {String? platformOverride}) {
    final platform =
        platformOverride ??
        (Platform.isMacOS
            ? 'macos'
            : Platform.isWindows
            ? 'windows'
            : Platform.isLinux
            ? 'linux'
            : 'other');
    switch (platform) {
      case 'macos':
        final match = RegExp(r'^(/Volumes/[^/]+)(/|$)').firstMatch(path);
        return match?.group(1);
      case 'windows':
        final unc = RegExp(r'^(\\\\[^\\]+\\[^\\]+)(\\|$)').firstMatch(path);
        if (unc != null) return unc.group(1);
        final drive = RegExp(r'^([A-Za-z]:)(\\|/|$)').firstMatch(path);
        // The system drive C: is always mounted; other drive letters can
        // be network mappings or removable media.
        if (drive != null && drive.group(1)!.toUpperCase() != 'C:') {
          return '${drive.group(1)}\\';
        }
        return null;
      case 'linux':
        // Candidate roots, most specific first. A root must be a PROPER
        // prefix of the path (followed by '/'): otherwise the optional
        // second segment would swallow the file name itself (e.g.
        // /media/usb/a.jpg must resolve to /media/usb, not the file).
        for (final pattern in [
          r'^(/run/media/[^/]+/[^/]+)/',
          r'^(/media/[^/]+/[^/]+)/',
          r'^(/media/[^/]+)/',
          r'^(/mnt/[^/]+)/',
        ]) {
          final match = RegExp(pattern).firstMatch(path);
          if (match != null) return match.group(1);
        }
        return null;
      default:
        return null;
    }
  }

  /// True when [path]'s volume is currently reachable. Paths on the system
  /// volume are always online; paths under a mount root are online iff the
  /// root directory exists. Async: the existence probe is a filesystem
  /// call that can hang on an unreachable share.
  Future<bool> isVolumeOnline(String path, {String? platformOverride}) async {
    final root = volumeRootOf(path, platformOverride: platformOverride);
    if (root == null) return true;
    return _directoryExists(root);
  }

  /// An [isVolumeOnline] that memoizes per mount root, for callers
  /// classifying MANY paths in one pass (the Missing count, the wizard's
  /// harvest). Without it a library with hundreds of rows on one
  /// unreachable share pays that share's stat timeout once per row.
  ///
  /// The memo holds the in-flight future, so concurrent probes of the same
  /// root also collapse into one call. Deliberately per-pass rather than
  /// per-[VolumeStatus]: a long-lived cache would keep reporting a volume
  /// offline after the user plugged it back in. Create a fresh probe for
  /// each pass.
  Future<bool> Function(String path) newPassProbe({String? platformOverride}) {
    final byRoot = <String, Future<bool>>{};
    return (path) {
      final root = volumeRootOf(path, platformOverride: platformOverride);
      if (root == null) return Future.value(true);
      return byRoot.putIfAbsent(root, () => _directoryExists(root));
    };
  }

  /// An [isVolumeOnline] for callers with no pass to scope a memo to, where
  /// [newPassProbe] cannot be used and a plain [isVolumeOnline] costs one
  /// stat per call.
  ///
  /// `LocalFileResolver` is the case this exists for (#1182): it is a
  /// singleton resolving one grid tile at a time, and a 140 px grid puts
  /// 30-60 tiles on screen on desktop. Per-call it paid an unreachable
  /// share's stat timeout once per tile, each one parking a `dart:io` pool
  /// thread that drift's SQLite also needs -- which is how a thumbnail
  /// problem became an app-wide freeze.
  ///
  /// [ttl] is measured from when a probe COMPLETES, and an in-flight probe
  /// never expires. Both matter: a mount that hangs for longer than [ttl]
  /// would otherwise expire mid-probe and let the next caller start a second
  /// hang, which is the stall this exists to prevent. A bounded [ttl] is
  /// also what makes a long-lived memo safe at all -- see [newPassProbe],
  /// whose per-pass scoping exists because a cache that never expired would
  /// keep reporting a volume offline after the user plugged it back in. Here
  /// that window is one [ttl], not the life of the process.
  ///
  /// [clock] is injectable so tests can age the memo without waiting.
  Future<bool> Function(String path) newExpiringProbe({
    required Duration ttl,
    DateTime Function()? clock,
    String? platformOverride,
  }) {
    final now = clock ?? DateTime.now;
    final byRoot = <String, _ExpiringProbe>{};
    return (path) {
      final root = volumeRootOf(path, platformOverride: platformOverride);
      if (root == null) return Future.value(true);
      final cached = byRoot[root];
      if (cached != null && !cached.isStale(now(), ttl)) return cached.future;
      final entry = _ExpiringProbe(_directoryExists(root));
      byRoot[root] = entry;
      // Stamped on completion, either way. A probe that THREW is still an
      // answer that cost a filesystem round-trip, and re-running it for
      // every tile is the same stall as never memoizing at all.
      entry.future.then(
        (_) => entry.completedAt = now(),
        onError: (Object _) => entry.completedAt = now(),
      );
      return entry.future;
    };
  }
}

/// One memoized mount-root probe and when it finished.
class _ExpiringProbe {
  _ExpiringProbe(this.future);

  final Future<bool> future;
  DateTime? completedAt;

  bool isStale(DateTime now, Duration ttl) {
    final at = completedAt;
    // Still running: never stale. Expiring an in-flight probe would let the
    // next caller start a second one against the same unreachable mount.
    if (at == null) return false;
    return now.difference(at) >= ttl;
  }
}
