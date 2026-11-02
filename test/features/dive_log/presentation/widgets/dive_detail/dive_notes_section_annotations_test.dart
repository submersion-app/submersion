import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/presentation/providers/annotation_focus_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_annotations_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_text_sections.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The Notes card on the dive detail page (#4109): a linked passage shows a
/// pin and its time, jumps to the profile when tapped, and lights up when
/// the profile's popup asked to open it.
void main() {
  final dive = Dive(
    id: 'd1',
    dateTime: DateTime(2026, 5, 3),
    notes: 'I [felt sick](annotation:a1) and later [calm](annotation:gone).',
  );
  final annotation = ProfileEvent.annotation(
    id: 'a1',
    diveId: 'd1',
    timestamp: 1290,
    words: 'felt sick',
    createdAt: DateTime(2026),
  );

  Future<List<String>> pump(WidgetTester tester, {String? highlighted}) async {
    final taps = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diveAnnotationsProvider(
            'd1',
          ).overrideWith((ref) async => [annotation]),
          if (highlighted != null)
            annotationNotesHighlightProvider(
              'd1',
            ).overrideWith((ref) => highlighted),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiveNotesSection(dive: dive, onAnnotationTap: taps.add),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return taps;
  }

  TextSpan? span(WidgetTester tester, String text) {
    for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
      TextSpan? found;
      rich.text.visitChildren((s) {
        if (s is TextSpan && s.text == text) found = s;
        return found == null;
      });
      if (found != null) return found;
    }
    return null;
  }

  testWidgets('shows each annotation with its time and jumps to the profile '
      'on tap', (tester) async {
    final taps = await pump(tester);
    expect(find.byIcon(Icons.push_pin), findsOneWidget);
    expect(span(tester, ' 21:30'), isNotNull);
    // The dangling id stays plain words.
    expect(span(tester, 'calm')?.recognizer, isNull);

    await tester.tapOnText(find.textRange.ofSubstring('felt sick'));
    expect(taps, ['a1']);
  });

  testWidgets('the highlighted passage gets a background', (tester) async {
    await pump(tester, highlighted: 'a1');
    final theme = Theme.of(tester.element(find.byType(DiveNotesSection)));
    expect(
      span(tester, 'felt sick')?.style?.backgroundColor,
      theme.colorScheme.primaryContainer,
    );
  });
}
