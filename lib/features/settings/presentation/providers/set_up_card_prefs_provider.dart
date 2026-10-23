import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/settings/data/set_up_card_prefs.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

typedef SetUpCardState = ({bool hidden, bool photosSkipped});

/// The card's stored state, rebuilt on every write so the card follows a
/// Hide or a Skip at once.
final setUpCardPrefsProvider =
    NotifierProvider<SetUpCardPrefsNotifier, SetUpCardState>(
      SetUpCardPrefsNotifier.new,
    );

class SetUpCardPrefsNotifier extends Notifier<SetUpCardState> {
  SetUpCardPrefs get _store =>
      SetUpCardPrefs(ref.read(sharedPreferencesProvider));

  @override
  SetUpCardState build() {
    final store = SetUpCardPrefs(ref.watch(sharedPreferencesProvider));
    return (hidden: store.hidden, photosSkipped: store.photosSkipped);
  }

  Future<void> setHidden(bool value) async {
    await _store.setHidden(value);
    state = (hidden: value, photosSkipped: state.photosSkipped);
  }

  Future<void> setPhotosSkipped(bool value) async {
    await _store.setPhotosSkipped(value);
    state = (hidden: state.hidden, photosSkipped: value);
  }

  Future<void> seedOnce({required int diverCount}) async {
    final store = _store;
    await store.seedOnce(diverCount: diverCount);
    state = (hidden: store.hidden, photosSkipped: store.photosSkipped);
  }
}
