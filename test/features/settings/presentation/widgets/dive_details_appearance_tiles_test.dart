import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/dive_details_appearance_tiles.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Issue #4437: the tissue colour scheme moved from a palette button on the
/// Tissue Loading card into Settings > Appearance > Dives > Dive details.
void main() {
  Future<MockSettingsNotifier> pumpTiles(WidgetTester tester) async {
    final notifier = MockSettingsNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith((ref) => notifier)],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: DiveDetailsAppearanceTiles()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return notifier;
  }

  testWidgets('offers the tissue colour scheme with its current value', (
    tester,
  ) async {
    await pumpTiles(tester);

    expect(find.text('Tissue loading colors'), findsOneWidget);
    expect(find.byType(DropdownButton<TissueColorScheme>), findsOneWidget);
    // AppSettings defaults to the classic (Subsurface) scale.
    expect(
      tester
          .widget<DropdownButton<TissueColorScheme>>(
            find.byType(DropdownButton<TissueColorScheme>),
          )
          .value,
      TissueColorScheme.classic,
    );
    expect(find.text('Classic'), findsOneWidget);
  });

  testWidgets('saves the scheme chosen from the dropdown', (tester) async {
    final notifier = await pumpTiles(tester);

    await tester.tap(find.byType(DropdownButton<TissueColorScheme>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thermal').last);
    await tester.pumpAndSettle();

    expect(notifier.state.tissueColorScheme, TissueColorScheme.thermal);
    expect(find.text('Thermal'), findsOneWidget);
  });
}
