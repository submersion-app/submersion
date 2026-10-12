import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/presentation/widgets/focus/focus_sentence.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Every locale's sentence template must keep every control marker exactly
/// once, or the widget drops a control for that language.
void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    test(
      '${locale.languageCode} sentence templates keep every marker',
      () async {
        final l10n = await AppLocalizations.delegate.load(locale);
        final ranked = l10n.insights_focus_sentence_ranked(
          '<count>',
          '<mode>',
          '<metric>',
        );
        final threshold = l10n.insights_focus_sentence_threshold(
          '<metric>',
          '<mode>',
          '<value>',
        );
        for (final m in ['<count>', '<mode>', '<metric>']) {
          expect(m.allMatches(ranked).length, 1, reason: 'ranked $m');
        }
        for (final m in ['<metric>', '<mode>', '<value>']) {
          expect(m.allMatches(threshold).length, 1, reason: 'threshold $m');
        }
        // A slot from the other form would render a control the mode never
        // reads: a threshold box in a ranked sentence, or a count in a
        // threshold one.
        expect(ranked, isNot(contains('<value>')), reason: 'ranked');
        expect(threshold, isNot(contains('<count>')), reason: 'threshold');
        expect(
          splitFocusSentence(ranked).where(focusSentenceMarkers.contains),
          hasLength(3),
        );
      },
    );
  }
}
