import 'package:submersion/features/settings/domain/data_health/feature_health.dart';

/// The subject of a finish-setup finding whose item belongs to the media
/// store (attach, reconnect, its account's sign-in), marked on the Photos
/// page's Using row (#4561).
const mediaSetupStore = 'store';

/// The subject of a finish-setup finding whose item is a Lightroom sign-in,
/// marked on the Photos page's Photo sources row (#4561).
const mediaSetupLightroom = 'lightroom';

/// The subject of a finding about a photo subscription (a shared album or
/// photo feed), marked on the Photos page's Network sources row.
const mediaSetupSubscriptions = 'subscriptions';

/// What the photos and media health rules read.
class MediaHealthInputs {
  const MediaHealthInputs({
    required this.storeAttachedHere,
    required this.storeAnnounced,
    required this.lightroomConnected,
    required this.storeSetupItems,
    this.lightroomSetupItems = 0,
    required this.transfersWaitingWithReason,
    this.storeUnreachable = false,
    this.storeLabel,
    this.subscriptionCount = 0,
    this.subscriptionNeedingPassword,
    this.subscriptionFailing,
  });

  /// Active photo subscriptions (shared albums, photo feeds). One is enough
  /// for the feature to count as in use.
  final int subscriptionCount;

  /// The name of an active subscription whose last poll here wanted a
  /// password (none saved, or refused), or null when none did.
  final String? subscriptionNeedingPassword;

  /// The name of an active subscription whose last poll here failed for
  /// another reason, or null when none did.
  final String? subscriptionFailing;

  /// This device is attached to the library's announced media store.
  final bool storeAttachedHere;

  /// The library announces a media store (synced descriptor).
  final bool storeAnnounced;

  /// Lightroom is signed in on this device, not just on the roster.
  final bool lightroomConnected;

  /// Pending setup items for the media store: attach or reconnect, and
  /// sign-ins for the store's account.
  final int storeSetupItems;

  /// Pending sign-ins for an account only Lightroom uses.
  final int lightroomSetupItems;

  /// Every pending media setup item.
  int get mediaSetupItems => storeSetupItems + lightroomSetupItems;

  /// Transfers are deferred with a recorded failure, or the drain holds.
  final bool transfersWaitingWithReason;

  /// The attached store could not be opened with this device's keys. False
  /// while that is still being checked (#4561).
  final bool storeUnreachable;

  /// What the Photos page calls the store's account, for the sentence.
  final String? storeLabel;
}

/// Photos and media health per the spec's media table. Gallery and local
/// file links never make the feature "set up": the app copies nothing for
/// them. A dismissed attach is the diver's choice for this device.
FeatureHealth evaluateMediaHealth(MediaHealthInputs i) {
  FeatureHealth health(
    HealthLevel level,
    HealthReason reason, {
    String? subjectId,
    String? name,
  }) => FeatureHealth(
    feature: DataFeature.media,
    level: level,
    reason: reason,
    subjectId: subjectId,
    name: name,
  );

  // A pending media setup item (store to attach, Lightroom to sign in)
  // means the feature is in use but unfinished here; a dismissed one is the
  // diver's choice for this device and leaves it not set up.
  if (!i.storeAttachedHere &&
      !i.lightroomConnected &&
      i.mediaSetupItems == 0 &&
      i.subscriptionCount == 0) {
    return health(HealthLevel.notSetUp, HealthReason.notSetUp);
  }
  return pickHealth(DataFeature.media, [
    if (i.storeSetupItems > 0)
      health(
        HealthLevel.attention,
        HealthReason.mediaFinishSetup,
        subjectId: mediaSetupStore,
      ),
    if (i.lightroomSetupItems > 0)
      health(
        HealthLevel.attention,
        HealthReason.mediaFinishSetup,
        subjectId: mediaSetupLightroom,
      ),
    if (i.transfersWaitingWithReason)
      health(HealthLevel.attention, HealthReason.mediaTransfersPaused),
    if (i.storeAttachedHere && i.storeUnreachable)
      health(
        HealthLevel.attention,
        HealthReason.mediaStoreUnreachable,
        name: i.storeLabel,
      ),
    if (i.subscriptionNeedingPassword != null)
      health(
        HealthLevel.attention,
        HealthReason.mediaSubscriptionNeedsPassword,
        subjectId: mediaSetupSubscriptions,
        name: i.subscriptionNeedingPassword,
      ),
    if (i.subscriptionFailing != null)
      health(
        HealthLevel.attention,
        HealthReason.mediaSubscriptionFailing,
        subjectId: mediaSetupSubscriptions,
        name: i.subscriptionFailing,
      ),
  ]);
}
