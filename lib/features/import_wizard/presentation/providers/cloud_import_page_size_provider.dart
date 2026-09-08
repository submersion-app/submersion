import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/import_wizard/domain/cloud_import_paging.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// How many of the newest remaining dives a cloud import fetches per page.
///
/// Device-local: it only affects this device's fetch-step batch size, so it
/// lives in SharedPreferences rather than the per-diver settings row.
final cloudImportPageSizeProvider =
    StateNotifierProvider<CloudImportPageSizeNotifier, int>((ref) {
      SharedPreferences? prefs;
      try {
        prefs = ref.read(sharedPreferencesProvider);
      } catch (_) {
        // Widget tests that never override SharedPreferences still get the
        // default page size instead of throwing on first fetch. Riverpod
        // wraps the provider's UnimplementedError, so this is a bare catch.
      }
      return CloudImportPageSizeNotifier(prefs: prefs);
    });

class CloudImportPageSizeNotifier extends StateNotifier<int> {
  CloudImportPageSizeNotifier({SharedPreferences? prefs, int? initial})
    : _prefs = prefs,
      super(
        CloudImportPaging.clamp(
          initial ??
              prefs?.getInt(CloudImportPaging.prefsKey) ??
              CloudImportPaging.defaultPageSize,
        ),
      );

  final SharedPreferences? _prefs;

  Future<void> setPageSize(int value) async {
    state = CloudImportPaging.clamp(value);
    await _prefs?.setInt(CloudImportPaging.prefsKey, state);
  }
}
