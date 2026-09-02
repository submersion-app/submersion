import 'dart:ui';

import 'package:http/http.dart' as http;
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/marine_life/data/services/inaturalist_species_lookup_service.dart';
import 'package:submersion/features/marine_life/data/services/species_lookup_service.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The language code sent as iNaturalist's `locale` parameter, from the
/// persisted locale setting. Mirrors `l10nForLocaleTag`: `system` follows
/// the platform, and a region or script suffix is dropped.
String lookupLocaleCode(
  String localeTag, {
  String Function()? systemLanguageCode,
}) {
  final tag = localeTag == 'system'
      ? (systemLanguageCode ?? _platformLanguageCode)()
      : localeTag;
  return tag.split(RegExp('[-_]')).first.toLowerCase();
}

String _platformLanguageCode() =>
    PlatformDispatcher.instance.locale.languageCode;

/// Shared client for species lookups. Overridden in tests with a MockClient.
final speciesLookupHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final speciesLookupServiceProvider = Provider<SpeciesLookupService>((ref) {
  return INaturalistSpeciesLookupService(
    client: ref.watch(speciesLookupHttpClientProvider),
  );
});

final speciesLookupLocaleProvider = Provider<String>((ref) {
  return lookupLocaleCode(ref.watch(localeProvider));
});
