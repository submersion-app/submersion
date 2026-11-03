import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where the browser keeps the database, in the order drift prefers them.
///
/// Only [opfsShared] and [opfsLocks] put SQLite on the origin private file
/// system; the IndexedDB forms persist but page by page copies, and
/// [inMemory] means nothing survives a reload. The Settings page shows this
/// so a diver whose browser fell back knows what will and will not persist.
enum WebDatabaseStorage {
  opfsShared,
  opfsLocks,
  sharedIndexedDb,
  unsafeIndexedDb,
  inMemory,
  unknown;

  /// The drift storage implementation [name] names, or [unknown].
  static WebDatabaseStorage fromName(String name) => values.firstWhere(
    (value) => value.name == name,
    orElse: () => WebDatabaseStorage.unknown,
  );
}

/// What drift chose when it opened the browser database, and which browser
/// features it found missing on the way to that choice.
@immutable
class WebDatabaseStatus {
  const WebDatabaseStatus({
    required this.storage,
    this.missingFeatures = const {},
  });

  final WebDatabaseStorage storage;

  /// drift's `MissingBrowserFeature` names: `sharedWorkers`,
  /// `fileSystemAccess`, `sharedArrayBuffers` and so on.
  final Set<String> missingFeatures;

  /// Whether the database outlives the page.
  bool get persists => storage != WebDatabaseStorage.inMemory;

  @override
  bool operator ==(Object other) =>
      other is WebDatabaseStatus &&
      other.storage == storage &&
      setEquals(other.missingFeatures, missingFeatures);

  @override
  int get hashCode =>
      Object.hash(storage, Object.hashAllUnordered(missingFeatures));

  @override
  String toString() =>
      'WebDatabaseStatus($storage, missing: ${missingFeatures.join(', ')})';
}

/// The status of the database the page opened, recorded by the web
/// connection and read by [webDatabaseStatusProvider]. Null on a native
/// build and before the browser database is open.
abstract final class WebDatabaseStatusHolder {
  static final ValueNotifier<WebDatabaseStatus?> notifier = ValueNotifier(null);

  static WebDatabaseStatus? get current => notifier.value;

  static void record(WebDatabaseStatus status) => notifier.value = status;

  /// Forgets the recorded status, for tests and for a forgotten device.
  static void clear() => notifier.value = null;
}

/// The browser database status, or null where there is none.
final webDatabaseStatusProvider = Provider<WebDatabaseStatus?>((ref) {
  final notifier = WebDatabaseStatusHolder.notifier;
  void changed() => ref.invalidateSelf();
  notifier.addListener(changed);
  ref.onDispose(() => notifier.removeListener(changed));
  return notifier.value;
});
