import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/widgets/replace_cloud_library_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Widget host(Widget child, {Locale locale = const Locale('en')}) =>
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: Scaffold(body: child),
      );

  FilledButton confirmButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton));

  testWidgets('Replace stays disabled until the word is typed', (tester) async {
    await tester.pumpWidget(
      host(
        const ReplaceCloudLibraryDialog(localDiveCount: 1247, peerFileCount: 2),
      ),
    );

    expect(confirmButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'replace');
    await tester.pump();
    expect(
      confirmButton(tester).onPressed,
      isNull,
      reason: 'confirmation is case-sensitive',
    );

    await tester.enterText(find.byType(TextField), 'Replace');
    await tester.pump();
    expect(confirmButton(tester).onPressed, isNotNull);
  });

  testWidgets('names the blast radius when the peer count is known', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const ReplaceCloudLibraryDialog(localDiveCount: 1247, peerFileCount: 2),
      ),
    );

    expect(find.textContaining('1247 dives'), findsOneWidget);
    expect(find.textContaining('2 other devices'), findsOneWidget);
  });

  testWidgets('falls back to a count-less line when preflight failed', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const ReplaceCloudLibraryDialog(
          localDiveCount: 1247,
          peerFileCount: null,
        ),
      ),
    );

    expect(find.textContaining('Every other device'), findsOneWidget);
  });

  testWidgets('a solo device is told there is nothing to adopt', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const ReplaceCloudLibraryDialog(localDiveCount: 10, peerFileCount: 0),
      ),
    );

    expect(find.textContaining('No other device'), findsOneWidget);
  });

  testWidgets('the confirm word is the localized one, not English', (
    tester,
  ) async {
    // Regression guard: comparing against a hardcoded English word made the
    // reset dialog impossible to confirm in seven locales.
    await tester.pumpWidget(
      host(
        const ReplaceCloudLibraryDialog(localDiveCount: 1, peerFileCount: 1),
        locale: const Locale('fr'),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Replace');
    await tester.pump();
    expect(confirmButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Remplacer');
    await tester.pump();
    expect(confirmButton(tester).onPressed, isNotNull);
  });
}
