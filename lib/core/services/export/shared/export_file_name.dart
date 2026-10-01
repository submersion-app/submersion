import 'dart:convert';

import 'package:intl/intl.dart';

/// Anything that is not a letter, a combining mark or a digit, in any
/// script. Marks stay so a decomposed accent (macOS spells "é" as "e" plus
/// U+0301) and Indic vowel signs are not cut out of the word.
final _separators = RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true);
final _edgeUnderscores = RegExp(r'^_+|_+$');

/// The most UTF-8 bytes a [fileNameSegment] keeps. File systems cap one
/// name at 255 bytes, and a CJK letter takes 3, so an uncapped long name
/// would fail to save; this leaves room for the prefix, date and extension.
const fileNameSegmentMaxBytes = 100;

/// [name] reduced to a file-name segment every platform accepts: letters
/// and digits of any script ("Curaçao", "台湾"), each run of anything else
/// one underscore, none at either end, at most [fileNameSegmentMaxBytes]
/// bytes. Empty when nothing usable is left.
String fileNameSegment(String name) {
  final reduced = name.replaceAll(_separators, '_');
  final kept = StringBuffer();
  var bytes = 0;
  // By code point, so a character outside the BMP is kept or dropped whole.
  for (final rune in reduced.runes) {
    final char = String.fromCharCode(rune);
    bytes += utf8.encode(char).length;
    if (bytes > fileNameSegmentMaxBytes) break;
    kept.write(char);
  }
  return kept.toString().replaceAll(_edgeUnderscores, '');
}

/// [date] as a file name carries it: ISO whatever the diver reads in the
/// export itself, so a folder of exports sorts chronologically (#964).
String fileNameDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

/// [parts] joined by underscores, with [extension]. Empty parts are left
/// out, so a name that reduced to nothing never leaves `__` behind.
String exportFileName(Iterable<String> parts, String extension) =>
    '${parts.where((p) => p.isNotEmpty).join('_')}.$extension';
