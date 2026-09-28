import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';

/// The passport the app last read or wrote over NFC, for a few seconds.
///
/// When an in-app NFC session ends, Android resumes its own tag dispatch,
/// and a tag still held against the phone arrives again as an incoming link.
/// The link dispatcher asks here and drops that repeat, so the passport the
/// diver is already looking at does not open a second time.
class RecentPassportTags {
  RecentPassportTags({
    DateTime Function()? clock,
    this.window = const Duration(seconds: 5),
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Duration window;
  String? _passportId;
  DateTime? _at;

  /// Records that the app just handled [tagText]; text that is no passport
  /// tag is ignored.
  void note(String tagText) {
    final id = _passportIdOf(tagText);
    if (id == null) return;
    _passportId = id;
    _at = _clock();
  }

  /// Whether [tagText] names the passport handled within [window].
  bool wasJustHandled(String tagText) {
    final at = _at;
    if (at == null || _clock().difference(at) >= window) return false;
    final id = _passportIdOf(tagText);
    return id != null && id == _passportId;
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
