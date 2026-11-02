import 'package:characters/characters.dart';

import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';

/// The words an annotation's profile marker shows (#4109): the passage,
/// cut at the last word boundary before [maxChars] with an ellipsis.
String annotationMarkerLabel(ProfileEvent annotation, {int maxChars = 24}) =>
    cutAtWord(annotation.description ?? '', maxChars: maxChars);

/// [text] trimmed and, when longer than [maxChars] characters, cut at the
/// last word boundary before it with an ellipsis; a single word longer than
/// the limit is cut hard. Counts user-perceived characters, so an emoji or a
/// combined letter is never split.
String cutAtWord(String text, {required int maxChars}) {
  final chars = text.trim().characters.toList();
  if (chars.length <= maxChars) return chars.join();
  // Back up from the limit until the cut does not split a word; a single
  // word longer than the limit is cut hard.
  var cut = maxChars;
  while (cut > 0 && _isWordChar(chars[cut - 1]) && _isWordChar(chars[cut])) {
    cut--;
  }
  if (cut == 0) cut = maxChars;
  final head = chars.take(cut).join().replaceAll(_trailingJunk, '');
  return '$head\u2026';
}

final _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);
final _trailingJunk = RegExp(r'[\s\p{P}]+$', unicode: true);

bool _isWordChar(String c) => _wordChar.hasMatch(c);
