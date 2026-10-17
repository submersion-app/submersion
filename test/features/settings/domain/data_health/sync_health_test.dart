import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/domain/data_health/sync_health.dart';

void main() {
  final now = DateTime(2026, 10, 17, 12);
  const providerId = 'icloud';

  SyncFailureRecord failure({
    String provider = providerId,
    Duration ago = const Duration(hours: 1),
    SyncFailureKind kind = SyncFailureKind.other,
  }) => SyncFailureRecord(
    providerId: provider,
    at: now.subtract(ago),
    kind: kind,
    message: 'boom',
  );

  SyncHealthInputs inputs({
    bool customFolder = false,
    bool providerSelected = true,
    bool needsPassphrase = false,
    bool awaitingAdoption = false,
    bool authenticated = true,
    SyncFailureRecord? lastFailure,
    Duration? syncedAgo = const Duration(minutes: 12),
    int conflicts = 0,
    bool peersHeld = false,
    bool autoSyncEnabled = true,
  }) => SyncHealthInputs(
    customFolder: customFolder,
    providerSelected: providerSelected,
    providerId: providerSelected ? providerId : null,
    needsPassphrase: needsPassphrase,
    awaitingAdoption: awaitingAdoption,
    authenticated: authenticated,
    lastFailure: lastFailure,
    lastSyncAt: syncedAgo == null ? null : now.subtract(syncedAgo),
    conflicts: conflicts,
    peersHeld: peersHeld,
    autoSyncEnabled: autoSyncEnabled,
  );

  FeatureHealth eval(SyncHealthInputs i) => evaluateSyncHealth(i, now);

  void expectHealth(FeatureHealth h, HealthLevel level, HealthReason reason) {
    expect(h.feature, DataFeature.sync);
    expect((h.level, h.reason), (level, reason));
  }

  test('healthy when everything is fine', () {
    final h = eval(inputs());
    expectHealth(h, HealthLevel.healthy, HealthReason.ok);
    expect(h.when, now.subtract(const Duration(minutes: 12)));
  });

  test('custom folder is notSetUp even with no provider', () {
    expectHealth(
      eval(inputs(customFolder: true, providerSelected: false)),
      HealthLevel.notSetUp,
      HealthReason.syncCustomFolder,
    );
  });

  test('no provider is attention syncOff even after a failure', () {
    expectHealth(
      eval(inputs(providerSelected: false, lastFailure: failure())),
      HealthLevel.attention,
      HealthReason.syncOff,
    );
  });

  test('needs passphrase is failing', () {
    expectHealth(
      eval(inputs(needsPassphrase: true)),
      HealthLevel.failing,
      HealthReason.syncNeedsPassphrase,
    );
  });

  test('awaiting adoption is failing', () {
    expectHealth(
      eval(inputs(awaitingAdoption: true)),
      HealthLevel.failing,
      HealthReason.syncAwaitingAdoption,
    );
  });

  test('signed out is failing', () {
    expectHealth(
      eval(inputs(authenticated: false)),
      HealthLevel.failing,
      HealthReason.syncSignedOut,
    );
  });

  test('other failure newer than last sync is failing with when', () {
    final f = failure(ago: const Duration(minutes: 5));
    final h = eval(inputs(lastFailure: f));
    expectHealth(h, HealthLevel.failing, HealthReason.syncFailed);
    expect(h.when, f.at);
  });

  test('other failure older than last sync is ignored', () {
    expectHealth(
      eval(inputs(lastFailure: failure(ago: const Duration(hours: 2)))),
      HealthLevel.healthy,
      HealthReason.ok,
    );
  });

  test('failure for another provider is ignored', () {
    expectHealth(
      eval(
        inputs(
          lastFailure: failure(
            provider: 'dropbox',
            ago: const Duration(minutes: 1),
          ),
        ),
      ),
      HealthLevel.healthy,
      HealthReason.ok,
    );
  });

  test('network failure with sync 2 days ago is healthy', () {
    expectHealth(
      eval(
        inputs(
          syncedAgo: const Duration(days: 2),
          lastFailure: failure(kind: SyncFailureKind.network),
        ),
      ),
      HealthLevel.healthy,
      HealthReason.ok,
    );
  });

  test('network failure with sync 8 days ago is attention offline', () {
    final h = eval(
      inputs(
        syncedAgo: const Duration(days: 8),
        lastFailure: failure(kind: SyncFailureKind.network),
      ),
    );
    expectHealth(h, HealthLevel.attention, HealthReason.syncOffline);
    expect(h.when, now.subtract(const Duration(days: 8)));
  });

  test('network failure and never synced is attention neverSynced', () {
    expectHealth(
      eval(
        inputs(
          syncedAgo: null,
          lastFailure: failure(kind: SyncFailureKind.network),
        ),
      ),
      HealthLevel.attention,
      HealthReason.syncNeverSynced,
    );
  });

  test('conflicts give count', () {
    final h = eval(inputs(conflicts: 3));
    expectHealth(h, HealthLevel.attention, HealthReason.syncConflicts);
    expect(h.count, 3);
  });

  test('peers held is attention', () {
    expectHealth(
      eval(inputs(peersHeld: true)),
      HealthLevel.attention,
      HealthReason.syncPeersHeld,
    );
  });

  test('auto sync off is attention autoOff', () {
    expectHealth(
      eval(inputs(autoSyncEnabled: false)),
      HealthLevel.attention,
      HealthReason.syncAutoOff,
    );
  });

  test('never synced is attention', () {
    expectHealth(
      eval(inputs(syncedAgo: null)),
      HealthLevel.attention,
      HealthReason.syncNeverSynced,
    );
  });

  test('failing outranks conflicts', () {
    expectHealth(
      eval(inputs(conflicts: 2, authenticated: false)),
      HealthLevel.failing,
      HealthReason.syncSignedOut,
    );
  });
}
