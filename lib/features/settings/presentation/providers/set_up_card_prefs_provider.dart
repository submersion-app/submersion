import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/settings/data/set_up_card_prefs.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

typedef SetUpCardState = ({bool hidden, bool photosSkipped});

/// The card's stored state, rebuilt on every write so the card follows a
/// Hide or a Skip at once. The upgrade seed runs at startup, before this is
/// first read.
final setUpCardPrefsNotifierProvider =
    NotifierProvider<SetUpCardPrefsNotifier, SetUpCardState>(
      SetUpCardPrefsNotifier.new,
    );

class SetUpCardPrefsNotifier extends Notifier<SetUpCardState> {
  late SetUpCardPrefs _store;

  @override
  SetUpCardState build() {
    _store = SetUpCardPrefs(ref.watch(sharedPreferencesProvider));
    return (hidden: _store.hidden, photosSkipped: _store.photosSkipped);
  }

  Future<void> setHidden(bool value) async {
    await _store.setHidden(value);
    state = (hidden: value, photosSkipped: state.photosSkipped);
  }

  Future<void> setPhotosSkipped(bool value) async {
    await _store.setPhotosSkipped(value);
    state = (hidden: state.hidden, photosSkipped: value);
  }
}
