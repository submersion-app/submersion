import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/explore/data/channel_nl_engine.dart';
import 'package:submersion/features/explore/domain/nl_engine.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

final nlEngineProvider = Provider<NlEngine>((ref) => ChannelNlEngine());

/// Synchronous platform gate, separate from the async probe so an entry
/// point is never enabled transiently while the probe loads (the iCloud tile
/// pattern). Uses defaultTargetPlatform so tests can override the platform.
/// The one gate for every entry point, the keyboard shortcut included.
final explorePlatformSupportedProvider = Provider<bool>((ref) {
  return switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.macOS => true,
    _ => false,
  };
});

/// Reads the device's locale at the moment it is called, since the device
/// language can change while the app runs; a provider so tests can set it.
final exploreDeviceLocaleProvider = Provider<Locale Function()>(
  (ref) =>
      () => PlatformDispatcher.instance.locale,
);

/// The language tag of the app's [locale] setting: 'system', the default,
/// resolves to the [device]'s language now.
String exploreLocaleTag(String locale, Locale Function() device) =>
    locale == 'system' ? device().toLanguageTag() : locale;

/// The model's answer for the active app locale.
final exploreAvailabilityProvider = FutureProvider<NlAvailability>((ref) async {
  if (!ref.watch(explorePlatformSupportedProvider)) {
    return NlAvailability.unsupportedPlatform;
  }
  final tag = exploreLocaleTag(
    ref.watch(localeProvider),
    ref.watch(exploreDeviceLocaleProvider),
  );
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
