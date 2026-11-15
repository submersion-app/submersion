import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_card.dart';
import 'package:submersion/features/buddies/presentation/widgets/swap/card_summary.dart';
import 'package:submersion/features/buddies/presentation/widgets/swap/your_card_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

const _full = BuddyCard(
  id: 'me',
  name: 'Jordan Blake',
  phone: '+1 555 0199',
  email: 'j@x.com',
  social: '@jordan',
  certs: [BuddyCardCert(agency: 'PADI', name: 'Advanced Open Water Diver')],
  dives: 342,
  since: 2014,
);

Future<AppLocalizations> _l10n() =>
    AppLocalizations.delegate.load(const Locale('en'));

Future<void> _pump(
  WidgetTester tester, {
  required BuddyCard? card,
  VoidCallback? onEdit,
  double width = 430,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ListView(
            children: [YourCardSection(card: card, onEdit: onEdit ?? () {})],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  test('buddyCardChips lists shared values in share-sheet order', () async {
    final chips = buddyCardChips(_full, await _l10n(), (d) => 'D');
    expect(chips, [
      '+1 555 0199',
      'j@x.com',
      'Advanced Open Water Diver',
      '342 dives',
      'Diving since 2014',
      '@jordan',
    ]);
  });

  test(
    'buddyCardChips formats the last dive with the given formatter',
    () async {
      final card = BuddyCard(
        id: 'me',
        name: 'Jo',
        last: DateTime.utc(2026, 11, 2),
      );
      final chips = buddyCardChips(card, await _l10n(), (d) => 'Nov ${d.day}');
      expect(chips, ['Last dive Nov 2']);
    },
  );

  test('buddyCardChips skips what the card does not carry', () async {
    const card = BuddyCard(id: 'me', name: 'Jo');
    expect(buddyCardChips(card, await _l10n(), (d) => 'D'), isEmpty);
  });

  testWidgets('section shows name, Your card, chips and Edit calls back', (
    tester,
  ) async {
    var edits = 0;
    await _pump(tester, card: _full, onEdit: () => edits++);
    expect(find.text('Jordan Blake'), findsOneWidget);
    expect(find.text('Your card'), findsOneWidget);
    expect(find.text('342 dives'), findsOneWidget);
    expect(find.text('JB'), findsOneWidget);
    await tester.tap(find.text('Edit'));
    expect(edits, 1);
  });

  testWidgets('a missing card says it could not be built and offers no Edit', (
    tester,
  ) async {
    await _pump(tester, card: null);
    expect(find.text('Your buddy card could not be built.'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
  });

  testWidgets('a long email ellipsizes at 320 wide', (tester) async {
    await _pump(
      tester,
      width: 320,
      card: const BuddyCard(
        id: 'me',
        name: 'Jordan Blake',
        email:
            'jordan.blake.the.very.long.address.for.diving@example-dive-club.com',
      ),
    );
    expect(tester.takeException(), isNull);
    // Wrap and Chip clip silently, so check the chip stays on screen.
    expect(tester.getRect(find.byType(Chip)).right, lessThanOrEqualTo(320));
  });
}
