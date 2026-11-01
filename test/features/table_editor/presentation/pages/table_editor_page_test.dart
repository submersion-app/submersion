import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/dive_centers/domain/constants/dive_center_field.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/bulk_dive_edit_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/constants/site_field.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/table_editor/entities/dive_table_editor_entity.dart';
import 'package:submersion/features/table_editor/presentation/pages/table_editor_page.dart';
import 'package:submersion/features/table_editor/presentation/providers/table_editor_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/constants/entity_field.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

class _Config<F extends EntityField> extends EntityTableConfigNotifier<F> {
  _Config(EntityTableViewConfig<F> config, F Function(String) fromName)
    : super(defaultConfig: config, fieldFromName: fromName) {
    state = config;
  }
}

/// The Table editor page (#3422): tabs, the width gate, Save all with its
/// summary and Undo, and the guards around leaving with drafts.
void main() {
  final l10n = AppLocalizationsEn();
  late DiveRepository diveRepo;
  late List<Dive> dives;
  final pushed = <String>[];

  String vis(double m) => const UnitFormatter(AppSettings()).formatDistance(m);

  setUp(() async {
    await setUpTestDatabase();
    diveRepo = DiveRepository();
    for (final (id, n, v) in [('d1', 1, 15.0), ('d2', 2, 20.0)]) {
      await diveRepo.createDive(
        Dive(
          id: id,
          diveNumber: n,
          dateTime: DateTime(2026, 1, n),
          visibilityMeters: v,
        ),
      );
    }
    dives = await diveRepo.getDivesByIdsWithoutSamples(['d1', 'd2']);
    pushed.clear();
  });

  tearDown(() async => tearDownTestDatabase());

  Future<void> pumpPage(
    WidgetTester tester, {
    Size size = const Size(1200, 800),
  }) async {
    // The width gate reads MediaQuery, which follows the view, not the
    // test surface.
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final entity = DiveTableEditorEntity(
      diveRepo: diveRepo,
      bulk: BulkDiveEditService(
        diveRepo,
        BuddyRepository(),
        SpeciesRepository(),
      ),
      sites: const [],
      centers: const [],
      trips: const [],
    );
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/settings/table-editor'),
              child: const Text('open editor'),
            ),
          ),
        ),
        GoRoute(
          path: '/settings/table-editor',
          builder: (context, state) => const TableEditorPage(),
        ),
        GoRoute(
          path: '/dives/:id',
          builder: (context, state) {
            pushed.add('/dives/${state.pathParameters['id']}');
            return const Scaffold(body: Text('dive page'));
          },
        ),
      ],
    );
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          tableEditorDivesProvider.overrideWithValue(AsyncValue.data(dives)),
          tableEditorDiveEntityProvider.overrideWithValue(
            AsyncValue.data(entity),
          ),
          tableEditorSitesProvider.overrideWithValue(const AsyncValue.data([])),
          tableEditorCentersProvider.overrideWithValue(
            const AsyncValue.data([]),
          ),
          diveSurfaceIntervalsProvider.overrideWith(
            (ref) async => const <String, Duration?>{},
          ),
          allDiveComputersProvider.overrideWith((ref) async => const []),
          tableEditorDiveConfigProvider.overrideWith(
            (ref) => _Config<DiveField>(
              EntityTableViewConfig(
                columns: [
                  EntityTableColumnConfig(
                    field: DiveField.diveNumber,
                    isPinned: true,
                  ),
                  EntityTableColumnConfig(field: DiveField.visibility),
                ],
              ),
              (n) => diveFieldFromName(n) ?? DiveField.diveNumber,
            ),
          ),
          tableEditorSiteConfigProvider.overrideWith(
            (ref) => _Config<SiteField>(
              EntityTableViewConfig(
                columns: [
                  EntityTableColumnConfig(
                    field: SiteField.siteName,
                    isPinned: true,
                  ),
                ],
              ),
              SiteFieldAdapter.instance.fieldFromName,
            ),
          ),
          tableEditorCenterConfigProvider.overrideWith(
            (ref) => _Config<DiveCenterField>(
              EntityTableViewConfig(
                columns: [
                  EntityTableColumnConfig(
                    field: DiveCenterField.centerName,
                    isPinned: true,
                  ),
                ],
              ),
              DiveCenterFieldAdapter.instance.fieldFromName,
            ),
          ),
        ],
      ),
    );
    await tester.tap(find.text('open editor'));
    await tester.pumpAndSettle();
  }

  Future<void> draftVisibility(WidgetTester tester, String text) async {
    await tester.tap(find.text(vis(15)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
  }

  testWidgets('shows three tabs and the dive sheet', (tester) async {
    await pumpPage(tester);

    expect(find.text(l10n.tableEditor_tab_dives), findsOneWidget);
    expect(find.text(l10n.tableEditor_tab_sites), findsOneWidget);
    expect(find.text(l10n.tableEditor_tab_centers), findsOneWidget);
    expect(find.text(vis(15)), findsOneWidget);
    expect(find.text(vis(20)), findsOneWidget);
  });

  testWidgets('a narrow window shows only the wider screen message', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(600, 800));

    expect(find.text(l10n.tableEditor_needsWiderScreen), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
  });

  testWidgets('Save all is disabled without drafts and enabled with one', (
    tester,
  ) async {
    await pumpPage(tester);
    final button = find.widgetWithText(FilledButton, l10n.tableEditor_saveAll);
    expect(tester.widget<FilledButton>(button).enabled, isFalse);

    await draftVisibility(tester, '12');

    expect(tester.widget<FilledButton>(button).enabled, isTrue);
    expect(find.text(l10n.tableEditor_draftCount(1)), findsOneWidget);
  });

  testWidgets('leaving with drafts asks first', (tester) async {
    await pumpPage(tester);
    await draftVisibility(tester, '12');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text(l10n.forms_discard_title), findsOneWidget);
    await tester.tap(find.text(l10n.forms_discard_keepEditing));
    await tester.pumpAndSettle();
    expect(find.byType(TableEditorPage), findsOneWidget);
  });

  testWidgets('Save all shows the summary then saves and offers Undo', (
    tester,
  ) async {
    await pumpPage(tester);
    await draftVisibility(tester, '12');

    await tester.tap(
      find.widgetWithText(FilledButton, l10n.tableEditor_saveAll),
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.tableEditor_summary_title), findsOneWidget);
    expect(find.text(l10n.tableEditor_summary_changed(1)), findsOneWidget);
    expect(find.text(l10n.tableEditor_summary_overwrite(1)), findsOneWidget);

    await tester.tap(
      find.widgetWithText(FilledButton, l10n.tableEditor_saveAll).last,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final saved = await diveRepo.getDivesByIdsWithoutSamples(['d1']);
    expect(saved.single.visibilityMeters, 12);
    expect(find.text(l10n.tableEditor_undo), findsOneWidget);
    expect(find.text(l10n.tableEditor_draftCount(1)), findsNothing);
  });

  testWidgets('double tap with drafts offers Save all and open', (
    tester,
  ) async {
    await pumpPage(tester);
    await draftVisibility(tester, '12');

    await tester.tap(find.text(vis(20)));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text(vis(20)));
    await tester.pumpAndSettle();

    expect(find.text(l10n.tableEditor_open_saveAndOpen), findsOneWidget);
    await tester.tap(find.text(l10n.tableEditor_open_discardAndOpen));
    await tester.pumpAndSettle();
    expect(pushed, ['/dives/d2']);
  });

  testWidgets('switching tabs with drafts asks first', (tester) async {
    await pumpPage(tester);
    await draftVisibility(tester, '12');

    await tester.tap(find.text(l10n.tableEditor_tab_sites));
    await tester.pumpAndSettle();

    expect(find.text(l10n.forms_discard_title), findsOneWidget);
    await tester.tap(find.text(l10n.forms_discard_keepEditing));
    await tester.pumpAndSettle();
    expect(find.text(l10n.tableEditor_draftCount(1)), findsOneWidget);
    expect(find.text(vis(12)), findsOneWidget);
  });

  testWidgets('drafts survive a window narrowed below the gate', (
    tester,
  ) async {
    await pumpPage(tester);
    await draftVisibility(tester, '12');

    tester.view.physicalSize = const Size(600, 800);
    await tester.pumpAndSettle();
    expect(find.text(l10n.tableEditor_needsWiderScreen), findsOneWidget);

    tester.view.physicalSize = const Size(1200, 800);
    await tester.pumpAndSettle();
    expect(find.text(l10n.tableEditor_draftCount(1)), findsOneWidget);
  });

  testWidgets('back from the narrow view with drafts asks first', (
    tester,
  ) async {
    await pumpPage(tester);
    await draftVisibility(tester, '12');
    tester.view.physicalSize = const Size(600, 800);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text(l10n.forms_discard_title), findsOneWidget);
  });
}
