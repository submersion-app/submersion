import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/dive_types/presentation/widgets/dive_type_favourite_button.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The star that makes a dive type a favourite (issue #4413).
void main() {
  Widget harness(MockSettingsNotifier settings) => ProviderScope(
    overrides: [settingsProvider.overrideWith((ref) => settings)],
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: DiveTypeFavouriteButton(
          diveTypeId: 'wreck',
          diveTypeName: 'Wreck',
        ),
      ),
    ),
  );

  testWidgets('an unstarred type offers to add it', (tester) async {
    await tester.pumpWidget(harness(MockSettingsNotifier()));
    expect(find.byIcon(Icons.star_border), findsOneWidget);
    expect(find.byTooltip('Add Wreck to favorites'), findsOneWidget);
    expect(find.byKey(diveTypeFavouriteButtonKey('wreck')), findsOneWidget);
  });

  testWidgets('tapping stars the type, tapping again unstars it', (
    tester,
  ) async {
    final settings = MockSettingsNotifier();
    await tester.pumpWidget(harness(settings));

    await tester.tap(find.byKey(diveTypeFavouriteButtonKey('wreck')));
    await tester.pump();
    expect(settings.state.favouriteDiveTypeIds, {'wreck'});
    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.byTooltip('Remove Wreck from favorites'), findsOneWidget);

    await tester.tap(find.byKey(diveTypeFavouriteButtonKey('wreck')));
    await tester.pump();
    expect(settings.state.favouriteDiveTypeIds, isEmpty);
    expect(find.byIcon(Icons.star_border), findsOneWidget);
  });

  test('a blank id, as a non-Latin custom name slugs to, stays starred', () {
    final c = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => MockSettingsNotifier(
            const AppSettings(favouriteDiveTypeIds: {''}),
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    expect(c.read(favouriteDiveTypeIdsProvider), {''});
  });

  test('the provider rebuilds only when the favourites change', () async {
    final settings = MockSettingsNotifier(
      const AppSettings(favouriteDiveTypeIds: {'cave'}),
    );
    final c = ProviderContainer(
      overrides: [settingsProvider.overrideWith((ref) => settings)],
    );
    addTearDown(c.dispose);
    var notified = 0;
    c.listen(favouriteDiveTypeIdsProvider, (_, _) => notified++);
    expect(c.read(favouriteDiveTypeIdsProvider), {'cave'});

    await settings.setDefaultShowBuoyancy(true);
    expect(c.read(favouriteDiveTypeIdsProvider), {'cave'});
    expect(notified, 0);

    // A settings load decodes a fresh Set holding the same ids: equal, not
    // identical, so selecting the Set itself would rebuild every picker.
    settings.state = settings.state.copyWith(favouriteDiveTypeIds: {'cave'});
    expect(c.read(favouriteDiveTypeIdsProvider), {'cave'});
    expect(notified, 0);

    await settings.setDiveTypeFavourite('wreck', true);
    expect(c.read(favouriteDiveTypeIdsProvider), {'cave', 'wreck'});
    expect(notified, 1);
  });
}
