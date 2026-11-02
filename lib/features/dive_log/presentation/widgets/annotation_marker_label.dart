import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';

/// The words an annotation's profile marker shows (#4109): the passage,
/// cut at the last word boundary before [maxChars] with an ellipsis.
String annotationMarkerLabel(ProfileEvent annotation, {int maxChars = 24}) =>
    cutAtWord(annotation.description ?? '', maxChars: maxChars);

/// [text] trimmed and, when longer than [maxChars], cut at the last word
/// boundary before it with an ellipsis; a single word longer than the limit
/// is cut hard.
String cutAtWord(String text, {required int maxChars}) {
  final words = text.trim();
  if (words.length <= maxChars) return words;
  // Back up from the limit until the cut does not split a word; a single
  // word longer than the limit is cut hard.
  var cut = maxChars;
  while (cut > 0 && _isWordChar(words[cut - 1]) && _isWordChar(words[cut])) {
    cut--;
  }
  if (cut == 0) cut = maxChars;
  final head = words.substring(0, cut).replaceAll(_trailingJunk, '');
  return '$head…';
}

final _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);
final _trailingJunk = RegExp(r'[\s\p{P}]+$', unicode: true);

bool _isWordChar(String c) => _wordChar.hasMatch(c);
