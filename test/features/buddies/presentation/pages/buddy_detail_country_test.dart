import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_detail_page.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/country_flag.dart';

import '../../../../helpers/mock_providers.dart';

/// The buddy detail page names the buddy's country, with its flag
/// (issue #4457).
void main() {
  Future<void> pumpDetail(
    WidgetTester tester,
    Buddy buddy, {
    bool flags = true,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 2000);
    addTearDown(tester.view.reset);
    final settings = MockSettingsNotifier();
    await settings.setShowCountryFlags(flags);
    final overrides = await getBaseOverrides(settingsNotifier: settings);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          buddyByIdProvider(buddy.id).overrideWith((ref) async => buddy),
          buddyStatsProvider(
            buddy.id,
          ).overrideWith((ref) async => const BuddyStats(totalDives: 0)),
          diveIdsForBuddyProvider(buddy.id).overrideWith((ref) async => []),
          divesForBuddyProvider(buddy.id).overrideWith((ref) async => []),
          buddyCertificationsProvider(buddy.id).overrideWith((ref) async => []),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BuddyDetailPage(buddyId: buddy.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Buddy buddy({String? country, String? code}) => Buddy(
    id: 'b1',
    name: 'Marco',
    country: country,
    countryCode: code,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  testWidgets('shows the country with its flag', (tester) async {
    await pumpDetail(tester, buddy(country: 'Italy', code: 'IT'));
    expect(find.text('Italy'), findsOneWidget);
    expect(find.byType(CountryFlag), findsOneWidget);
  });

  testWidgets('with flags turned off shows a globe instead', (tester) async {
    await pumpDetail(tester, buddy(country: 'Italy', code: 'IT'), flags: false);
    expect(find.text('Italy'), findsOneWidget);
    expect(find.byType(CountryFlag), findsNothing);
    expect(find.byIcon(Icons.public), findsOneWidget);
  });

  testWidgets('a country no table reads shows a globe', (tester) async {
    await pumpDetail(tester, buddy(country: 'Atlantis'));
    expect(find.text('Atlantis'), findsOneWidget);
    expect(find.byType(CountryFlag), findsNothing);
    expect(find.byIcon(Icons.public), findsOneWidget);
  });

  testWidgets('a buddy without a country shows no country row', (tester) async {
    await pumpDetail(tester, buddy());
    expect(find.byIcon(Icons.public), findsNothing);
  });
}
