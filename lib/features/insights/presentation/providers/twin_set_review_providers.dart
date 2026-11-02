import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Whether the current diver dismissed the Gas page's twin set re-role note
/// (issue #3374). Per diver, per device, in SharedPreferences: the note is
/// about this screen, not the logbook, so a dismissal is never synced and a
/// peer still gets its own offer.
class TwinSetReviewDismissedNotifier extends StateNotifier<bool> {
  TwinSetReviewDismissedNotifier(this._prefs, String? diverId)
    : _key = keyFor(diverId),
      super(_prefs.getBool(keyFor(diverId)) ?? false);

  final SharedPreferences _prefs;
  final String _key;

  /// The preference key for [diverId]'s dismissal.
  static String keyFor(String? diverId) =>
      'twin_set_review_dismissed.${diverId ?? ''}';

  Future<void> dismiss() async {
    state = true;
    await _prefs.setBool(_key, true);
  }
}

final twinSetReviewDismissedProvider =
    StateNotifierProvider<TwinSetReviewDismissedNotifier, bool>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      final diverId = ref.watch(currentDiverIdProvider);
      return TwinSetReviewDismissedNotifier(prefs, diverId);
    });
