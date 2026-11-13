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

Future<void> _pumpSection(WidgetTester tester, List<Dive> dives) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        diveIdsForBuddyProvider(
          'b1',
        ).overrideWith((ref) async => [for (final d in dives) d.id]),
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
}

void main() {
  testWidgets('rows show the measured runtime, as the trip Dives tab does', (
    tester,
  ) async {
    await _pumpSection(tester, [
      Dive(
        id: 'a',
        diveNumber: 3,
        dateTime: DateTime(2026, 3, 8, 9),
        runtime: const Duration(minutes: 52),
        bottomTime: const Duration(minutes: 47),
      ),
    ]);

    expect(find.text('52 min'), findsOneWidget);
    expect(find.textContaining('47'), findsNothing);
  });

  testWidgets('a dive without a site reads as an unknown site', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpSection(tester, [
      Dive(id: 'a', diveNumber: 3, dateTime: DateTime(2026, 3, 8, 9)),
    ]);

    expect(find.text('Unknown Site'), findsOneWidget);
    // The row's own label is one line of the merged node it joins.
    expect(
      find.bySemanticsLabel(RegExp(r'(^|\n)Dive 3 at Unknown Site(\n|$)')),
      findsOneWidget,
    );
    handle.dispose();
  });

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
