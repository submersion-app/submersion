import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_shared_dives_section.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/dive_number_badge_expectations.dart';
import '../../../../helpers/mock_providers.dart';

void main() {
  // #4497: the badge was a fixed 40 point box, so a four digit dive number
  // wrapped onto two lines in the shared dives card.
  testWidgets('dive numbers past 999 stay on one line in their badges', (
    tester,
  ) async {
    final dives = [
      Dive(id: 'a', diveNumber: 1234, dateTime: DateTime(2026, 3, 8, 14)),
      Dive(id: 'b', diveNumber: 999, dateTime: DateTime(2026, 3, 7, 9)),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          diveIdsForBuddyProvider('b1').overrideWith((ref) async => ['a', 'b']),
          divesForBuddyProvider('b1').overrideWith((ref) async => dives),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: BuddySharedDivesSection(buddyId: 'b1'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expectDiveNumberOnOneLineInBadge(tester, '#1234');
    expectDiveNumberOnOneLineInBadge(tester, '#999');
  });
}
