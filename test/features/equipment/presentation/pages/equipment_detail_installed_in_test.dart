import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/condition_trend.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_exposure_totals.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_detail_page.dart';
import 'package:submersion/features/equipment/presentation/providers/condition_trend_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_condition_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_exposure_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The history section needs a notifier that never touches the database.
class _MockServiceRecordNotifier
    extends StateNotifier<AsyncValue<List<ServiceRecord>>>
    implements ServiceRecordNotifier {
  _MockServiceRecordNotifier() : super(const AsyncValue.data([]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  // Dates format through the process-global Intl.defaultLocale, which
  // MaterialApp.locale does not set.
  late String? savedIntlLocale;
  setUp(() {
    savedIntlLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });
  tearDown(() => Intl.defaultLocale = savedIntlLocale);

  const cellId = 'cell-2';
  const hostId = 'ccr';

  // Ten local calendar days ago, stored the way the date picker stores it.
  final today = DateTime.now();
  final installed = DateTime(today.year, today.month, today.day - 10);

  EquipmentItem cell({
    String? parentId = hostId,
    EquipmentStatus status = EquipmentStatus.active,
    bool isActive = true,
  }) => EquipmentItem(
    id: cellId,
    name: 'Cell 2',
    type: EquipmentType.o2Cell,
    status: status,
    isActive: isActive,
    parentEquipmentId: parentId,
    attributes: [
      EquipmentAttribute.curated(
        equipmentId: cellId,
        key: EquipmentAttrKeys.installedDate,
        valueNum: installed.millisecondsSinceEpoch.toDouble(),
      ),
    ],
  );

  const host = EquipmentItem(
    id: hostId,
    name: 'JJ-CCR',
    type: EquipmentType.rebreather,
  );

  /// Pumps the child's page. [parent] is what the lookup of [hostId]
  /// resolves to; leave [overrideParent] false to skip that override
  /// entirely (a child with no parent id never asks).
  Future<void> pump(
    WidgetTester tester, {
    required EquipmentItem child,
    EquipmentItem? parent,
    bool overrideParent = true,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 2400);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      initialLocation: '/equipment/$cellId',
      routes: [
        GoRoute(
          path: '/equipment/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return id == cellId
                ? const EquipmentDetailPage(equipmentId: cellId)
                : Scaffold(body: Text('OPENED:$id'));
          },
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          equipmentItemProvider(cellId).overrideWith((ref) async => child),
          if (overrideParent)
            equipmentItemProvider(hostId).overrideWith((ref) async => parent),
          equipmentDiveCountProvider(cellId).overrideWith((ref) async => 0),
          equipmentTripCountProvider(cellId).overrideWith((ref) async => 0),
          serviceRecordNotifierProvider(
            cellId,
          ).overrideWith((ref) => _MockServiceRecordNotifier()),
          serviceClockStatusesProvider(
            cellId,
          ).overrideWith((ref) async => const []),
          equipmentComponentsProvider(
            cellId,
          ).overrideWith((ref) async => const []),
          equipmentExposureTotalsProvider(
            cellId,
          ).overrideWith((ref) async => EquipmentExposureTotals.empty),
          equipmentConditionProvider(
            cellId,
          ).overrideWith((ref) async => const []),
          conditionTrendProvider((
            equipmentId: cellId,
            kind: null,
          )).overrideWith((ref) async => null),
          conditionTrendProvider((
            equipmentId: cellId,
            kind: ConditionTrendKind.scrubberMinutes,
          )).overrideWith((ref) async => null),
          childEquipmentProvider(cellId).overrideWith((ref) async => const []),
          observationsForEquipmentProvider(
            cellId,
          ).overrideWith((ref) async => const []),
          equipmentWorstClockProvider.overrideWith((ref) async => {}),
          equipmentRollupClockProvider.overrideWith((ref) async => {}),
        ].cast(),
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // The plain spec row for the install date, whose label is exactly this.
  final plainInstalledRow = find.text('Installed');

  testWidgets('a fitted child links to its host with the install age', (
    tester,
  ) async {
    await pump(tester, child: cell(), parent: host);

    expect(find.text('Installed in'), findsOneWidget);
    expect(find.text('JJ-CCR'), findsOneWidget);
    expect(find.textContaining('10 days ago'), findsOneWidget);
    // The age line carries the date, so the plain row would repeat it.
    expect(plainInstalledRow, findsNothing);
  });

  testWidgets('tapping the host opens its detail page', (tester) async {
    await pump(tester, child: cell(), parent: host);

    await tester.tap(find.text('JJ-CCR'));
    await tester.pumpAndSettle();

    expect(find.text('OPENED:$hostId'), findsOneWidget);
  });

  testWidgets('an item with no parent shows no link', (tester) async {
    await pump(tester, child: cell(parentId: null), overrideParent: false);

    expect(find.text('Installed in'), findsNothing);
    expect(find.text('Was installed in'), findsNothing);
    expect(plainInstalledRow, findsOneWidget);
  });

  testWidgets('a parent id naming no item renders nothing and keeps the date', (
    tester,
  ) async {
    await pump(tester, child: cell(), parent: null);

    expect(tester.takeException(), isNull);
    expect(find.text('Installed in'), findsNothing);
    expect(find.textContaining('10 days ago'), findsNothing);
    expect(plainInstalledRow, findsOneWidget);
  });

  testWidgets('a retired host is named with its status', (tester) async {
    await pump(
      tester,
      child: cell(),
      parent: host.copyWith(status: EquipmentStatus.retired, isActive: false),
    );

    expect(find.text('Installed in'), findsOneWidget);
    expect(find.text('JJ-CCR (Retired)'), findsOneWidget);
  });

  testWidgets('a sold host is named with its own status', (tester) async {
    await pump(
      tester,
      child: cell(),
      parent: host.copyWith(status: EquipmentStatus.sold),
    );

    expect(find.text('JJ-CCR (Sold)'), findsOneWidget);
  });

  testWidgets('a legacy inactive host under a live status reads as retired', (
    tester,
  ) async {
    // Older rows can be deactivated with the status left as it was.
    await pump(tester, child: cell(), parent: host.copyWith(isActive: false));

    expect(find.text('JJ-CCR (Retired)'), findsOneWidget);
  });

  testWidgets('a retired child says it was installed, without an age', (
    tester,
  ) async {
    await pump(
      tester,
      child: cell(status: EquipmentStatus.retired, isActive: false),
      parent: host,
    );

    expect(find.text('Was installed in'), findsOneWidget);
    expect(find.text('Installed in'), findsNothing);
    expect(find.text('JJ-CCR'), findsOneWidget);
    expect(find.textContaining('10 days ago'), findsNothing);
    expect(plainInstalledRow, findsOneWidget);
  });

  // A screen reader must reach the row as its own node reading exactly its
  // visible text. Without a boundary the Details card merges every row into
  // one node, so the link was announced run together with Status, Dives and
  // Trips and could not be activated on its own. Anchored patterns, because
  // an unanchored one also matches that merged card node.
  final fittedNode = RegExp(
    r'^Installed in\nJJ-CCR\nInstalled [^\n]+, 10 days ago$',
  );
  final retiredNode = RegExp(r'^Was installed in\nJJ-CCR$');
  // Any node carrying both the card's Status row and the host's name.
  final mergedIntoCard = RegExp(r'Status[\s\S]*JJ-CCR');

  testWidgets('a fitted child reads the link as its own node', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, child: cell(), parent: host);

    expect(find.semantics.byLabel(fittedNode).evaluate(), hasLength(1));
    expect(find.semantics.byLabel(mergedIntoCard).evaluate(), isEmpty);
    semantics.dispose();
  });

  testWidgets('a retired child reads the past-tense link as its own node', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(
      tester,
      child: cell(status: EquipmentStatus.retired, isActive: false),
      parent: host,
    );

    expect(find.semantics.byLabel(retiredNode).evaluate(), hasLength(1));
    expect(find.semantics.byLabel(mergedIntoCard).evaluate(), isEmpty);
    semantics.dispose();
  });

  testWidgets('a screen reader can open the host from the row', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, child: cell(), parent: host);

    tester.semantics.performAction(
      find.semantics.byLabel(fittedNode),
      SemanticsAction.tap,
    );
    await tester.pumpAndSettle();

    expect(find.text('OPENED:$hostId'), findsOneWidget);
    semantics.dispose();
  });
}
