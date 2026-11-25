import 'dart:async';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';

/// Polls manifest subscriptions (photo feeds, shared albums) on their own:
/// once 30 seconds after launch, then at a cadence derived from their
/// intervals, each one only when it is due. Without this a subscription is
/// only ever polled by Poll now. Called once by the app root.
///
/// Listened to, not read once: when the provider is rebuilt (its
/// dependencies changed), the old scheduler is disposed and the new one is
/// started here. The provider cancels the timers when the scope goes.
void startSubscriptionPolling(WidgetRef ref) {
  ref.listenManual(
    subscriptionPollerSchedulerProvider,
    (_, scheduler) => unawaited(scheduler.startAfterWarmup()),
    fireImmediately: true,
  );
}
