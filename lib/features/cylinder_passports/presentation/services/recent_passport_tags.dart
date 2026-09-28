import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';

/// The passports the app read or wrote over NFC in the last three seconds.
///
/// When an in-app NFC session ends, Android resumes its own tag dispatch,
/// and a tag still held against the phone arrives again as an incoming link.
/// The link dispatcher asks here and drops that repeat, so the passport the
/// diver is already looking at does not open a second time. The sheets note
/// a tag while the session is still open, before that dispatch resumes.
class RecentPassportTags {
  RecentPassportTags({
    DateTime Function()? clock,
    this.window = const Duration(seconds: 3),
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Duration window;

  /// When each passport id was last handled.
  final Map<String, DateTime> _handledAt = {};

  /// Records that the app just handled [tagText]; text that is no passport
  /// tag is ignored.
  void note(String tagText) {
    final id = _passportIdOf(tagText);
    if (id == null) return;
    final now = _clock();
    _handledAt.removeWhere((_, at) => now.difference(at) >= window);
    _handledAt[id] = now;
  }

  /// Whether [tagText] names a passport handled within [window].
  bool wasJustHandled(String tagText) {
    final id = _passportIdOf(tagText);
    final at = id == null ? null : _handledAt[id];
    return at != null && _clock().difference(at) < window;
  }

  /// [wasJustHandled], and forgets the passport when it was: Android
  /// re-dispatches a held tag once, so only that first repeat is dropped. A
  /// diver who lifts the tag and taps it again means it, and it opens.
  bool takeJustHandled(String tagText) {
    if (!wasJustHandled(tagText)) return false;
    _handledAt.remove(_passportIdOf(tagText));
    return true;
  }

  static String? _passportIdOf(String text) =>
      switch (PassportPayloadCodec.decode(text)) {
        PassportDecoded(:final payload) => payload.passportId.toLowerCase(),
        PassportRejected() => null,
      };
}

final recentPassportTagsProvider = Provider<RecentPassportTags>(
  (ref) => RecentPassportTags(),
);
