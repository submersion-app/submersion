import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/pages/appearance_page.dart';
import 'package:submersion/features/settings/presentation/pages/section_appearance_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/mock_providers.dart';
import '../../../support/fake_app_settings_repository.dart';

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final base = await getBaseOverrides();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        appSettingsRepositoryProvider.overrideWithValue(
          FakeAppSettingsRepository(),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The arrange sheet is reachable from Settings > Appearance > Dives, beside
/// the other dive detail settings, and no longer from the general Appearance
/// list, where it read as a design choice (#3750).
void main() {
  testWidgets('the Dives appearance page opens the arrange sheet', (
    tester,
  ) async {
    await _pump(tester, const SectionAppearancePage(sectionKey: 'dives'));

    final entry = find.text('Gear arrangement');
    expect(entry, findsOneWidget);
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.text('Order types by'), findsOneWidget);
  });

  // The tablet and desktop settings pane embeds the same page without its
  // Scaffold; the sheet has to open from there too.
  testWidgets('the embedded Dives page opens the arrange sheet', (
    tester,
  ) async {
    await _pump(
      tester,
      const Scaffold(
        body: SectionAppearancePage(sectionKey: 'dives', embedded: true),
      ),
    );

    final entry = find.text('Gear arrangement');
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.text('Order types by'), findsOneWidget);
  });

  testWidgets('the entry sits in the Dive Details group', (tester) async {
    await _pump(tester, const SectionAppearancePage(sectionKey: 'dives'));

    final header = tester.getTopLeft(find.text('Dive Details')).dy;
    final entry = tester.getTopLeft(find.text('Gear arrangement')).dy;
    expect(entry, greaterThan(header));
  });

  testWidgets('other sections do not show the entry', (tester) async {
    await _pump(tester, const SectionAppearancePage(sectionKey: 'sites'));

    expect(find.text('Gear arrangement'), findsNothing);
  });

  testWidgets('the general Appearance page no longer shows the entry', (
    tester,
  ) async {
    await _pump(tester, const AppearancePage());

    expect(find.text('Colored navigation icons'), findsOneWidget);
    expect(find.text('Gear arrangement'), findsNothing);
  });
}
