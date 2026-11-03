import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/explore/presentation/providers/explore_gate_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The language code of the app's locale, with `system` read from the device,
/// for the filler words and month names of a sentence typed in plain words
/// (#3457).
final queryLanguageProvider = Provider<String>((ref) {
  final tag = exploreLocaleTag(
    ref.watch(localeProvider),
    ref.watch(exploreDeviceLocaleProvider),
  );
  return tag.split(RegExp('[-_]')).first;
});
