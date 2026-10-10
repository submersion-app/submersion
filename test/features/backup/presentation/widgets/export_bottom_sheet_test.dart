import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/backup/presentation/widgets/export_bottom_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Widget host(Widget sheet) => MaterialApp(
    // Pinned: flutter_test forwards the host machine's locale list, and the
    // English finders below would find nothing on a translated build.
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: sheet),
  );

  testWidgets('Save to File receives the trimmed note', (tester) async {
    String? saved = 'unset';
    await tester.pumpWidget(
      host(ExportBottomSheet(onSaveToFile: (note) => saved = note)),
    );
    await tester.enterText(find.byType(TextField), ' For the shop ');
    await tester.tap(find.text('Save to File'));
    expect(saved, 'For the shop');
  });

  testWidgets('Share receives the note', (tester) async {
    String? shared = 'unset';
    await tester.pumpWidget(
      host(
        ExportBottomSheet(
          onSaveToFile: (_) {},
          onShare: (note) => shared = note,
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Buddy copy');
    await tester.tap(find.text('Share'));
    expect(shared, 'Buddy copy');
  });

  testWidgets('an untouched field gives no note', (tester) async {
    String? saved = 'unset';
    await tester.pumpWidget(
      host(ExportBottomSheet(onSaveToFile: (note) => saved = note)),
    );
    await tester.tap(find.text('Save to File'));
    expect(saved, isNull);
  });

  testWidgets('Share is absent when the platform has no share sheet', (
    tester,
  ) async {
    await tester.pumpWidget(host(ExportBottomSheet(onSaveToFile: (_) {})));
    expect(find.text('Share'), findsNothing);
    expect(find.text('Note (optional)'), findsOneWidget);
  });
}
