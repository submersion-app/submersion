import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certifications/domain/constants/certification_field.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_list_content.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _TestCertTableConfigNotifier
    extends EntityTableConfigNotifier<CertificationField> {
  _TestCertTableConfigNotifier(EntityTableViewConfig<CertificationField> config)
    : super(
        defaultConfig: config,
        fieldFromName: CertificationFieldAdapter.instance.fieldFromName,
      );
}

class _MockCertListNotifier
    extends StateNotifier<AsyncValue<List<Certification>>>
    implements CertificationListNotifier {
  _MockCertListNotifier(List<Certification> certs)
    : super(AsyncValue.data(certs));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final _testConfig = EntityTableViewConfig<CertificationField>(
  columns: [
    EntityTableColumnConfig(field: CertificationField.certName, isPinned: true),
    EntityTableColumnConfig(field: CertificationField.agency),
    EntityTableColumnConfig(field: CertificationField.level),
    EntityTableColumnConfig(field: CertificationField.issueDate),
    EntityTableColumnConfig(field: CertificationField.expiryDate),
    EntityTableColumnConfig(field: CertificationField.expiryStatus),
  ],
);

final _now = DateTime.now();

Certification _makeCert({
  required String id,
  required String name,
  CertificationAgency agency = CertificationAgency.padi,
  CertificationLevel? level,
  DateTime? issueDate,
  DateTime? expiryDate,
}) {
  return Certification(
    id: id,
    name: name,
    agency: agency,
    level: level,
    issueDate: issueDate,
    expiryDate: expiryDate,
    createdAt: _now,
    updatedAt: _now,
  );
}

Future<List<Override>> _buildOverrides({
  required List<Certification> certs,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
    certificationListNotifierProvider.overrideWith(
      (ref) => _MockCertListNotifier(certs),
    ),
    certificationListViewModeProvider.overrideWith((ref) => ListViewMode.table),
    certificationTableConfigProvider.overrideWith(
      (ref) => _TestCertTableConfigNotifier(_testConfig),
    ),
  ];
}

void main() {
  group('CertificationListContent in table mode', () {
    testWidgets('renders table with column headers', (tester) async {
      final certs = [
        _makeCert(
          id: 'c1',
          name: 'Open Water Diver',
          agency: CertificationAgency.padi,
          level: CertificationLevel.openWater,
          issueDate: DateTime(2023, 1, 15),
        ),
        _makeCert(
          id: 'c2',
          name: 'Advanced Open Water',
          agency: CertificationAgency.ssi,
          level: CertificationLevel.advancedOpenWater,
          issueDate: DateTime(2023, 6, 20),
        ),
      ];

      final overrides = await _buildOverrides(certs: certs);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CertificationListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      // Verify column headers appear (shortLabel values)
      expect(find.text('Name'), findsWidgets);
      expect(find.text('Agency'), findsOneWidget);
      expect(find.text('Level'), findsOneWidget);
      expect(find.text('Issued'), findsOneWidget);
      expect(find.text('Expires'), findsOneWidget);
    });

    testWidgets('renders rows for each certification', (tester) async {
      final certs = [
        _makeCert(id: 'c1', name: 'Open Water Diver'),
        _makeCert(id: 'c2', name: 'Advanced Open Water'),
        _makeCert(id: 'c3', name: 'Rescue Diver'),
      ];

      final overrides = await _buildOverrides(certs: certs);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CertificationListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Open Water Diver'), findsOneWidget);
      expect(find.text('Advanced Open Water'), findsOneWidget);
      expect(find.text('Rescue Diver'), findsOneWidget);
    });

    testWidgets('shows empty state when no certifications', (tester) async {
      final overrides = await _buildOverrides(certs: []);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CertificationListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      // The empty state shows a card icon
      expect(find.byIcon(Icons.card_membership_outlined), findsOneWidget);
    });

    testWidgets('table app bar includes column settings button', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        certs: [_makeCert(id: 'c1', name: 'Open Water')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CertificationListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.view_column_outlined), findsOneWidget);
    });

    testWidgets('renders with showAppBar false (compact bar)', (tester) async {
      final overrides = await _buildOverrides(
        certs: [_makeCert(id: 'c1', name: 'Nitrox Diver')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CertificationListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      expect(find.text('Nitrox Diver'), findsOneWidget);
    });

    testWidgets('table app bar has wallet button', (tester) async {
      final overrides = await _buildOverrides(
        certs: [_makeCert(id: 'c1', name: 'Open Water')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CertificationListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.wallet), findsOneWidget);
    });

    testWidgets('table app bar has search button', (tester) async {
      final overrides = await _buildOverrides(
        certs: [_makeCert(id: 'c1', name: 'Open Water')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CertificationListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('table app bar has more options popup', (tester) async {
      final overrides = await _buildOverrides(
        certs: [_makeCert(id: 'c1', name: 'Open Water')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CertificationListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('table app bar popup menu shows view mode items', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        certs: [_makeCert(id: 'c1', name: 'Open Water')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CertificationListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Detailed'), findsOneWidget);
    });

    testWidgets('table app bar has vertical divider', (tester) async {
      final overrides = await _buildOverrides(
        certs: [_makeCert(id: 'c1', name: 'Open Water')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CertificationListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.byType(VerticalDivider), findsOneWidget);
    });

    testWidgets('compact bar in table mode shows column settings button', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        certs: [_makeCert(id: 'c1', name: 'Nitrox Diver')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CertificationListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      // Compact bar in table mode should also have column settings button
      expect(find.byIcon(Icons.view_column_outlined), findsOneWidget);
    });

    testWidgets('compact bar in table mode shows wallet button', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        certs: [_makeCert(id: 'c1', name: 'Nitrox Diver')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CertificationListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.wallet), findsOneWidget);
    });

    testWidgets('compact bar in table mode shows search button', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        certs: [_makeCert(id: 'c1', name: 'Nitrox Diver')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CertificationListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('compact bar in table mode shows sort button', (tester) async {
      final overrides = await _buildOverrides(
        certs: [_makeCert(id: 'c1', name: 'Nitrox Diver')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CertificationListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.sort), findsOneWidget);
    });

    testWidgets('compact bar in table mode shows popup menu', (tester) async {
      final overrides = await _buildOverrides(
        certs: [_makeCert(id: 'c1', name: 'Nitrox Diver')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CertificationListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('table renders certification data in cells', (tester) async {
      final certs = [
        _makeCert(
          id: 'c1',
          name: 'Open Water Diver',
          agency: CertificationAgency.padi,
          level: CertificationLevel.openWater,
          issueDate: DateTime(2023, 1, 15),
        ),
      ];

      final overrides = await _buildOverrides(certs: certs);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CertificationListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      // Cert name should be in the table cells
      expect(find.text('Open Water Diver'), findsOneWidget);
    });

    testWidgets('renders with expired certification data', (tester) async {
      final certs = [
        _makeCert(
          id: 'exp1',
          name: 'First Aid',
          agency: CertificationAgency.padi,
          issueDate: DateTime(2021, 1, 1),
          expiryDate: DateTime(2023, 1, 1),
        ),
      ];

      final overrides = await _buildOverrides(certs: certs);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CertificationListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('First Aid'), findsOneWidget);
    });

    testWidgets('renders with multiple certification levels', (tester) async {
      final certs = [
        _makeCert(
          id: 'ml1',
          name: 'Open Water',
          level: CertificationLevel.openWater,
        ),
        _makeCert(
          id: 'ml2',
          name: 'Advanced',
          level: CertificationLevel.advancedOpenWater,
        ),
        _makeCert(id: 'ml3', name: 'Rescue', level: CertificationLevel.rescue),
        _makeCert(
          id: 'ml4',
          name: 'Divemaster',
          level: CertificationLevel.diveMaster,
        ),
      ];

      final overrides = await _buildOverrides(certs: certs);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CertificationListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Open Water'), findsOneWidget);
      expect(find.text('Advanced'), findsOneWidget);
      expect(find.text('Rescue'), findsOneWidget);
      expect(find.text('Divemaster'), findsOneWidget);
    });

    testWidgets('compact bar in table mode shows column settings icon', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        certs: [_makeCert(id: 'cb1', name: 'Nitrox')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CertificationListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.view_column_outlined), findsOneWidget);
      expect(find.text('Nitrox'), findsOneWidget);
    });

    testWidgets('renders with various agencies', (tester) async {
      final certs = [
        _makeCert(
          id: 'a1',
          name: 'PADI Cert',
          agency: CertificationAgency.padi,
        ),
        _makeCert(id: 'a2', name: 'SSI Cert', agency: CertificationAgency.ssi),
        _makeCert(
          id: 'a3',
          name: 'NAUI Cert',
          agency: CertificationAgency.naui,
        ),
      ];

      final overrides = await _buildOverrides(certs: certs);

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CertificationListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('PADI Cert'), findsOneWidget);
      expect(find.text('SSI Cert'), findsOneWidget);
      expect(find.text('NAUI Cert'), findsOneWidget);
    });

    testWidgets('tapping popup menu Detailed switches from table mode', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        certs: [_makeCert(id: 'c1', name: 'Test Cert')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CertificationListContent(showAppBar: true),
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
        certs: [_makeCert(id: 'c1', name: 'Test Cert')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CertificationListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();

      expect(find.text('Sort Certifications'), findsOneWidget);

      // Tap a sort option to invoke the onSortChanged callback
      await tester.tap(find.text('Date Issued'));
      await tester.pumpAndSettle();
    });

    testWidgets('compact bar column settings opens picker', (tester) async {
      final overrides = await _buildOverrides(
        certs: [_makeCert(id: 'c1', name: 'Test Cert')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CertificationListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.view_column_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Columns'), findsOneWidget);
    });

    testWidgets('compact bar popup menu Detailed switches view mode', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        certs: [_makeCert(id: 'c1', name: 'Test Cert')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CertificationListContent(showAppBar: false),
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
