/// Anything that is not a letter, a combining mark or a digit, in any
/// script. Marks stay so a decomposed accent (macOS spells "é" as "e" plus
/// U+0301) and Indic vowel signs are not cut out of the word.
final _separators = RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true);
final _edgeUnderscores = RegExp(r'^_+|_+$');

/// [name] reduced to a file-name segment every platform accepts: letters
/// and digits of any script ("Curaçao", "台湾"), each run of anything else
/// one underscore, none at either end. Empty when nothing usable is left.
String fileNameSegment(String name) =>
    name.replaceAll(_separators, '_').replaceAll(_edgeUnderscores, '');

/// [parts] joined by underscores, with [extension]. Empty parts are left
/// out, so a name that reduced to nothing never leaves `__` behind.
String exportFileName(Iterable<String> parts, String extension) =>
    '${parts.where((p) => p.isNotEmpty).join('_')}.$extension';
