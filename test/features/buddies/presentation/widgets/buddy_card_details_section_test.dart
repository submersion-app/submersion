import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_card_details_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  Future<UnitFormatter> pump(WidgetTester tester, Buddy buddy) async {
    final settings = MockSettingsNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith((ref) => settings)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: BuddyCardDetailsSection(buddy: buddy)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return UnitFormatter(settings.state);
  }

  testWidgets('shows dives, diving since, last dive and the received date '
      "in the diver's date format", (tester) async {
    final buddy = Buddy(
      id: 'b1',
      name: 'Sam Rivera',
      cardDiveCount: 118,
      cardDivingSince: DateTime(2016),
      cardLastDive: DateTime(2026, 10, 3),
      cardReceivedAt: DateTime(2026, 10, 28, 14),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final units = await pump(tester, buddy);
    expect(find.text("From Sam Rivera's card"), findsOneWidget);
    expect(find.text('118 dives'), findsOneWidget);
    expect(find.text('Diving since 2016'), findsOneWidget);
    expect(
      find.text('Last dive ${units.formatDate(DateTime(2026, 10, 3))}'),
      findsOneWidget,
    );
    expect(
      find.text('Received ${units.formatDate(DateTime(2026, 10, 28))}'),
      findsOneWidget,
    );
  });

  testWidgets('hidden when the buddy has no card details', (tester) async {
    await pump(
      tester,
      Buddy(
        id: 'b1',
        name: 'Sam Rivera',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    expect(find.textContaining('card'), findsNothing);
  });

  testWidgets('only the figures the card carried are listed', (tester) async {
    await pump(
      tester,
      Buddy(
        id: 'b1',
        name: 'Sam',
        cardDiveCount: 1,
        cardReceivedAt: DateTime(2026, 10, 28),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    expect(find.text('1 dive'), findsOneWidget);
    expect(find.textContaining('Diving since'), findsNothing);
    expect(find.textContaining('Last dive'), findsNothing);
  });
}
