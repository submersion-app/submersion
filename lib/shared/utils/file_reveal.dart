import 'dart:io';

/// Spawns a process. Injectable so tests never shell out for real.
typedef ProcessRunner =
    Future<void> Function(String executable, List<String> arguments);

/// Whether this platform can reveal a file in a native file manager.
///
/// Mobile has no equivalent: there is no user-visible filesystem to reveal
/// a path in, so callers hide the affordance rather than offering one that
/// does nothing.
bool get canRevealInFileManager =>
    Platform.isMacOS || Platform.isWindows || Platform.isLinux;

/// Reveals [path] in the platform's native file manager.
///
/// Failures are intentionally swallowed: this is a convenience affordance,
/// and the common failure (the file moved since the panel read the row) is
/// already what the caller is looking at. Process.run THROWS rather than
/// returning non-zero when the executable is absent, which is routine on a
/// minimal Linux desktop with no xdg-open, so that is caught too.
///
/// [runProcess] exists so unit tests can assert the command without
/// launching a real file manager, which would make them non-hermetic and
/// can hang a headless CI host.
Future<void> revealInFileManager(
  String path, {
  ProcessRunner? runProcess,
}) async {
  if (!canRevealInFileManager) return;
  final run = runProcess ?? _spawn;
  try {
    if (Platform.isMacOS) {
      await run('open', ['-R', path]);
    } else if (Platform.isWindows) {
      await run('explorer', ['/select,', path]);
    } else if (Platform.isLinux) {
      await run('xdg-open', [File(path).parent.path]);
    }
  } on ProcessException {
    // See the doc above: an absent executable throws rather than failing.
  }
}

// coverage:ignore-start
// The real spawn. Exercised by manual desktop smoke tests; every caller in
// the app goes through revealInFileManager, whose command selection IS unit
// tested via an injected runner.
Future<void> _spawn(String executable, List<String> arguments) async {
  await Process.run(executable, arguments);
}
// coverage:ignore-end
