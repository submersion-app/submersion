import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/app.dart' show resolveAppLocale;
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/features/transfer/presentation/widgets/pdf_export_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// #2252: the PDF export sheet lets the diver pick the language the logbook
/// prints in, starting from the language the app is shown in.
Future<ValueGetter<Object?>> _open(WidgetTester tester, Locale locale) async {
  // The sheet stacks four templates, page size, language and two switches.
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  Object? result = #pending;
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: locale,
        // The app's own resolution, so an unsupported system language lands
        // where it does for a diver rather than on MaterialApp's default.
        localeListResolutionCallback: resolveAppLocale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await PdfExportDialog.show(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return () => result;
}

Finder get _languageField => find.byKey(PdfExportDialog.languageFieldKey);

Future<void> _export(WidgetTester tester, Locale locale) async {
  final l10n = lookupAppLocalizations(locale);
  await tester.tap(find.text(l10n.transfer_pdfExport_exportButton));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('defaults to the app language', (tester) async {
    const french = Locale('fr');
    final result = await _open(tester, french);

    expect(
      find.descendant(of: _languageField, matching: find.text('Français')),
      findsOneWidget,
    );

    await _export(tester, french);
    expect((result() as PdfExportOptions).languageCode, 'fr');
  });

  testWidgets('returns the language the diver picks', (tester) async {
    const french = Locale('fr');
    final result = await _open(tester, french);

    await tester.tap(_languageField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    await _export(tester, french);
    expect((result() as PdfExportOptions).languageCode, 'en');
  });

  testWidgets('offers every language the app ships', (tester) async {
    await _open(tester, const Locale('en'));

    await tester.tap(_languageField);
    await tester.pumpAndSettle();

    for (final name in ['Deutsch', 'Español', '简体中文', 'Magyar']) {
      expect(find.text(name), findsWidgets, reason: name);
    }
  });

  test('offers exactly the languages the app ships', () {
    expect(
      PdfExportDialog.languageOptions.map((option) => option.code).toSet(),
      AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet(),
    );
  });

  testWidgets('an unsupported system language starts on English', (
    tester,
  ) async {
    const japanese = Locale('ja');
    final result = await _open(tester, japanese);

    expect(
      find.descendant(of: _languageField, matching: find.text('English')),
      findsOneWidget,
    );

    await _export(tester, const Locale('en'));
    expect((result() as PdfExportOptions).languageCode, 'en');
  });
}
