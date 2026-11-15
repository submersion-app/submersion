import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/domain/data_health/media_health.dart';

void main() {
  MediaHealthInputs inputs({
    bool storeAttachedHere = true,
    bool storeAnnounced = true,
    bool lightroomConnected = false,
    int mediaSetupItems = 0,
    int lightroomSetupItems = 0,
    bool transfersWaitingWithReason = false,
    bool storeUnreachable = false,
    String? storeLabel,
  }) => MediaHealthInputs(
    storeAttachedHere: storeAttachedHere,
    storeAnnounced: storeAnnounced,
    lightroomConnected: lightroomConnected,
    storeSetupItems: mediaSetupItems,
    lightroomSetupItems: lightroomSetupItems,
    transfersWaitingWithReason: transfersWaitingWithReason,
    storeUnreachable: storeUnreachable,
    storeLabel: storeLabel,
  );

  void expectHealth(FeatureHealth h, HealthLevel level, HealthReason reason) {
    expect(h.feature, DataFeature.media);
    expect((h.level, h.reason), (level, reason));
  }

  test('nothing attached and no Lightroom is notSetUp', () {
    expectHealth(
      evaluateMediaHealth(
        inputs(storeAttachedHere: false, storeAnnounced: false),
      ),
      HealthLevel.notSetUp,
      HealthReason.notSetUp,
    );
  });

  test('dismissed attach is not set up', () {
    expectHealth(
      evaluateMediaHealth(inputs(storeAttachedHere: false, mediaSetupItems: 0)),
      HealthLevel.notSetUp,
      HealthReason.notSetUp,
    );
  });

  test('announced with attach item pending is attention finishSetup', () {
    expectHealth(
      evaluateMediaHealth(inputs(storeAttachedHere: false, mediaSetupItems: 1)),
      HealthLevel.attention,
      HealthReason.mediaFinishSetup,
    );
  });

  test('Lightroom needing sign-in here is attention, not unset', () {
    expectHealth(
      evaluateMediaHealth(
        inputs(
          storeAttachedHere: false,
          storeAnnounced: false,
          lightroomConnected: false,
          mediaSetupItems: 1,
        ),
      ),
      HealthLevel.attention,
      HealthReason.mediaFinishSetup,
    );
  });

  test('attached store, all fine, is healthy', () {
    expectHealth(
      evaluateMediaHealth(inputs()),
      HealthLevel.healthy,
      HealthReason.ok,
    );
  });

  test('Lightroom only, all fine, is healthy', () {
    expectHealth(
      evaluateMediaHealth(
        inputs(
          storeAttachedHere: false,
          storeAnnounced: false,
          lightroomConnected: true,
        ),
      ),
      HealthLevel.healthy,
      HealthReason.ok,
    );
  });

  test('setup items is attention', () {
    expectHealth(
      evaluateMediaHealth(inputs(mediaSetupItems: 2)),
      HealthLevel.attention,
      HealthReason.mediaFinishSetup,
    );
  });

  test('waiting with reason is attention paused', () {
    expectHealth(
      evaluateMediaHealth(inputs(transfersWaitingWithReason: true)),
      HealthLevel.attention,
      HealthReason.mediaTransfersPaused,
    );
  });

  group('findings (#4561)', () {
    test('store and Lightroom setup items each get their own finding', () {
      final h = evaluateMediaHealth(
        inputs(mediaSetupItems: 1, lightroomSetupItems: 1),
      );
      expectHealth(h, HealthLevel.attention, HealthReason.mediaFinishSetup);
      expect(
        [for (final f in h.findings) (f.reason, f.subjectId)],
        [
          (HealthReason.mediaFinishSetup, mediaSetupStore),
          (HealthReason.mediaFinishSetup, mediaSetupLightroom),
        ],
      );
    });

    test('a Lightroom item alone counts as set up and unfinished', () {
      final h = evaluateMediaHealth(
        inputs(
          storeAttachedHere: false,
          storeAnnounced: false,
          lightroomSetupItems: 1,
        ),
      );
      expectHealth(h, HealthLevel.attention, HealthReason.mediaFinishSetup);
      expect(h.findings.single.subjectId, mediaSetupLightroom);
    });

    test('an attached store that cannot be opened needs attention', () {
      final h = evaluateMediaHealth(
        inputs(storeUnreachable: true, storeLabel: 'B2'),
      );
      expectHealth(
        h,
        HealthLevel.attention,
        HealthReason.mediaStoreUnreachable,
      );
      expect(h.name, 'B2');
    });

    test('an unreachable flag without an attached store is ignored', () {
      final h = evaluateMediaHealth(
        inputs(
          storeAttachedHere: false,
          lightroomConnected: true,
          storeUnreachable: true,
        ),
      );
      expectHealth(h, HealthLevel.healthy, HealthReason.ok);
      expect(h.findings, isEmpty);
    });
  });
}
