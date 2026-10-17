import 'package:submersion/features/settings/domain/data_health/feature_health.dart';

/// What the photos and media health rules read.
class MediaHealthInputs {
  const MediaHealthInputs({
    required this.storeAttachedHere,
    required this.storeAnnounced,
    required this.attachItemPending,
    required this.lightroomConnected,
    required this.mediaSetupItems,
    required this.transfersWaitingWithReason,
  });

  /// This device is attached to the library's announced media store.
  final bool storeAttachedHere;

  /// The library announces a media store (synced descriptor).
  final bool storeAnnounced;

  /// The "attach on this device" setup item is showing (not dismissed).
  final bool attachItemPending;

  final bool lightroomConnected;

  /// Pending setup items that belong to media: store attach or reconnect,
  /// and sign-ins for the store's account or Lightroom.
  final int mediaSetupItems;

  /// Transfers are deferred with a recorded failure, or the drain holds.
  final bool transfersWaitingWithReason;
}

/// Photos and media health per the spec's media table. Gallery and local
/// file links never make the feature "set up": the app copies nothing for
/// them. A dismissed attach is the diver's choice for this device.
FeatureHealth evaluateMediaHealth(MediaHealthInputs i) {
  FeatureHealth health(HealthLevel level, HealthReason reason) =>
      FeatureHealth(feature: DataFeature.media, level: level, reason: reason);

  if (!i.storeAttachedHere && !i.lightroomConnected && !i.attachItemPending) {
    return health(HealthLevel.notSetUp, HealthReason.notSetUp);
  }
  return pickHealth(DataFeature.media, [
    if (i.mediaSetupItems > 0)
      health(HealthLevel.attention, HealthReason.mediaFinishSetup),
    if (i.transfersWaitingWithReason)
      health(HealthLevel.attention, HealthReason.mediaTransfersPaused),
  ]);
}
