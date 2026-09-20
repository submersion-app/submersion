import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/explore/data/channel_nl_engine.dart';
import 'package:submersion/features/explore/domain/nl_engine.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

final nlEngineProvider = Provider<NlEngine>((ref) => ChannelNlEngine());

/// Synchronous platform gate, separate from the async probe so an entry
/// point is never enabled transiently while the probe loads (the iCloud tile
/// pattern). Uses defaultTargetPlatform so tests can override the platform.
final explorePlatformSupportedProvider = Provider<bool>((ref) {
  return switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.macOS => true,
    _ => false,
  };
});

/// The model's answer for the active app locale. 'system' resolves to the
/// device locale tag.
final exploreAvailabilityProvider = FutureProvider<NlAvailability>((ref) async {
  if (!ref.watch(explorePlatformSupportedProvider)) {
    return NlAvailability.unsupportedPlatform;
  }
  final locale = ref.watch(localeProvider);
  final tag = locale == 'system'
      ? PlatformDispatcher.instance.locale.toLanguageTag()
      : locale;
  return ref.watch(nlEngineProvider).availability(tag);
});

final exploreEnabledProvider = Provider<bool>((ref) {
  if (!ref.watch(explorePlatformSupportedProvider)) return false;
  final availability = ref.watch(exploreAvailabilityProvider);
  // Closed while a probe is in flight. A locale change reloads this provider,
  // and AsyncValue retains the PREVIOUS answer during the reload, so reading
  // `.value` alone would keep the entry point open on an English "available"
  // while the new locale's probe is still running.
  if (availability.isLoading) return false;
  return availability.value == NlAvailability.available;
});
