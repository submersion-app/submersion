import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/section_country_flags_tile.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/country_flag.dart';

import '../../../../helpers/mock_providers.dart';

/// Each section's appearance page has its own Country flags switch (issue
/// #5001), and flipping one leaves the other three alone.
void main() {
  const subtitles = {
    FlagSection.sites: "Show a small flag beside each site's location",
    FlagSection.dives: "Show a small flag beside each dive's site location",
    FlagSection.buddies: "Show a small flag on each buddy's photo",
    FlagSection.trips: "Show the flags of each trip's countries",
  };

  Map<FlagSection, bool> switches(AppSettings s) => {
    FlagSection.sites: s.showCountryFlags,
    FlagSection.dives: s.showDiveCountryFlags,
    FlagSection.buddies: s.showBuddyCountryFlags,
    FlagSection.trips: s.showTripCountryFlags,
  };

  for (final section in FlagSection.values) {
    testWidgets('the ${section.name} tile is on and saves only its own off', (
      tester,
    ) async {
      final notifier = MockSettingsNotifier();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [settingsProvider.overrideWith((ref) => notifier)],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: SectionCountryFlagsTile(section: section)),
          ),
        ),
      );
      final tile = find.byKey(
        ValueKey('section-country-flags-${section.name}'),
      );
      expect(find.text('Country flags'), findsOneWidget);
      expect(find.text(subtitles[section]!), findsOneWidget);
      expect(tester.widget<SwitchListTile>(tile).value, isTrue);

      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(tile).value, isFalse);
      expect(switches(notifier.state), {
        for (final s in FlagSection.values) s: s != section,
      });
    });
  }
}
