import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/domain/data_health/media_health.dart';

void main() {
  MediaHealthInputs inputs({
    bool storeAttachedHere = true,
    bool storeAnnounced = true,
    bool lightroomConnected = false,
    int mediaSetupItems = 0,
    bool transfersWaitingWithReason = false,
  }) => MediaHealthInputs(
    storeAttachedHere: storeAttachedHere,
    storeAnnounced: storeAnnounced,
    lightroomConnected: lightroomConnected,
    mediaSetupItems: mediaSetupItems,
    transfersWaitingWithReason: transfersWaitingWithReason,
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
}
