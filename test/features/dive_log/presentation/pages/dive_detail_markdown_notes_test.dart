import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_view.dart';

import '../../../../helpers/mock_providers.dart';

/// #3683: the Notes card draws the dive's notes as formatted Markdown.
void main() {
  void ignoreOverflowErrors() {
    final originalOnError = FlutterError.onError;
    addTearDown(() => FlutterError.onError = originalOnError);
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) return;
      originalOnError?.call(details);
    };
  }

  Future<void> pumpWith(WidgetTester tester, Dive dive) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(const AppSettings()),
          ),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          diveProvider(dive.id).overrideWith((ref) async => dive),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiveDetailPage(diveId: dive.id, embedded: true),
        ),
      ),
    );
    ignoreOverflowErrors();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('the Notes card draws Markdown formatted', (tester) async {
    await pumpWith(
      tester,
      createTestDiveWithBottomTime().copyWith(notes: '# Plan\n**Bring torch**'),
    );
    expect(find.byType(MarkdownNotesView), findsOneWidget);
    final text = tester
        .widgetList<RichText>(
          find.descendant(
            of: find.byType(MarkdownNotesView),
            matching: find.byType(RichText),
          ),
        )
        .map((r) => r.text.toPlainText())
        .join('\n');
    expect(text, contains('Plan'));
    expect(text, contains('Bring torch'));
    expect(text, isNot(contains('**')));
  });

  testWidgets('a dive without notes keeps the empty state', (tester) async {
    await pumpWith(tester, createTestDiveWithBottomTime().copyWith(notes: ''));
    expect(find.byType(MarkdownNotesView), findsNothing);
  });
}
