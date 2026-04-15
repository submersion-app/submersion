import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
import 'package:submersion/l10n/arb/app_localizations.dart';
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

Future<List<Override>> _buildPhoneOverrides({
  required List<Certification> certs,
  String? highlightedCertificationId,
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
    certificationListViewModeProvider.overrideWith(
      (ref) => ListViewMode.detailed,
    ),
    certificationTableConfigProvider.overrideWith(
      (ref) => _TestCertTableConfigNotifier(_testConfig),
    ),
    if (highlightedCertificationId != null)
      highlightedCertificationIdProvider.overrideWith(
        (ref) => highlightedCertificationId,
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

      // Verify column headers appear (displayName values)
      expect(find.text('Name'), findsWidgets);
      expect(find.text('Agency'), findsOneWidget);
      expect(find.text('Level'), findsOneWidget);
      expect(find.text('Issue Date'), findsOneWidget);
      expect(find.text('Expiry Date'), findsOneWidget);
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

    // Column settings are now provided by TableModeLayout, not the content
    // widget. The compact bar provides wallet, sort, search, and view mode
    // controls.

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

    testWidgets('tapping a row sets highlighted certification id', (
      tester,
    ) async {
      final certs = [
        _makeCert(id: 'c1', name: 'PADI OW'),
        _makeCert(id: 'c2', name: 'SSI AOW'),
      ];

      final overrides = await _buildOverrides(certs: certs);

      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides.cast(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return const Scaffold(
                  body: CertificationListContent(showAppBar: true),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap on a certification row
      await tester.tap(find.text('PADI OW'));
      // Pump past the DoubleTapGestureRecognizer's 300ms timeout
      await tester.pump(const Duration(milliseconds: 350));

      // The tap should have set the highlighted certification ID
      expect(container.read(highlightedCertificationIdProvider), 'c1');
    });

    testWidgets('double-tapping a row navigates to certification detail', (
      tester,
    ) async {
      final certs = [_makeCert(id: 'c1', name: 'PADI OW')];

      final overrides = await _buildOverrides(certs: certs);

      String? pushedPath;
      final router = GoRouter(
        initialLocation: '/certifications',
        routes: [
          GoRoute(
            path: '/certifications',
            builder: (context, state) => const Scaffold(
              body: CertificationListContent(showAppBar: true),
            ),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  pushedPath = state.uri.toString();
                  return const Scaffold(body: SizedBox());
                },
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides.cast(),
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();

      // Double-tap on a certification row
      await tester.tap(find.text('PADI OW'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('PADI OW'));
      await tester.pumpAndSettle();

      expect(pushedPath, '/certifications/c1');
    });
  });

  group('phone-mode highlight', () {
    testWidgets(
      'phone view highlights certification when highlightedCertificationIdProvider is set',
      (tester) async {
        final certs = [
          _makeCert(id: 'c1', name: 'Open Water'),
          _makeCert(id: 'c2', name: 'Rescue Diver'),
        ];

        final overrides = await _buildPhoneOverrides(
          certs: certs,
          highlightedCertificationId: 'c2',
        );

        await tester.pumpWidget(
          testApp(
            overrides: overrides,
            child: const CertificationListContent(showAppBar: false),
          ),
        );
        await tester.pumpAndSettle();

        final tiles = tester
            .widgetList<CertificationListTile>(
              find.byType(CertificationListTile),
            )
            .toList();
        final ow = tiles.firstWhere((t) => t.certification.id == 'c1');
        final rescue = tiles.firstWhere((t) => t.certification.id == 'c2');

        expect(ow.isSelected, isFalse);
        expect(rescue.isSelected, isTrue);
      },
    );
  });
}
