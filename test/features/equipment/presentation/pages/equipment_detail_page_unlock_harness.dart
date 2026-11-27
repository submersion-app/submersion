import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/services/gear_item_edit_save_service.dart';
import 'package:submersion/features/equipment/domain/entities/condition_trend.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_exposure_totals.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_new_sitting.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_detail_page.dart';
import 'package:submersion/features/equipment/presentation/providers/condition_trend_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_condition_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_exposure_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/pump_until.dart';
import '../../../../helpers/test_app.dart';

/// The item the page shows, as stored: a regulator owned by no profile
/// (every profile counts as its owner), with no notes.
final apex = EquipmentItem(
  id: 'g1',
  name: 'Apex',
  type: EquipmentType.regulator,
  brand: 'Apex',
  serialNumber: 'A1',
  createdAt: DateTime(2026),
);

/// Records each save the page asks for, stores its result where the page
/// reads the item from, and can fail.
class FakeGearItemSave implements GearItemEditSaveService {
  FakeGearItemSave(this.stored);

  final StateController<EquipmentItem?> stored;

  final calls = <({EquipmentItem after, Set<String> cards})>[];
  bool fail = false;

  /// Whether to run the held writes a save is given, as the real one does
  /// inside its transaction.
  bool runHeld = true;

  /// Holds the write until completed.
  Completer<void>? gate;

  @override
  Future<({EquipmentItem before, EquipmentItem after})?> save({
    required String equipmentId,
    required EquipmentItem Function(EquipmentItem stored) apply,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
    bool alsoWriteIsAChange = false,
  }) async {
    if (fail) throw StateError('the save failed');
    await gate?.future;
    final before = stored.state!;
    final after = apply(before);
    calls.add((after: after, cards: changedCardIds.toSet()));
    if (runHeld) await alsoWrite?.call();
    stored.state = after;
    return (before: before, after: after);
  }

  /// Each new item the page asked to create, failed ones included.
  final creates = <({EquipmentItem item, Set<String> cards})>[];

  @override
  Future<EquipmentItem> create({
    required EquipmentItem item,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
  }) async {
    creates.add((item: item, cards: changedCardIds.toSet()));
    if (fail) throw StateError('the create failed');
    return item;
  }
}

class GearPageHarness {
  GearPageHarness(this.save, this.stored, this.serviceRecords);

  final FakeGearItemSave save;
  final StateController<EquipmentItem?> stored;

  /// Counts the service record reloads, which reschedule the reminders.
  final CountingServiceRecords serviceRecords;
}

final _storedProvider = StateProvider<EquipmentItem?>((ref) => apex);

/// No service records, counting each reload (which reschedules the item's
/// service reminders).
class CountingServiceRecords
    extends StateNotifier<AsyncValue<List<ServiceRecord>>>
    implements ServiceRecordNotifier {
  CountingServiceRecords() : super(const AsyncValue.data([]));

  int refreshes = 0;

  @override
  Future<void> refresh() async => refreshes++;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Pumps the gear item page, at phone width, or as the list's pane when
/// [embedded]. The page's other reads answer with nothing.
Future<GearPageHarness> pumpGearPage(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  EquipmentItem? item,
  bool openUnlocked = false,
  bool embedded = false,
  Size size = const Size(600, 2400),
  VoidCallback? onSittingEnded,
  VoidCallback? onDeleted,
  List<EquipmentItem> children = const [],
  List<EquipmentFinding> findings = const [],
  List<Object> extraOverrides = const [],
}) async {
  final shown = item ?? apex;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides();
  late GearPageHarness harness;
  final serviceRecords = CountingServiceRecords();
  final page = EquipmentDetailPage(
    equipmentId: shown.id,
    openUnlocked: openUnlocked,
    embedded: embedded,
    onSittingEnded: onSittingEnded,
    onDeleted: onDeleted,
  );
  await tester.pumpWidget(
    testApp(
      overrides: [
        ...overrides,
        validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
        equipmentListViewModeProvider.overrideWith((ref) => ListViewMode.table),
        _storedProvider.overrideWith((ref) => shown),
        equipmentItemProvider(
          shown.id,
        ).overrideWith((ref) async => ref.watch(_storedProvider)),
        equipmentDiveCountProvider(shown.id).overrideWith((ref) async => 0),
        equipmentTripCountProvider(shown.id).overrideWith((ref) async => 0),
        equipmentComponentsProvider(
          shown.id,
        ).overrideWith((ref) async => const []),
        equipmentPartOfProvider(shown.id).overrideWith((ref) async => const []),
        equipmentExposureTotalsProvider(
          shown.id,
        ).overrideWith((ref) async => EquipmentExposureTotals.empty),
        equipmentConditionProvider(
          shown.id,
        ).overrideWith((ref) async => findings),
        conditionTrendProvider((
          equipmentId: shown.id,
          kind: null,
        )).overrideWith((ref) async => null),
        conditionTrendProvider((
          equipmentId: shown.id,
          kind: ConditionTrendKind.scrubberMinutes,
        )).overrideWith((ref) async => null),
        childEquipmentProvider(shown.id).overrideWith((ref) async => children),
        observationsForEquipmentProvider(
          shown.id,
        ).overrideWith((ref) async => const []),
        equipmentWorstClockProvider.overrideWith((ref) async => {}),
        serviceRecordNotifierProvider(
          shown.id,
        ).overrideWith((ref) => serviceRecords),
        gearItemEditSaveServiceProvider.overrideWith((ref) {
          final save = FakeGearItemSave(ref.watch(_storedProvider.notifier));
          harness = GearPageHarness(
            save,
            ref.watch(_storedProvider.notifier),
            serviceRecords,
          );
          return save;
        }),
        ...extraOverrides,
      ],
      child: Theme(
        data: AppThemeRegistry.resolveTheme(
          AppThemeRegistry.presets.first,
          brightness,
        ),
        child: embedded ? Scaffold(body: page) : page,
      ),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(EquipmentDetailPage)),
  );
  container.read(gearItemEditSaveServiceProvider);
  return harness;
}

/// What a test of a new gear item's page pumped: the fake save, the router
/// it is pushed in, and how the page ended.
class NewGearItemHarness {
  late FakeGearItemSave save;
  late GoRouter router;
  Object? popped;
  bool poppedAtAll = false;
  final createdIds = <String>[];
}

/// Pumps a new gear item's page (issue #4527, phase 3, plan 11) with
/// [request], pushed over a launcher at `/equipment/new` in a router whose
/// `/equipment/:id` shows the item's id; or the pane's ([embedded]). Needs
/// the test database: the cards read nothing for an id not stored, and a
/// clone reads its source there.
Future<NewGearItemHarness> pumpNewGearItemPage(
  WidgetTester tester, {
  NewGearItemRequest request = const NewGearItemRequest(),
  bool embedded = false,
  Size size = const Size(700, 1600),
  List<Object> extraOverrides = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides();
  final harness = NewGearItemHarness();
  harness.router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: embedded
              ? EquipmentDetailPage.newItem(
                  request: request,
                  embedded: true,
                  onCreated: harness.createdIds.add,
                )
              : TextButton(
                  onPressed: () async {
                    final result = await context.push<Object?>(
                      '/equipment/new',
                    );
                    harness
                      ..poppedAtAll = true
                      ..popped = result;
                  },
                  child: const Text('open'),
                ),
        ),
      ),
      GoRoute(
        path: '/equipment/new',
        builder: (context, _) => EquipmentDetailPage.newItem(request: request),
      ),
      GoRoute(
        path: '/equipment/:id',
        builder: (_, state) =>
            Scaffold(body: Text('ITEM ${state.pathParameters['id']}')),
      ),
    ],
  );
  addTearDown(harness.router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
        defaultCurrencyProvider.overrideWithValue('EUR'),
        gearItemEditSaveServiceProvider.overrideWith(
          (ref) => harness.save = FakeGearItemSave(
            ref.watch(_storedProvider.notifier),
          ),
        ),
        ...extraOverrides,
      ].cast(),
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: harness.router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (!embedded) {
    await tester.tap(find.text('open'));
    await tester.pump();
  }
  // A clone's seed reads its source from the database, which answers only
  // outside the test's fake clock.
  await pumpUntilRealAsync(
    tester,
    () =>
        find.byType(EquipmentDetailPage).evaluate().isNotEmpty &&
        find.byType(CircularProgressIndicator).evaluate().isEmpty,
    reason: "the new item's page to open or say why not",
  );
  await tester.pumpAndSettle();
  final page = find.byType(EquipmentDetailPage);
  if (page.evaluate().isNotEmpty) {
    ProviderScope.containerOf(
      tester.element(page),
    ).read(gearItemEditSaveServiceProvider);
  }
  return harness;
}
