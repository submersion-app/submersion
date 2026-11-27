/// Languages that end a sentence with the ideographic full stop and write no
/// space after it.
const _ideographicStopLanguages = {'ja', 'zh'};

/// A sentence that already ends in its own stop in a Latin-style language.
final _latinEnd = RegExp(r'[.!?؟。]$');

/// A sentence that already ends in its own stop in Japanese or Chinese.
final _ideographicEnd = RegExp(r'[。！？.!?]$');

/// [sentences] joined into one message in [languageCode]'s convention, adding
/// a full stop to a sentence that lacks one.
///
/// Latin-style languages get ". " (or just a space after a sentence's own
/// stop). Japanese and Chinese get "。" with no space (or nothing after
/// their own stop): a Latin ". " inside Japanese text reads as a typo (#4833).
/// [languageCode] may carry a region or script suffix (`zh_Hans`).
String joinSentences(List<String> sentences, String languageCode) {
  if (sentences.isEmpty) return '';
  final language = languageCode.split(RegExp('[-_]')).first.toLowerCase();
  final ideographic = _ideographicStopLanguages.contains(language);
  var text = sentences.first.trimRight();
  for (final next in sentences.skip(1)) {
    final String joiner;
    if (ideographic) {
      joiner = _ideographicEnd.hasMatch(text) ? '' : '。';
    } else {
      joiner = _latinEnd.hasMatch(text) ? ' ' : '. ';
    }
    text = '$text$joiner${next.trim()}';
  }
  return text;
}
