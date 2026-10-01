import 'package:intl/intl.dart';

/// Anything that is not a letter, a combining mark or a digit, in any
/// script. Marks stay so a decomposed accent (macOS spells "é" as "e" plus
/// U+0301) and Indic vowel signs are not cut out of the word.
final _separators = RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true);
final _edgeUnderscores = RegExp(r'^_+|_+$');
final _mark = RegExp(r'^\p{M}$', unicode: true);

/// Names Windows reserves for devices, whatever their case and even with an
/// extension (`AUX.subplan` cannot be saved). Superscript digits count too.
final _windowsReserved = RegExp(
  r'^(CON|PRN|AUX|NUL|COM[0-9¹²³]|LPT[0-9¹²³])$',
  caseSensitive: false,
);

/// The most UTF-8 bytes a [fileNameSegment] keeps. File systems cap one
/// name at 255 bytes, and a CJK letter takes 3, so an uncapped long name
/// would fail to save; this leaves room for the prefix, date and extension.
const fileNameSegmentMaxBytes = 100;

/// [name] reduced to a file-name segment every platform accepts: letters
/// and digits of any script ("Curaçao", "台湾"), each run of anything else
/// one underscore, none at either end, at most [fileNameSegmentMaxBytes]
/// bytes. Empty when nothing usable is left.
String fileNameSegment(String name) {
  final runes = name.replaceAll(_separators, '_').runes.toList();
  var bytes = 0;
  var end = 0;
  // By code point, so a character outside the BMP is kept or dropped whole.
  while (end < runes.length) {
    bytes += _utf8Length(runes[end]);
    if (bytes > fileNameSegmentMaxBytes) break;
    end++;
  }
  // A mark that did not fit takes its letter with it, so the cut never
  // leaves "e" where the name said "é".
  if (end < runes.length && _isMark(runes[end])) {
    while (end > 0 && _isMark(runes[end - 1])) {
      end--;
    }
    if (end > 0) end--;
  }
  return String.fromCharCodes(runes.take(end)).replaceAll(_edgeUnderscores, '');
}

bool _isMark(int rune) => _mark.hasMatch(String.fromCharCode(rune));

int _utf8Length(int rune) => rune < 0x80
    ? 1
    : rune < 0x800
    ? 2
    : rune < 0x10000
    ? 3
    : 4;

/// [date] as a file name carries it: ISO with ASCII digits whatever locale
/// the diver reads the export in, so a folder of exports sorts
/// chronologically (#964). en_US is the one locale intl carries without
/// initializeDateFormatting, so this never throws for want of locale data.
String fileNameDate(DateTime date) =>
    DateFormat('yyyy-MM-dd', 'en_US').format(date);

/// [parts] joined by underscores, with [extension]. Empty parts are left
/// out, so a name that reduced to nothing never leaves `__` behind, and a
/// name Windows reserves for a device gets a trailing underscore.
String exportFileName(Iterable<String> parts, String extension) {
  final stem = parts.where((p) => p.isNotEmpty).join('_');
  final safe = _windowsReserved.hasMatch(stem) ? '${stem}_' : stem;
  return '$safe.$extension';
}
