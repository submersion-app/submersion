import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
import '../../../../helpers/bulk_delete_contract.dart';
import '../../../../helpers/selection_contract.dart';

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

  /// Narrow the visible list, standing in for a filter change.
  void showOnly(List<Certification> certs) {
    state = AsyncValue.data(certs);
  }

  /// Ids bulk delete actually asked to remove.
  final deleted = <String>[];

  @override
  Future<void> deleteCertification(String id) async => deleted.add(id);

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
  group('bulk delete', () {
    late _MockCertListNotifier notifier;

    Future<Widget> host(List<dynamic> rows) async {
      notifier = _MockCertListNotifier(rows.cast());
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      return testApp(
        locale: const Locale('en'),
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          certificationListNotifierProvider.overrideWith((ref) => notifier),
          certificationListViewModeProvider.overrideWith(
            (ref) => ListViewMode.detailed,
          ),
          certificationTableConfigProvider.overrideWith(
            (ref) => _TestCertTableConfigNotifier(_testConfig),
          ),
        ],
        child: const CertificationListContent(showAppBar: true),
      );
    }

    testWidgets('deletes every checked row and reports the count', (
      tester,
    ) async {
      final widget = await host([
        _makeCert(id: 'x1', name: 'Aaa Cert'),
        _makeCert(id: 'x2', name: 'Bbb Cert'),
      ]);

      await verifyBulkDelete(
        tester,
        build: () => widget,
        selectButton: find.byKey(const ValueKey('enter_selection')),
        expectedDeletedCount: 2,
      );

      expect(notifier.deleted, ['x1', 'x2']);
      expect(find.text('2 deleted'), findsOneWidget);
    });

    testWidgets('cancelling deletes nothing and keeps the selection', (
      tester,
    ) async {
      final widget = await host([_makeCert(id: 'x1', name: 'Aaa Cert')]);

      await verifyBulkDeleteCancels(
        tester,
        build: () => widget,
        selectButton: find.byKey(const ValueKey('enter_selection')),
      );

      expect(notifier.deleted, isEmpty);
    });
  });

  group('selection contract', () {
    testWidgets('satisfies the shared selection contract', (tester) async {
      final all = <Certification>[
        _makeCert(id: 'x1', name: 'Aaa Cert'),
        _makeCert(id: 'x2', name: 'Bbb Cert'),
        _makeCert(id: 'x3', name: 'Ccc Cert'),
      ];
      final notifier = _MockCertListNotifier(all);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final overrides = <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        certificationListNotifierProvider.overrideWith((ref) => notifier),
        certificationListViewModeProvider.overrideWith(
          (ref) => ListViewMode.detailed,
        ),
        certificationTableConfigProvider.overrideWith(
          (ref) => _TestCertTableConfigNotifier(_testConfig),
        ),
      ];

      await verifySelectionContract(
        tester,
        build: () => testApp(
          overrides: overrides,
          locale: const Locale('en'),
          child: const CertificationListContent(showAppBar: true),
        ),
        selectButton: find.byKey(const ValueKey('enter_selection')),
        rowRoot: find.ancestor(
          of: find.text('Aaa Cert'),
          matching: find.byType(CertificationListTile),
        ),
        firstRow: find.text('Aaa Cert'),
        applyFilter: (tester) async {
          notifier.showOnly([all.first]);
        },
        visibleAfterFilter: 1,
      );
    });
  });

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
      expect(find.text('Certification'), findsOneWidget);
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
    // widget. The compact bar provides wallet, search, sort, and view mode
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

      // ml1 and ml4 store a name identical to their certification, so the
      // Name column derives it and both columns show the same string; ml2 and
      // ml3 store names that differ from theirs and are kept verbatim.
      expect(find.text('Open Water'), findsNWidgets(2));
      expect(find.text('Advanced'), findsOneWidget);
      expect(find.text('Rescue'), findsOneWidget);
      expect(find.text('Divemaster'), findsNWidgets(2));
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

  // The canonical action order across every entity list, taken from the
  // Dives/Sites baseline:
  //
  //   [view switches: map, wallet] search  filter  sort  select  overflow
  //
  // Certifications is the strictest case in the app: it is the only bar
  // carrying a view switch (wallet) alongside search, sort, select and
  // overflow, so it pins every neighbour pair in the sequence. It used to
  // render sort before search.
  group('compact bar action order', () {
    testWidgets('follows the canonical order', (tester) async {
      final overrides = await _buildPhoneOverrides(
        certs: [_makeCert(id: 'c1', name: 'Nitrox Diver')],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CertificationListContent(showAppBar: false),
        ),
      );
      await tester.pump();

      const expected = <IconData>[
        Icons.wallet,
        Icons.search,
        Icons.sort,
        Icons.checklist,
        Icons.more_vert,
      ];

      final xs = [
        for (final icon in expected)
          tester.getCenter(find.byIcon(icon).first).dx,
      ];

      for (var i = 1; i < xs.length; i++) {
        expect(
          xs[i],
          greaterThan(xs[i - 1]),
          reason:
              '${expected[i]} must sit right of ${expected[i - 1]} '
              '(got ${xs[i]} vs ${xs[i - 1]})',
        );
      }
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

  group('title derivation', () {
    // The subtitle dates itself with DateFormat.yMMMd(), which resolves
    // against Intl.defaultLocale (a process global that app.dart sets from the
    // app locale), NOT the MaterialApp.locale the harness passes. Pin it so
    // the "Aug 24, 2026" assertions below state their real dependency instead
    // of riding on intl's implicit en_US fallback, and restore it so the
    // global stays contained. No initializeDateFormatting is needed: these are
    // widget tests, so GlobalMaterialLocalizations loads the symbol data.
    String? previousLocale;
    setUp(() {
      previousLocale = Intl.defaultLocale;
      Intl.defaultLocale = 'en';
    });
    tearDown(() => Intl.defaultLocale = previousLocale);

    testWidgets('a cert with no stored name still shows a title', (
      tester,
    ) async {
      final overrides = await _buildOverrides(
        certs: [
          _makeCert(id: 'n1', name: '', level: CertificationLevel.openWater),
        ],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CertificationListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Open Water'), findsWidgets);
    });

    testWidgets('accessibility label names the agency exactly once', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      final overrides = await _buildPhoneOverrides(
        certs: [
          _makeCert(
            id: 'n3',
            name: 'PADI : Open Water',
            level: CertificationLevel.openWater,
          ),
        ],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CertificationListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      // The label stands in for the whole tile, so it must carry the agency --
      // but exactly once. It has been wrong in both directions: originally
      // "PADI PADI : Open Water", then briefly with no agency at all.
      expect(find.bySemanticsLabel('PADI Open Water'), findsOneWidget);

      // Must be disposed before the test body ends; addTearDown runs after
      // the framework's own handle check.
      handle.dispose();
    });

    testWidgets('a derived stored name is not shown verbatim', (tester) async {
      final overrides = await _buildOverrides(
        certs: [
          _makeCert(
            id: 'n2',
            name: 'PADI : Open Water',
            level: CertificationLevel.openWater,
          ),
        ],
      );

      await tester.pumpWidget(
        testApp(
          overrides: overrides,
          child: const CertificationListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('PADI : Open Water'), findsNothing);
      // The Name column derives the certification; the Agency column still
      // carries "PADI" on its own, so the title must not repeat it.
      expect(find.text('Open Water'), findsWidgets);
    });

    // A custom name takes the title, which leaves the level with nowhere to go
    // unless the subtitle carries it. See issue #1265: a card entered as
    // "Bill Ansell" / PADI / Divemaster showed no trace of "Divemaster".
    testWidgets('a custom name keeps the certification in the subtitle', (
      tester,
    ) async {
      final overrides = await _buildPhoneOverrides(
        certs: [
          _makeCert(
            id: 'c1',
            name: 'Bill Ansell',
            level: CertificationLevel.diveMaster,
            issueDate: DateTime(2026, 8, 24),
          ),
        ],
      );

      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: overrides,
          child: const CertificationListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      expect(find.text('Bill Ansell'), findsOneWidget);
      expect(find.text('PADI - Divemaster - Aug 24, 2026'), findsOneWidget);
    });

    testWidgets('a derived title does not repeat the level in the subtitle', (
      tester,
    ) async {
      final overrides = await _buildPhoneOverrides(
        certs: [
          _makeCert(
            id: 'c2',
            name: '',
            level: CertificationLevel.diveMaster,
            issueDate: DateTime(2026, 8, 24),
          ),
        ],
      );

      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: overrides,
          child: const CertificationListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      // The title already says "Divemaster"; the subtitle must not say it
      // again, which is the duplication the title helper exists to remove.
      expect(find.text('Divemaster'), findsOneWidget);
      expect(find.text('PADI - Aug 24, 2026'), findsOneWidget);
    });

    testWidgets('accessibility label names the certification too', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      final overrides = await _buildPhoneOverrides(
        certs: [
          _makeCert(
            id: 'c3',
            name: 'Bill Ansell',
            level: CertificationLevel.diveMaster,
          ),
        ],
      );

      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: overrides,
          child: const CertificationListContent(showAppBar: true),
        ),
      );
      await tester.pump();

      // The label stands in for the whole tile, so a screen reader must hear
      // the level even when a custom name owns the title.
      expect(
        find.bySemanticsLabel('PADI Bill Ansell, Divemaster'),
        findsOneWidget,
      );

      handle.dispose();
    });
  });
}
