import 'package:submersion/core/providers/provider.dart';

/// Selected media ids in the library. Selection mode is active iff the set
/// is non-empty; every mutation replaces the set (immutability rule).
final mediaSelectionProvider =
    StateNotifierProvider<MediaSelectionNotifier, Set<String>>(
      (ref) => MediaSelectionNotifier(),
    );

class MediaSelectionNotifier extends StateNotifier<Set<String>> {
  MediaSelectionNotifier() : super(const {});

  void toggle(String mediaId) {
    state = state.contains(mediaId)
        ? {...state}.difference({mediaId})
        : {...state, mediaId};
  }

  void clear() {
    state = const {};
  }
}
