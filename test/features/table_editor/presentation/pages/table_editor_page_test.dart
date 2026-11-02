import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/app/app_exit_guard.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/dive_centers/domain/constants/dive_center_field.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/bulk_dive_edit_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/constants/site_field.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/table_editor/entities/site_table_editor_entity.dart';
import 'package:flutter/services.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/table_editor/data/table_editor_save_service.dart';
import 'package:submersion/features/table_editor/domain/table_draft.dart';
import 'package:submersion/features/table_editor/domain/table_editor_entity.dart';
import 'package:submersion/features/table_editor/entities/dive_table_editor_entity.dart';
import 'package:submersion/features/table_editor/presentation/pages/table_editor_page.dart';
import 'package:submersion/features/table_editor/presentation/providers/table_editor_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/constants/entity_field.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_column_picker.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

class _Config<F extends EntityField> extends EntityTableConfigNotifier<F> {
  _Config(EntityTableViewConfig<F> config, F Function(String) fromName)
    : super(defaultConfig: config, fieldFromName: fromName) {
    state = config;
  }
}

/// A save held open until the test lets it finish.
class _HeldSave extends TableEditorSaveService {
  final release = Completer<void>();

  @override
  Future<TableEditorSaveResult> save<T, F extends EntityField>({
    required TableEditorEntity<T, F> entity,
    required List<TableDraft> drafts,
  }) async {
    await release.future;
    return TableEditorSaveResult(
      operationId: null,
      saved: drafts.length,
      changedElsewhere: const [],
    );
  }
}

/// A save that finds every draft moved, to [current] when given, or to what
/// the draft itself says.
class _StaleSave extends TableEditorSaveService {
  final Object? current;
  final bool toDraftValue;
  _StaleSave.to(this.current) : toDraftValue = false;
  _StaleSave.toDraftValue() : current = null, toDraftValue = true;

  @override
  Future<TableEditorSaveResult> save<T, F extends EntityField>({
    required TableEditorEntity<T, F> entity,
    required List<TableDraft> drafts,
  }) async => TableEditorSaveResult(
    operationId: null,
    saved: 0,
    changedElsewhere: [
      for (final d in drafts) StaleDraft(d, toDraftValue ? d.value : current),
    ],
  );
}

/// Counts the reloads a save asks of the dive list.
class _DiveList extends StateNotifier<AsyncValue<List<Dive>>>
    implements DiveListNotifier {
  _DiveList() : super(const AsyncValue.data([]));

  var fullReloads = 0;
  var quietReloads = 0;

  @override
  Future<void> refresh() async => fullReloads++;

  @override
  Future<void> reloadQuietly() async => quietReloads++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
    List<SiteWithCount> sites = const [],
    TableEditorSaveService? saveService,
    AppExitGuard? exitGuard,
    List<DiveField> extraDiveColumns = const [],
    List<SiteField> extraSiteColumns = const [],
    AsyncValue<List<Dive>>? divesValue,
    DiveListNotifier? diveList,
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
          onExit: confirmLeaveTableEditor,
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
          if (saveService != null)
            tableEditorSaveServiceProvider.overrideWithValue(saveService),
          if (exitGuard != null)
            appExitGuardProvider.overrideWithValue(exitGuard),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          tableEditorDivesProvider.overrideWithValue(
            divesValue ?? AsyncValue.data(dives),
          ),
          if (diveList != null)
            diveListNotifierProvider.overrideWith((ref) => diveList),
          tableEditorDiveEntityProvider.overrideWithValue(
            AsyncValue.data(entity),
          ),
          tableEditorSitesProvider.overrideWithValue(AsyncValue.data(sites)),
          tableEditorSiteEntityProvider.overrideWithValue(
            AsyncValue.data(
              SiteTableEditorEntity(
                repo: SiteRepository(),
                editableLibrarySites: const {},
              ),
            ),
          ),
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
                  for (final field in extraDiveColumns)
                    EntityTableColumnConfig(field: field),
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
                  for (final field in extraSiteColumns)
                    EntityTableColumnConfig(field: field),
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

  testWidgets('rows that failed to load say so rather than spin', (
    tester,
  ) async {
    await pumpPage(
      tester,
      divesValue: AsyncValue.error(StateError('no rows'), StackTrace.empty),
    );

    expect(find.text(l10n.common_error_tryAgain), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
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

    await tester.tap(find.text('#2'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('#2'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.tableEditor_open_saveAndOpen), findsOneWidget);
    await tester.tap(find.text(l10n.tableEditor_open_discardAndOpen));
    await tester.pumpAndSettle();
    expect(pushed, ['/dives/d2']);
  });

  testWidgets('double tap with a cell still open asks first', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.text(vis(15)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), '12');

    await tester.tap(find.text('#2'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('#2'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.tableEditor_open_saveAndOpen), findsOneWidget);
    expect(pushed, isEmpty);
  });

  testWidgets('double tap with an untouched cell open just opens', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(find.text(vis(15)));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('#2'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('#2'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.tableEditor_open_saveAndOpen), findsNothing);
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

  testWidgets('switching tabs with a cell still open asks first', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(find.text(vis(15)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), '12');

    await tester.tap(find.text(l10n.tableEditor_tab_sites));
    await tester.pumpAndSettle();

    expect(find.text(l10n.forms_discard_title), findsOneWidget);
    await tester.tap(find.text(l10n.forms_discard_keepEditing));
    await tester.pumpAndSettle();
    expect(find.text(l10n.tableEditor_draftCount(1)), findsOneWidget);
  });

  testWidgets('switching tabs with an untouched cell open just switches', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(find.text(vis(15)));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text(l10n.tableEditor_tab_sites));
    await tester.pumpAndSettle();

    expect(find.text(l10n.forms_discard_title), findsNothing);
    expect(find.text(vis(15)), findsNothing);
  });

  group('leaving by the sidebar', () {
    void leave(WidgetTester tester) =>
        GoRouter.of(tester.element(find.byType(TableEditorPage))).go('/home');

    testWidgets('with drafts it asks, and keep editing stays', (tester) async {
      await pumpPage(tester);
      await draftVisibility(tester, '12');

      leave(tester);
      await tester.pumpAndSettle();
      expect(find.text(l10n.forms_discard_title), findsOneWidget);

      await tester.tap(find.text(l10n.forms_discard_keepEditing));
      await tester.pumpAndSettle();

      expect(find.byType(TableEditorPage), findsOneWidget);
      expect(find.text(l10n.tableEditor_draftCount(1)), findsOneWidget);
    });

    testWidgets('discarding leaves and the drafts do not come back', (
      tester,
    ) async {
      await pumpPage(tester);
      await draftVisibility(tester, '12');

      leave(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.forms_discard_discard));
      await tester.pumpAndSettle();
      expect(find.text('open editor'), findsOneWidget);

      await tester.tap(find.text('open editor'));
      await tester.pumpAndSettle();
      expect(find.text(vis(15)), findsOneWidget);
      expect(find.text(l10n.tableEditor_draftCount(1)), findsNothing);
    });

    testWidgets('with nothing unsaved it simply leaves', (tester) async {
      await pumpPage(tester);

      leave(tester);
      await tester.pumpAndSettle();

      expect(find.text(l10n.forms_discard_title), findsNothing);
      expect(find.text('open editor'), findsOneWidget);
    });
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

  group('toolbar', () {
    void mockClipboard(String text) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.getData') return {'text': text};
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
    }

    testWidgets('Paste lands a numbered block as drafts and the summary '
        'names the matching', (tester) async {
      mockClipboard('2\t12\n1\t14\n');
      await pumpPage(tester);
      // Select a cell without typing: Escape closes it, the selection stays.
      await tester.tap(find.text(vis(15)));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      await tester.tap(find.byTooltip(l10n.tableEditor_paste));
      await tester.pumpAndSettle();

      expect(find.text(l10n.tableEditor_draftCount(2)), findsOneWidget);
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.tableEditor_saveAll),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.tableEditor_summary_matching_number),
        findsOneWidget,
      );
    });

    testWidgets('Undo after Save all restores the value', (tester) async {
      await pumpPage(tester);
      await draftVisibility(tester, '12');
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.tableEditor_saveAll),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.tableEditor_saveAll).last,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        (await diveRepo.getDivesByIdsWithoutSamples([
          'd1',
        ])).single.visibilityMeters,
        12,
      );

      await tester.tap(find.text(l10n.tableEditor_undo));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        (await diveRepo.getDivesByIdsWithoutSamples([
          'd1',
        ])).single.visibilityMeters,
        15,
      );
      expect(find.text(l10n.tableEditor_undoneAll), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('Clear filters appears with an active dive filter and '
        'resets it', (tester) async {
      await pumpPage(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TableEditorPage)),
      );
      container
          .read(tableEditorDiveFilterProvider.notifier)
          .state = DiveFilterState(
        query: ConditionNode(FieldPath(const ['notes']), QueryOp.isEmpty, null),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.tableEditor_clearFilters), findsOneWidget);

      await tester.tap(find.text(l10n.tableEditor_clearFilters));
      await tester.pumpAndSettle();

      expect(find.text(l10n.tableEditor_clearFilters), findsNothing);
      expect(container.read(tableEditorDiveFilterProvider).query, isNull);
    });

    testWidgets('the Sites tab shows its rows and opens a cell', (
      tester,
    ) async {
      await pumpPage(
        tester,
        sites: const [
          SiteWithDiveCount(
            site: DiveSite(id: 's1', name: 'Reef', country: 'Mexico'),
            diveCount: 3,
          ),
        ],
      );
      await tester.tap(find.text(l10n.tableEditor_tab_sites));
      await tester.pumpAndSettle();
      expect(find.text('Reef'), findsOneWidget);

      await tester.tap(find.text('Reef'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Blue Hole');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text(l10n.tableEditor_draftCount(1)), findsOneWidget);
    });

    Finder saveAllButton() =>
        find.widgetWithText(FilledButton, l10n.tableEditor_saveAll);

    Future<void> selectCell(WidgetTester tester) async {
      await tester.tap(find.text(vis(15)));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
    }

    testWidgets('the columns button opens the picker', (tester) async {
      await pumpPage(tester);

      await tester.tap(
        find.byTooltip(l10n.columnConfig_tooltip_columnSettings),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EntityTableColumnPicker<DiveField>), findsOneWidget);
    });

    testWidgets('Save all takes the cell still being typed in', (tester) async {
      await pumpPage(tester);
      await draftVisibility(tester, '12');
      ProviderScope.containerOf(tester.element(find.byType(TableEditorPage)))
          .read(
            tableEditorDraftsNotifierProvider(TableEditorTab.dives).notifier,
          )
          .setEditing(const CellPosition('d2', 'visibility'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '9');

      await tester.tap(saveAllButton());
      await tester.pumpAndSettle();
      expect(find.text(l10n.tableEditor_summary_changed(2)), findsOneWidget);
      await tester.tap(saveAllButton().last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final saved = await diveRepo.getDivesByIdsWithoutSamples(['d2']);
      expect(saved.single.visibilityMeters, 9);
    });

    testWidgets('Save all is ready while the only edit is still open', (
      tester,
    ) async {
      await pumpPage(tester);
      await tester.tap(find.text(vis(15)));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField), '12');
      await tester.pump();

      await tester.tap(saveAllButton());
      await tester.pumpAndSettle();

      expect(find.text(l10n.tableEditor_summary_changed(1)), findsOneWidget);
    });

    testWidgets('back with a typed cell open asks first and leaves no draft '
        'behind', (tester) async {
      await pumpPage(tester);
      await tester.tap(find.text(vis(15)));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField), '12');

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text(l10n.forms_discard_title), findsOneWidget);
      await tester.tap(find.text(l10n.forms_discard_discard));
      await tester.pumpAndSettle();
      expect(find.text('open editor'), findsOneWidget);

      await tester.tap(find.text('open editor'));
      await tester.pumpAndSettle();
      expect(find.text(vis(15)), findsOneWidget);
      expect(find.text(l10n.tableEditor_draftCount(1)), findsNothing);
    });

    testWidgets('back with an untouched cell open simply leaves', (
      tester,
    ) async {
      await pumpPage(tester);
      await tester.tap(find.text(vis(15)));
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text(l10n.forms_discard_title), findsNothing);
      expect(find.text('open editor'), findsOneWidget);
    });

    testWidgets('Paste is off while the selection is not on the sheet', (
      tester,
    ) async {
      await pumpPage(tester);
      ProviderScope.containerOf(tester.element(find.byType(TableEditorPage)))
          .read(
            tableEditorDraftsNotifierProvider(TableEditorTab.dives).notifier,
          )
          .setSelected(const CellPosition('gone', 'visibility'));
      await tester.pump();

      final paste = find.ancestor(
        of: find.byIcon(Icons.content_paste),
        matching: find.byType(IconButton),
      );
      expect(tester.widget<IconButton>(paste).onPressed, isNull);
    });

    testWidgets('the paste shortcut works with a toggle cell open', (
      tester,
    ) async {
      mockClipboard('2\t12\n');
      await pumpPage(tester, extraDiveColumns: const [DiveField.isFavorite]);
      final notifier = ProviderScope.containerOf(
        tester.element(find.byType(TableEditorPage)),
      ).read(tableEditorDraftsNotifierProvider(TableEditorTab.dives).notifier);
      notifier.setEditing(const CellPosition('d1', 'isFavorite'));
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      expect(
        notifier.draftAt(const CellPosition('d2', 'isFavorite')),
        isNotNull,
      );
    });

    testWidgets('a paste that lands nothing says why', (tester) async {
      mockClipboard('Dive\tVisibility\n99\t12\n');
      await pumpPage(tester);
      await selectCell(tester);

      await tester.tap(find.byTooltip(l10n.tableEditor_paste));
      await tester.pumpAndSettle();

      expect(find.text(l10n.tableEditor_skip_unknownRow('99')), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('a later save does not repeat the last paste', (tester) async {
      mockClipboard('2\t12\n');
      await pumpPage(tester);
      await selectCell(tester);
      await tester.tap(find.byTooltip(l10n.tableEditor_paste));
      await tester.pumpAndSettle();
      await tester.tap(saveAllButton());
      await tester.pumpAndSettle();
      await tester.tap(saveAllButton().last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 6));

      await draftVisibility(tester, '11');
      await tester.tap(saveAllButton());
      await tester.pumpAndSettle();

      expect(find.text(l10n.tableEditor_summary_matching_number), findsNothing);
    });

    testWidgets('a paste whose drafts were all discarded stays out of the '
        'summary', (tester) async {
      mockClipboard('2\t12\n');
      await pumpPage(tester);
      await selectCell(tester);
      await tester.tap(find.byTooltip(l10n.tableEditor_paste));
      await tester.pumpAndSettle();
      ProviderScope.containerOf(tester.element(find.byType(TableEditorPage)))
          .read(
            tableEditorDraftsNotifierProvider(TableEditorTab.dives).notifier,
          )
          .remove('d2', 'visibility');
      await tester.pump();

      await draftVisibility(tester, '11');
      await tester.tap(saveAllButton());
      await tester.pumpAndSettle();

      expect(find.text(l10n.tableEditor_summary_matching_number), findsNothing);
    });

    testWidgets('a save reloads the dive list quietly', (tester) async {
      final list = _DiveList();
      await pumpPage(tester, diveList: list);
      await draftVisibility(tester, '12');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      await tester.tap(saveAllButton());
      await tester.pumpAndSettle();
      await tester.tap(saveAllButton().last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 6));

      expect(list.fullReloads, 0);
      expect(list.quietReloads, 1);
    });

    group('a draft a save left out', () {
      Future<TableDraft?> saveAgainst(
        WidgetTester tester,
        TableEditorSaveService service,
      ) async {
        await pumpPage(tester, saveService: service);
        await draftVisibility(tester, '12');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        await tester.tap(saveAllButton());
        await tester.pumpAndSettle();
        await tester.tap(saveAllButton().last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(seconds: 6));
        return ProviderScope.containerOf(
              tester.element(find.byType(TableEditorPage)),
            )
            .read(tableEditorDraftsNotifierProvider(TableEditorTab.dives))
            .at('d1', 'visibility');
      }

      testWidgets('is flagged when the store says something else', (
        tester,
      ) async {
        final left = await saveAgainst(tester, _StaleSave.to(30.0));

        expect(left?.flag, TableDraftFlag.changedElsewhere);
        expect(left?.original, 30.0);
      });

      testWidgets('goes when the store already says the same', (tester) async {
        final left = await saveAgainst(tester, _StaleSave.toDraftValue());

        expect(left, isNull);
      });
    });

    testWidgets('a cell\'s filter compares what is stored, not what shows', (
      tester,
    ) async {
      await pumpPage(
        tester,
        extraSiteColumns: const [SiteField.notes],
        sites: const [
          SiteWithDiveCount(
            site: DiveSite(id: 's1', name: 'Reef', notes: 'Great **wreck**'),
            diveCount: 3,
          ),
        ],
      );
      await tester.tap(find.text(l10n.tableEditor_tab_sites));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Great wreck'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.tableMode_cell_only('Great wreck')));
      await tester.pumpAndSettle();

      final rule =
          ProviderScope.containerOf(
                tester.element(find.byType(TableEditorPage)),
              ).read(tableEditorSiteQueryProvider)!
              as ConditionNode;
      expect(rule.value, const StringValue('Great **wreck**'));
    });

    testWidgets('a cell edited while a save runs keeps its newer draft, and '
        'Save all waits', (tester) async {
      final held = _HeldSave();
      await pumpPage(tester, saveService: held);
      await draftVisibility(tester, '12');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      await tester.tap(saveAllButton());
      await tester.pumpAndSettle();
      await tester.tap(saveAllButton().last);
      await tester.pumpAndSettle();

      expect(tester.widget<FilledButton>(saveAllButton()).onPressed, isNull);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TableEditorPage)),
      );
      final notifier = container.read(
        tableEditorDraftsNotifierProvider(TableEditorTab.dives).notifier,
      );
      const newer = TableDraft(
        entityId: 'd1',
        fieldName: 'visibility',
        original: 15.0,
        value: 11.0,
      );
      notifier.put(newer);

      held.release.complete();
      await tester.pump();
      await tester.pump();

      expect(
        container
            .read(tableEditorDraftsNotifierProvider(TableEditorTab.dives))
            .at('d1', 'visibility'),
        newer,
      );
      await tester.pump(const Duration(seconds: 6));
    });

    group('while a save writes', () {
      Future<_HeldSave> startSave(WidgetTester tester) async {
        final held = _HeldSave();
        await pumpPage(tester, saveService: held);
        await draftVisibility(tester, '12');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        await tester.tap(saveAllButton());
        await tester.pumpAndSettle();
        await tester.tap(saveAllButton().last);
        await tester.pumpAndSettle();
        return held;
      }

      testWidgets('leaving waits for it and has nothing to ask', (
        tester,
      ) async {
        final held = await startSave(tester);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(TableEditorPage)),
        );

        bool? left;
        final leaving = container.read(appExitGuardProvider).mayLeave();
        unawaited(leaving.then((v) => left = v));
        await tester.pumpAndSettle();

        expect(find.text(l10n.forms_discard_discard), findsNothing);
        expect(left, isNull);

        held.release.complete();
        await tester.pump();
        await tester.pump();

        expect(left, isTrue);
        expect(find.text(l10n.forms_discard_discard), findsNothing);
        await tester.pump(const Duration(seconds: 6));
      });

      testWidgets('switching tabs waits for it and has nothing to ask', (
        tester,
      ) async {
        final held = await startSave(tester);

        await tester.tap(find.text(l10n.tableEditor_tab_sites));
        await tester.pumpAndSettle();

        expect(find.text(l10n.forms_discard_discard), findsNothing);

        held.release.complete();
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();

        expect(find.text(l10n.forms_discard_discard), findsNothing);
        expect(find.text(vis(12)), findsNothing);
        expect(find.text(vis(15)), findsNothing);
      });

      testWidgets('a double tap waits for it and then just opens', (
        tester,
      ) async {
        final held = await startSave(tester);

        await tester.tap(find.text('#2'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('#2'));
        await tester.pumpAndSettle();

        expect(find.text(l10n.tableEditor_open_discardAndOpen), findsNothing);
        expect(pushed, isEmpty);

        held.release.complete();
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(seconds: 6));

        expect(pushed, ['/dives/d2']);
      });
    });

    testWidgets('Undo leaves what changed since the save and says so', (
      tester,
    ) async {
      await pumpPage(tester);
      await draftVisibility(tester, '12');
      await tester.tap(saveAllButton());
      await tester.pumpAndSettle();
      await tester.tap(saveAllButton().last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final moved = (await diveRepo.getDivesByIdsWithoutSamples(['d1'])).single;
      await diveRepo.updateDive(moved.copyWith(visibilityMeters: 7));

      await tester.tap(find.text(l10n.tableEditor_undo));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text(l10n.tableEditor_changeLog), findsOneWidget);
      expect(
        (await diveRepo.getDivesByIdsWithoutSamples([
          'd1',
        ])).single.visibilityMeters,
        7,
      );
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('a library site the profile may not edit shows a lock', (
      tester,
    ) async {
      await pumpPage(
        tester,
        sites: const [
          SiteWithDiveCount(
            site: DiveSite(id: 's1', name: 'Reef', sharedLibraryId: 'lib'),
            diveCount: 0,
          ),
          SiteWithDiveCount(
            site: DiveSite(id: 's2', name: 'Wreck'),
            diveCount: 0,
          ),
        ],
      );
      await tester.tap(find.text(l10n.tableEditor_tab_sites));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });
  });

  group('quitting the app', () {
    late int retried;
    late int closed;
    late AppExitGuard guard;

    setUp(() {
      retried = 0;
      closed = 0;
      guard = AppExitGuard(
        retryExit: () async => retried++,
        preventWindowClose: (_) async {},
      );
    });

    Future<AppExitResponse> close() async {
      closed++;
      return AppExitResponse.exit;
    }

    testWidgets('with drafts it is cancelled and asks, and keep editing '
        'stays', (tester) async {
      await pumpPage(tester, exitGuard: guard);
      await draftVisibility(tester, '12');

      expect(await guard.answer(close), AppExitResponse.cancel);
      await tester.pumpAndSettle();
      expect(find.text(l10n.forms_discard_title), findsOneWidget);

      await tester.tap(find.text(l10n.forms_discard_keepEditing));
      await tester.pumpAndSettle();

      expect(retried, 0);
      expect(closed, 0);
      expect(find.text(l10n.tableEditor_draftCount(1)), findsOneWidget);
    });

    testWidgets('discarding clears the drafts and quits', (tester) async {
      await pumpPage(tester, exitGuard: guard);
      await draftVisibility(tester, '12');

      await guard.answer(close);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.forms_discard_discard));
      await tester.pumpAndSettle();

      expect(retried, 1);
      expect(find.text(l10n.tableEditor_draftCount(1)), findsNothing);
      expect(await guard.answer(close), AppExitResponse.exit);
      expect(closed, 1);
    });

    testWidgets('a cell still being typed in counts as unsaved', (
      tester,
    ) async {
      await pumpPage(tester, exitGuard: guard);
      await tester.tap(find.text(vis(15)));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField), '12');

      expect(await guard.answer(close), AppExitResponse.cancel);
      await tester.pumpAndSettle();

      expect(find.text(l10n.forms_discard_title), findsOneWidget);
    });

    testWidgets('an untouched open cell quits without asking', (tester) async {
      await pumpPage(tester, exitGuard: guard);
      await tester.tap(find.text(vis(15)));
      await tester.pump(const Duration(milliseconds: 400));

      await guard.answer(close);
      await tester.pumpAndSettle();

      expect(find.text(l10n.forms_discard_title), findsNothing);
      expect(retried, 1);
    });

    testWidgets('a quit during the back prompt adds no second prompt', (
      tester,
    ) async {
      await pumpPage(tester, exitGuard: guard);
      await draftVisibility(tester, '12');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(await guard.answer(close), AppExitResponse.cancel);
      await tester.pumpAndSettle();

      expect(find.text(l10n.forms_discard_title), findsOneWidget);
    });

    testWidgets('with no drafts nothing stands in the way', (tester) async {
      await pumpPage(tester, exitGuard: guard);

      expect(await guard.answer(close), AppExitResponse.exit);
      expect(closed, 1);
    });

    testWidgets('the guard goes with the page', (tester) async {
      await pumpPage(tester, exitGuard: guard);
      await draftVisibility(tester, '12');

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.forms_discard_discard));
      await tester.pumpAndSettle();

      expect(await guard.answer(close), AppExitResponse.exit);
    });
  });
}
