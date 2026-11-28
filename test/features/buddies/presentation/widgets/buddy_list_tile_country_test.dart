import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/buddies/domain/constants/buddy_field.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_list_tile.dart';
import 'package:submersion/features/buddies/presentation/widgets/compact_buddy_list_tile.dart';
import 'package:submersion/shared/models/entity_card_view_config.dart';
import 'package:submersion/shared/providers/entity_card_config_providers.dart';
import 'package:submersion/shared/widgets/country_flag.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// A standard buddy row draws the buddy's flag as a badge on the avatar
/// (issue #5001); a compact row, with no avatar, draws it beside a Country
/// subtitle (issue #4457).
void main() {
  EntityCardViewConfig<BuddyField> config(
    BuddyField subtitle,
  ) => EntityCardViewConfig<BuddyField>(
    slots: [
      const EntityCardSlotConfig(slotId: 'title', field: BuddyField.buddyName),
      EntityCardSlotConfig(slotId: 'subtitle', field: subtitle),
      const EntityCardSlotConfig(slotId: 'stat1', field: BuddyField.diveCount),
      const EntityCardSlotConfig(slotId: 'stat2', field: BuddyField.lastDive),
    ],
  );

  final entry = BuddyWithDiveCount(
    buddy: Buddy(
      id: 'b1',
      name: 'Marco',
      email: 'marco@example.com',
      country: 'Italy',
      countryCode: 'IT',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    diveCount: 3,
  );

  Future<List<dynamic>> overrides(BuddyField subtitle) async => [
    ...await getBaseOverrides(),
    buddyDetailedCardConfigProvider.overrideWith(
      (ref) => EntityCardConfigNotifier<BuddyField>(
        defaultConfig: config(subtitle),
        fieldFromName: BuddyFieldAdapter.instance.fieldFromName,
      ),
    ),
    buddyCompactCardConfigProvider.overrideWith(
      (ref) => EntityCardConfigNotifier<BuddyField>(
        defaultConfig: config(subtitle),
        fieldFromName: BuddyFieldAdapter.instance.fieldFromName,
      ),
    ),
  ];

  Future<void> pumpStandard(
    WidgetTester tester, {
    BuddyField subtitle = BuddyField.email,
    BuddyWithDiveCount? buddy,
    bool flags = true,
  }) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...await overrides(subtitle),
          showBuddyCountryFlagsProvider.overrideWithValue(flags),
        ],
        locale: const Locale('en'),
        child: BuddyListTile(entry: buddy ?? entry, onTap: () {}),
      ),
    );
    await tester.pumpAndSettle();
  }

  // A standard row shows the buddy's flag as a badge on the avatar, whatever
  // its subtitle shows (issue #5001).
  testWidgets('a row with an email subtitle draws one flag on the avatar', (
    tester,
  ) async {
    await pumpStandard(tester);
    expect(find.byType(CountryFlag), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('buddy-avatar-flag')),
        matching: find.byType(CountryFlag),
      ),
      findsOneWidget,
    );
    final avatar = tester.getRect(find.byType(ProfileAvatar));
    final flag = tester.getRect(find.byType(CountryFlag));
    expect(flag.overlaps(avatar), isTrue);
    expect(flag.center.dx, greaterThan(avatar.center.dx));
    expect(flag.center.dy, greaterThan(avatar.center.dy));
  });

  testWidgets('a row with a Country subtitle still draws exactly one flag', (
    tester,
  ) async {
    await pumpStandard(tester, subtitle: BuddyField.country);
    expect(find.text('Italy'), findsOneWidget);
    expect(find.byType(CountryFlag), findsOneWidget);
    expect(find.byKey(const ValueKey('buddy-avatar-flag')), findsOneWidget);
  });

  testWidgets('a buddy with no country draws no badge', (tester) async {
    await pumpStandard(
      tester,
      buddy: BuddyWithDiveCount(
        buddy: Buddy(
          id: 'b2',
          name: 'Ana',
          email: 'ana@example.com',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        diveCount: 1,
      ),
    );
    expect(find.byType(CountryFlag), findsNothing);
    expect(find.byKey(const ValueKey('buddy-avatar-flag')), findsNothing);
  });

  testWidgets('a stored code with no country text draws no badge', (
    tester,
  ) async {
    await pumpStandard(
      tester,
      buddy: BuddyWithDiveCount(
        buddy: Buddy(
          id: 'b3',
          name: 'Luca',
          email: 'luca@example.com',
          countryCode: 'IT',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        diveCount: 1,
      ),
    );
    // The badge would be the row's only sign of the country, and with no
    // text there is nothing for the label to name.
    expect(find.byType(CountryFlag), findsNothing);
  });

  testWidgets('the badge sits on the trailing corner in a right-to-left row', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...await overrides(BuddyField.email),
          showBuddyCountryFlagsProvider.overrideWithValue(true),
        ],
        locale: const Locale('he'),
        child: BuddyListTile(entry: entry, onTap: () {}),
      ),
    );
    await tester.pumpAndSettle();
    final avatar = tester.getRect(find.byType(ProfileAvatar));
    final flag = tester.getRect(find.byType(CountryFlag));
    expect(flag.center.dx, lessThan(avatar.center.dx));
    expect(flag.center.dy, greaterThan(avatar.center.dy));
  });

  testWidgets('the Buddies switch off hides the badge', (tester) async {
    await pumpStandard(tester, flags: false);
    expect(find.byType(CountryFlag), findsNothing);
  });

  testWidgets("the row's label names the country when the badge draws", (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpStandard(tester);
    expect(find.bySemanticsLabel(RegExp('^Marco, Italy')), findsOneWidget);
    await pumpStandard(tester, flags: false);
    expect(find.bySemanticsLabel(RegExp('Italy')), findsNothing);
    handle.dispose();
  });

  testWidgets("the row's label names the country once with a Country "
      'subtitle', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpStandard(tester, subtitle: BuddyField.country);
    expect(find.byKey(const ValueKey('buddy-avatar-flag')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Italy')), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'Italy[\s\S]*Italy')),
      findsNothing,
      reason: 'the spoken subtitle already names the country',
    );
    handle.dispose();
  });

  testWidgets('a compact row showing the country draws its flag', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: await overrides(BuddyField.country),
        locale: const Locale('en'),
        child: CompactBuddyListTile(entry: entry, onTap: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Italy'), findsOneWidget);
    expect(find.byType(CountryFlag), findsOneWidget);
  });
}
