import 'package:submersion/core/providers/provider.dart';

/// The buddy card links the app read from or wrote to an NFC tag in the
/// last three seconds (issue #3728).
///
/// When an in-app NFC session ends, Android resumes its own tag dispatch,
/// and a tag still held against the phone arrives again as an incoming
/// link: the card just read would open a second time, and a sticker just
/// written would open the diver's own card. The link dispatcher asks here
/// and drops that one repeat, as passports do with their tags.
class RecentBuddyCardLinks {
  RecentBuddyCardLinks({
    DateTime Function()? clock,
    this.window = const Duration(seconds: 3),
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Duration window;
  final Map<String, DateTime> _handledAt = {};

  /// Records that the app just read or wrote [link].
  void note(String link) {
    final now = _clock();
    _handledAt.removeWhere((_, at) => now.difference(at) >= window);
    _handledAt[link.trim()] = now;
  }

  /// Whether [link] was handled within [window], forgetting it when it
  /// was: Android re-dispatches a held tag once, so only that first repeat
  /// is dropped. A diver who lifts the tag and taps it again means it.
  bool takeJustHandled(String link) {
    final key = link.trim();
    final at = _handledAt[key];
    if (at == null || _clock().difference(at) >= window) return false;
    _handledAt.remove(key);
    return true;
  }
}

final recentBuddyCardLinksProvider = Provider<RecentBuddyCardLinks>(
  (ref) => RecentBuddyCardLinks(),
);
