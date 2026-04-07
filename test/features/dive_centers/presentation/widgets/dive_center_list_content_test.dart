import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/domain/constants/dive_center_field.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_list_content.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _TestDCTableConfigNotifier
    extends EntityTableConfigNotifier<DiveCenterField> {
  _TestDCTableConfigNotifier(EntityTableViewConfig<DiveCenterField> config)
    : super(
        defaultConfig: config,
        fieldFromName: DiveCenterFieldAdapter.instance.fieldFromName,
      );
}

class _MockDCListNotifier extends StateNotifier<AsyncValue<List<DiveCenter>>>
    implements DiveCenterListNotifier {
  _MockDCListNotifier(List<DiveCenter> centers)
    : super(AsyncValue.data(centers));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final _testConfig = EntityTableViewConfig<DiveCenterField>(
  columns: [
    EntityTableColumnConfig(field: DiveCenterField.centerName, isPinned: true),
    EntityTableColumnConfig(field: DiveCenterField.city),
    EntityTableColumnConfig(field: DiveCenterField.country),
    EntityTableColumnConfig(field: DiveCenterField.phone),
    EntityTableColumnConfig(field: DiveCenterField.diveCount),
    EntityTableColumnConfig(field: DiveCenterField.rating),
  ],
);

final _now = DateTime.now();

DiveCenter _makeCenter({
  required String id,
  required String name,
  String? city,
  String? country,
  String? phone,
  double? rating,
}) {
  return DiveCenter(
    id: id,
    name: name,
    city: city,
    country: country,
    phone: phone,
    rating: rating,
    createdAt: _now,
    updatedAt: _now,
  );
}

Future<List<Override>> _buildOverrides({
  required List<DiveCenter> centers,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
    diveCenterListNotifierProvider.overrideWith(
      (ref) => _MockDCListNotifier(centers),
    ),
    diveCenterListViewModeProvider.overrideWith((ref) => ListViewMode.table),
    diveCenterTableConfigProvider.overrideWith(
      (ref) => _TestDCTableConfigNotifier(_testConfig),
    ),
    // Override dive count provider so it returns 0 for any center
    diveCenterDiveCountProvider.overrideWith((ref, centerId) => 0),
  ];
}

void main() {
  group('DiveCenterListContent in table mode', () {
    testWidgets('renders table with column headers', (tester) async {
      final centers = [
        _makeCenter(
          id: 'dc1',
          name: 'Blue Water Dive',
          city: 'Cairns',
          country: 'Australia',
          rating: 4.5,
        ),
        _makeCenter(
          id: 'dc2',
          name: 'Red Sea Divers',
          city: 'Sharm El Sheikh',
          country: 'Egypt',
          rating: 4.8,
        ),
      ];

      final overrides = await _buildOverrides(centers: centers);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveCenterListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      // Verify column headers from shortLabel values
      expect(find.text('Name'), findsWidgets);
      expect(find.text('City'), findsOneWidget);
      expect(find.text('Country'), findsOneWidget);
    });

    testWidgets('renders rows for each dive center', (tester) async {
      final centers = [
        _makeCenter(id: 'dc1', name: 'Blue Water Dive'),
        _makeCenter(id: 'dc2', name: 'Red Sea Divers'),
        _makeCenter(id: 'dc3', name: 'Pacific Reef Dive'),
      ];

      final overrides = await _buildOverrides(centers: centers);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveCenterListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Blue Water Dive'), findsOneWidget);
      expect(find.text('Red Sea Divers'), findsOneWidget);
      expect(find.text('Pacific Reef Dive'), findsOneWidget);
    });

    testWidgets('shows empty state when no centers', (tester) async {
      final overrides = await _buildOverrides(centers: []);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveCenterListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.store_outlined), findsOneWidget);
    });

    testWidgets('table app bar includes column settings button', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        centers: [_makeCenter(id: 'dc1', name: 'Test Center')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveCenterListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.view_column_outlined), findsOneWidget);
    });

    testWidgets('renders with showAppBar false (compact bar)', (tester) async {
      final overrides = await _buildOverrides(
        centers: [_makeCenter(id: 'dc1', name: 'Coral Reef Center')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveCenterListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      expect(find.text('Coral Reef Center'), findsOneWidget);
    });

    testWidgets('table app bar has map button', (tester) async {
      final overrides = await _buildOverrides(
        centers: [_makeCenter(id: 'dc1', name: 'Test Center')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveCenterListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.map), findsOneWidget);
    });

    testWidgets('table app bar has search button', (tester) async {
      final overrides = await _buildOverrides(
        centers: [_makeCenter(id: 'dc1', name: 'Test Center')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveCenterListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('table app bar has sort button', (tester) async {
      final overrides = await _buildOverrides(
        centers: [_makeCenter(id: 'dc1', name: 'Test Center')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveCenterListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.sort), findsOneWidget);
    });

    testWidgets('table app bar has more options popup', (tester) async {
      final overrides = await _buildOverrides(
        centers: [_makeCenter(id: 'dc1', name: 'Test Center')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveCenterListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('table app bar popup menu shows view mode items', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        centers: [_makeCenter(id: 'dc1', name: 'Test Center')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveCenterListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Detailed'), findsOneWidget);
      expect(find.text('Compact'), findsOneWidget);
    });

    testWidgets('table app bar has vertical divider', (tester) async {
      final overrides = await _buildOverrides(
        centers: [_makeCenter(id: 'dc1', name: 'Test Center')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveCenterListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.byType(VerticalDivider), findsOneWidget);
    });

    testWidgets('compact bar shows map button', (tester) async {
      final overrides = await _buildOverrides(
        centers: [_makeCenter(id: 'dc1', name: 'Coral Reef Center')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveCenterListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.map), findsOneWidget);
    });

    testWidgets('compact bar shows search button', (tester) async {
      final overrides = await _buildOverrides(
        centers: [_makeCenter(id: 'dc1', name: 'Coral Reef Center')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveCenterListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('compact bar shows sort button', (tester) async {
      final overrides = await _buildOverrides(
        centers: [_makeCenter(id: 'dc1', name: 'Coral Reef Center')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveCenterListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.sort), findsOneWidget);
    });

    testWidgets('compact bar shows popup menu', (tester) async {
      final overrides = await _buildOverrides(
        centers: [_makeCenter(id: 'dc1', name: 'Coral Reef Center')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveCenterListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('table renders dive center data in cells', (tester) async {
      final centers = [
        _makeCenter(
          id: 'dc1',
          name: 'Blue Water Dive',
          city: 'Cairns',
          country: 'Australia',
          rating: 4.5,
        ),
      ];

      final overrides = await _buildOverrides(centers: centers);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveCenterListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Blue Water Dive'), findsOneWidget);
      expect(find.text('Cairns'), findsOneWidget);
      expect(find.text('Australia'), findsOneWidget);
    });

    testWidgets('renders centers with null optional fields', (tester) async {
      final centers = [
        _makeCenter(
          id: 'null1',
          name: 'Basic Center',
          city: null,
          country: null,
          phone: null,
          rating: null,
        ),
      ];

      final overrides = await _buildOverrides(centers: centers);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveCenterListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Basic Center'), findsOneWidget);
    });

    testWidgets('compact bar shows more menu', (tester) async {
      final overrides = await _buildOverrides(
        centers: [_makeCenter(id: 'dc1', name: 'Coral Reef Center')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveCenterListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('renders many centers without crash', (tester) async {
      final centers = List.generate(
        10,
        (i) => _makeCenter(
          id: 'mc$i',
          name: 'Center $i',
          city: 'City $i',
          country: 'Country $i',
        ),
      );

      final overrides = await _buildOverrides(centers: centers);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveCenterListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Center 0'), findsOneWidget);
    });

    testWidgets('renders with phone and rating data', (tester) async {
      final centers = [
        _makeCenter(
          id: 'pr1',
          name: 'Phone Center',
          phone: '+1-555-1234',
          rating: 4.0,
        ),
      ];

      final overrides = await _buildOverrides(centers: centers);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveCenterListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Phone Center'), findsOneWidget);
    });

    testWidgets('tapping sort button opens sort sheet and selects option', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        centers: [_makeCenter(id: 'dc1', name: 'Test Center')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveCenterListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();

      expect(find.text('Sort Dive Centers'), findsOneWidget);

      await tester.tap(find.text('Dive Count'));
      await tester.pumpAndSettle();
    });

    testWidgets('tapping popup Detailed switches from table mode', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        centers: [_makeCenter(id: 'dc1', name: 'Test Center')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveCenterListContent(showAppBar: true),
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
        centers: [_makeCenter(id: 'dc1', name: 'Test Center')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveCenterListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();

      expect(find.text('Sort Dive Centers'), findsOneWidget);

      await tester.tap(find.text('Dive Count'));
      await tester.pumpAndSettle();
    });

    testWidgets('compact bar popup Detailed switches view mode', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        centers: [_makeCenter(id: 'dc1', name: 'Test Center')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const DiveCenterListContent(showAppBar: false),
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
