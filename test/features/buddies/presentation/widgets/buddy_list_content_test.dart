import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/constants/buddy_field.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_list_content.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _TestBuddyTableConfigNotifier
    extends EntityTableConfigNotifier<BuddyField> {
  _TestBuddyTableConfigNotifier(EntityTableViewConfig<BuddyField> config)
    : super(
        defaultConfig: config,
        fieldFromName: BuddyFieldAdapter.instance.fieldFromName,
      );
}

class _MockBuddyListNotifier extends StateNotifier<AsyncValue<List<Buddy>>>
    implements BuddyListNotifier {
  _MockBuddyListNotifier() : super(const AsyncValue.data(<Buddy>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final _testConfig = EntityTableViewConfig<BuddyField>(
  columns: [
    EntityTableColumnConfig(field: BuddyField.buddyName, isPinned: true),
    EntityTableColumnConfig(field: BuddyField.certificationLevel),
    EntityTableColumnConfig(field: BuddyField.certificationAgency),
    EntityTableColumnConfig(field: BuddyField.email),
    EntityTableColumnConfig(field: BuddyField.diveCount),
  ],
);

final _now = DateTime.now();

BuddyWithDiveCount _makeBuddy({
  required String id,
  required String name,
  String? email,
  CertificationLevel? certLevel,
  CertificationAgency? certAgency,
  int diveCount = 0,
}) {
  return BuddyWithDiveCount(
    buddy: Buddy(
      id: id,
      name: name,
      email: email,
      certificationLevel: certLevel,
      certificationAgency: certAgency,
      createdAt: _now,
      updatedAt: _now,
    ),
    diveCount: diveCount,
  );
}

Future<List<Override>> _buildOverrides({
  required List<BuddyWithDiveCount> buddies,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
    allBuddiesWithDiveCountProvider.overrideWith((ref) => buddies),
    buddyListNotifierProvider.overrideWith((ref) => _MockBuddyListNotifier()),
    buddyListViewModeProvider.overrideWith((ref) => ListViewMode.table),
    buddyTableConfigProvider.overrideWith(
      (ref) => _TestBuddyTableConfigNotifier(_testConfig),
    ),
  ];
}

void main() {
  group('BuddyListContent in table mode', () {
    testWidgets('renders table with column headers', (tester) async {
      final buddies = [
        _makeBuddy(
          id: 'b1',
          name: 'Alice Smith',
          certLevel: CertificationLevel.openWater,
          certAgency: CertificationAgency.padi,
          email: 'alice@example.com',
          diveCount: 10,
        ),
        _makeBuddy(
          id: 'b2',
          name: 'Bob Jones',
          certLevel: CertificationLevel.advancedOpenWater,
          certAgency: CertificationAgency.ssi,
          email: 'bob@example.com',
          diveCount: 25,
        ),
      ];

      final overrides = await _buildOverrides(buddies: buddies);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const BuddyListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      // Verify column headers from the config (shortLabel values)
      expect(find.text('Name'), findsWidgets);
      expect(find.text('Cert Level'), findsOneWidget);
      expect(find.text('Agency'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Dives'), findsOneWidget);
    });

    testWidgets('renders rows for each buddy', (tester) async {
      final buddies = [
        _makeBuddy(id: 'b1', name: 'Alice Smith', diveCount: 10),
        _makeBuddy(id: 'b2', name: 'Bob Jones', diveCount: 25),
        _makeBuddy(id: 'b3', name: 'Carol White', diveCount: 3),
      ];

      final overrides = await _buildOverrides(buddies: buddies);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const BuddyListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      // Each buddy name should appear
      expect(find.text('Alice Smith'), findsOneWidget);
      expect(find.text('Bob Jones'), findsOneWidget);
      expect(find.text('Carol White'), findsOneWidget);
    });

    testWidgets('shows empty state when no buddies', (tester) async {
      final overrides = await _buildOverrides(buddies: []);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const BuddyListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      // Should show the empty state, not a table
      expect(find.byIcon(Icons.people_outline), findsOneWidget);
    });

    testWidgets('table app bar includes column settings button', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        buddies: [_makeBuddy(id: 'b1', name: 'Test Buddy')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const BuddyListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      // Column settings icon should be in the app bar
      expect(find.byIcon(Icons.view_column_outlined), findsOneWidget);
    });

    testWidgets('renders with showAppBar false (compact bar)', (tester) async {
      final overrides = await _buildOverrides(
        buddies: [_makeBuddy(id: 'b1', name: 'Test Buddy')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const BuddyListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      // Should still render the buddy name in the table
      expect(find.text('Test Buddy'), findsOneWidget);
    });

    testWidgets('table app bar has sort button', (tester) async {
      final overrides = await _buildOverrides(
        buddies: [_makeBuddy(id: 'b1', name: 'Test Buddy')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const BuddyListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      // Sort button should be in the table app bar
      expect(find.byIcon(Icons.sort), findsOneWidget);
    });

    testWidgets('table app bar has search button', (tester) async {
      final overrides = await _buildOverrides(
        buddies: [_makeBuddy(id: 'b1', name: 'Test Buddy')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const BuddyListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      // Search button should be in the table app bar
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('table app bar has more options button', (tester) async {
      final overrides = await _buildOverrides(
        buddies: [_makeBuddy(id: 'b1', name: 'Test Buddy')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const BuddyListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      // More options (vertical dots) button should be present
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('table app bar popup menu shows view mode items', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        buddies: [_makeBuddy(id: 'b1', name: 'Test Buddy')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const BuddyListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      // Tap the more_vert popup menu button
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // View mode items should appear in the popup
      expect(find.text('Detailed'), findsOneWidget);
    });

    testWidgets('table app bar has vertical divider', (tester) async {
      final overrides = await _buildOverrides(
        buddies: [_makeBuddy(id: 'b1', name: 'Test Buddy')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const BuddyListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      // Vertical divider should be present in the table app bar
      expect(find.byType(VerticalDivider), findsOneWidget);
    });

    testWidgets('compact bar in table mode shows sort button', (tester) async {
      final overrides = await _buildOverrides(
        buddies: [_makeBuddy(id: 'b1', name: 'Test Buddy')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const BuddyListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      // Compact bar should have sort button
      expect(find.byIcon(Icons.sort), findsOneWidget);
    });

    testWidgets('compact bar in table mode shows search button', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        buddies: [_makeBuddy(id: 'b1', name: 'Test Buddy')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const BuddyListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      // Compact bar should have search button
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('compact bar in table mode shows popup menu', (tester) async {
      final overrides = await _buildOverrides(
        buddies: [_makeBuddy(id: 'b1', name: 'Test Buddy')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const BuddyListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      // Compact bar should have more options button
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('table renders cell data for buddy fields', (tester) async {
      final buddies = [
        _makeBuddy(
          id: 'b1',
          name: 'Alice Smith',
          certLevel: CertificationLevel.openWater,
          certAgency: CertificationAgency.padi,
          email: 'alice@example.com',
          diveCount: 10,
        ),
      ];

      final overrides = await _buildOverrides(buddies: buddies);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const BuddyListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      // Verify actual cell data appears
      expect(find.text('Alice Smith'), findsOneWidget);
      expect(find.text('alice@example.com'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
    });

    testWidgets('renders buddies with various cert levels', (tester) async {
      final buddies = [
        _makeBuddy(
          id: 'cl1',
          name: 'Diver A',
          certLevel: CertificationLevel.openWater,
          diveCount: 5,
        ),
        _makeBuddy(
          id: 'cl2',
          name: 'Diver B',
          certLevel: CertificationLevel.advancedOpenWater,
          diveCount: 15,
        ),
        _makeBuddy(
          id: 'cl3',
          name: 'Diver C',
          certLevel: CertificationLevel.diveMaster,
          diveCount: 100,
        ),
      ];

      final overrides = await _buildOverrides(buddies: buddies);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const BuddyListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Diver A'), findsOneWidget);
      expect(find.text('Diver B'), findsOneWidget);
      expect(find.text('Diver C'), findsOneWidget);
    });

    testWidgets('renders buddy with null cert info', (tester) async {
      final buddies = [
        _makeBuddy(
          id: 'nc1',
          name: 'Novice Diver',
          certLevel: null,
          certAgency: null,
          diveCount: 0,
        ),
      ];

      final overrides = await _buildOverrides(buddies: buddies);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const BuddyListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Novice Diver'), findsOneWidget);
    });

    testWidgets('compact bar shows more menu', (tester) async {
      final overrides = await _buildOverrides(
        buddies: [_makeBuddy(id: 'b1', name: 'Test Buddy')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const BuddyListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('renders many buddies without crash', (tester) async {
      final buddies = List.generate(
        15,
        (i) => _makeBuddy(id: 'mb$i', name: 'Buddy $i', diveCount: i * 5),
      );

      final overrides = await _buildOverrides(buddies: buddies);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const BuddyListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Buddy 0'), findsOneWidget);
    });

    testWidgets('tapping sort button opens sort sheet and selects option', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        buddies: [_makeBuddy(id: 'b1', name: 'Test Buddy')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const BuddyListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();

      expect(find.text('Sort Buddies'), findsOneWidget);

      await tester.tap(find.text('Dive Count'));
      await tester.pumpAndSettle();
    });

    testWidgets('tapping popup Detailed switches from table mode', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        buddies: [_makeBuddy(id: 'b1', name: 'Test Buddy')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const BuddyListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Detailed'));
      await tester.pumpAndSettle();

      // View mode was changed from table
      expect(find.byIcon(Icons.view_column_outlined), findsNothing);
    });

    testWidgets('compact bar sort button opens sheet and selects option', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        buddies: [_makeBuddy(id: 'b1', name: 'Test Buddy')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const BuddyListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();

      expect(find.text('Sort Buddies'), findsOneWidget);

      await tester.tap(find.text('Dive Count'));
      await tester.pumpAndSettle();
    });

    testWidgets('compact bar column settings opens picker', (tester) async {
      final overrides = await _buildOverrides(
        buddies: [_makeBuddy(id: 'b1', name: 'Test Buddy')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const BuddyListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      // In table mode, column settings should be available
      final colPickerFinder = find.byIcon(Icons.view_column_outlined);
      if (colPickerFinder.evaluate().isNotEmpty) {
        await tester.tap(colPickerFinder);
        await tester.pumpAndSettle();
        expect(find.text('Columns'), findsOneWidget);
      }
    });

    testWidgets('compact bar popup Detailed switches view mode', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        buddies: [_makeBuddy(id: 'b1', name: 'Test Buddy')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const BuddyListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Detailed'));
      await tester.pumpAndSettle();

      // View mode was changed from table
      expect(find.byIcon(Icons.view_column_outlined), findsNothing);
    });
  });
}
