import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/services/twin_fill_service.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/log_fill_sheet.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_fill_history_card.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

CylinderFill fill(
  String id, {
  String? together,
  FillSource source = FillSource.manual,
  String? signedRecord,
  String equipmentId = 'eq-1',
}) => CylinderFill(
  id: id,
  passportId: 'pp-$equipmentId',
  equipmentId: equipmentId,
  filledAt: DateTime(2026, 11, 2),
  o2Percent: 32,
  pressureBar: 220,
  source: source,
  signedRecord: signedRecord,
  filledTogetherId: together,
  createdAt: DateTime(2026, 11, 2),
  updatedAt: DateTime(2026, 11, 2),
);

class _Fills extends CylinderFillRepository {
  _Fills(this.tied, {this.deleteError});

  final Map<String, CylinderFill> tied;
  final Object? deleteError;
  final deleted = <String>[];
  var tiedFillReads = 0;
  var tiedFillsReads = 0;

  @override
  Future<CylinderFill?> tiedFillOf(CylinderFill fill) async => tied[fill.id];

  @override
  Future<CylinderFill?> tiedFill({
    required String id,
    required String together,
  }) async {
    tiedFillReads++;
    return tied[id];
  }

  @override
  Future<Map<String, CylinderFill>> tiedFillsOf(
    Iterable<CylinderFill> fills,
  ) async {
    tiedFillsReads++;
    return {for (final f in fills) f.id: ?tied[f.id]};
  }

  @override
  Future<void> delete(String id) async {
    if (deleteError case final error?) throw error;
    deleted.add(id);
  }

  @override
  Future<List<String>> recentStationNames({int limit = 8}) async => const [];

  @override
  Future<List<String>> recentAnalyzers({int limit = 8}) async => const [];
}

class _Twin extends TwinFillService {
  _Twin({this.deleteError});

  final Object? deleteError;
  final deletes = <({String id, bool tiedToo})>[];

  @override
  Future<void> delete(CylinderFill fill, {required bool tiedToo}) async {
    if (deleteError case final error?) throw error;
    deletes.add((id: fill.id, tiedToo: tiedToo));
  }
}

void main() {
  late String? savedIntlLocale;
  setUp(() async {
    savedIntlLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
    await setUpTestDatabase();
  });
  tearDown(() async {
    Intl.defaultLocale = savedIntlLocale;
    await tearDownTestDatabase();
  });

  Future<AppLocalizations> pump(
    WidgetTester tester, {
    required List<CylinderFill> fills,
    Map<String, CylinderFill> tied = const {},
    Set<String> tripCopies = const {},
    _Fills? repository,
    _Twin? twin,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 1400);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          fillsForEquipmentProvider('eq-1').overrideWith((ref) async => fills),
          serviceClockStatusesProvider('eq-1').overrideWith((ref) async => []),
          serviceRecordsForEquipmentProvider(
            'eq-1',
          ).overrideWith((ref) async => []),
          tripCopyFillIdsProvider(
            'eq-1',
          ).overrideWith((ref) async => tripCopies),
          cylinderFillRepositoryProvider.overrideWithValue(
            repository ?? _Fills(tied),
          ),
          twinFillServiceProvider.overrideWithValue(twin ?? _Twin()),
          equipmentItemProvider('eq-2').overrideWith(
            (ref) async => const EquipmentItem(
              id: 'eq-2',
              name: 'Double 12 B',
              type: EquipmentType.tank,
            ),
          ),
        ],
        child: const SingleChildScrollView(
          child: PassportFillHistoryCard(equipmentId: 'eq-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(
      tester.element(find.byType(PassportFillHistoryCard)),
    );
  }

  final partnerFill = fill('f2', together: 'g', equipmentId: 'eq-2');

  testWidgets('a tied fill names the cylinder it was filled with', (
    tester,
  ) async {
    final l10n = await pump(
      tester,
      fills: [fill('f1', together: 'g')],
      tied: {'f1': partnerFill},
    );
    expect(
      find.textContaining(l10n.passport_history_filledWith('Double 12 B')),
      findsOneWidget,
    );
  });

  testWidgets('one read names the partners of every tied fill', (tester) async {
    final repository = _Fills({
      for (final id in ['f1', 'f3', 'f4'])
        id: fill('$id-b', together: id, equipmentId: 'eq-2'),
    });
    final l10n = await pump(
      tester,
      fills: [
        for (final id in ['f1', 'f3', 'f4']) fill(id, together: id),
      ],
      repository: repository,
    );
    expect(
      find.textContaining(l10n.passport_history_filledWith('Double 12 B')),
      findsNWidgets(3),
    );
    expect(repository.tiedFillReads, 0);
    expect(repository.tiedFillsReads, 1);
  });

  testWidgets('a manual fill opens the sheet in edit mode', (tester) async {
    final l10n = await pump(tester, fills: [fill('f1')]);
    await tester.tap(find.byTooltip(l10n.passport_history_edit));
    await tester.pumpAndSettle();
    expect(find.byType(LogFillSheet), findsOneWidget);
    expect(find.text(l10n.passport_logFill_editTitle), findsOneWidget);
  });

  testWidgets('tapping a manual fill opens it for editing', (tester) async {
    final l10n = await pump(tester, fills: [fill('f1')]);
    await tester.tap(find.text('EAN32'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.passport_logFill_editTitle), findsOneWidget);
  });

  testWidgets('signed, tagged and trip-copied fills have no edit action', (
    tester,
  ) async {
    final l10n = await pump(
      tester,
      fills: [
        fill('signed', signedRecord: 'jws'),
        fill('tagged', source: FillSource.nfc),
        fill('trip'),
      ],
      tripCopies: {'trip'},
    );
    expect(find.byTooltip(l10n.passport_history_edit), findsNothing);
  });

  for (final (label, both) in [('both', true), ('only this one', false)]) {
    testWidgets('a tied delete asks, and $label reaches the service', (
      tester,
    ) async {
      final twin = _Twin();
      final l10n = await pump(
        tester,
        fills: [fill('f1', together: 'g')],
        tied: {'f1': partnerFill},
        twin: twin,
      );
      await tester.tap(find.byTooltip(l10n.passport_history_delete));
      await tester.pumpAndSettle();
      expect(find.text(l10n.passport_history_deleteTiedBody), findsOneWidget);
      await tester.tap(
        find.text(
          both
              ? l10n.passport_history_deleteBoth
              : l10n.passport_logFill_onlyThisOne,
        ),
      );
      await tester.pumpAndSettle();
      expect(twin.deletes.single.tiedToo, both);
      expect(twin.deletes.single.id, 'f1');
    });
  }

  testWidgets('a failed delete says so', (tester) async {
    final l10n = await pump(
      tester,
      fills: [fill('f1')],
      repository: _Fills(const {}, deleteError: StateError('locked')),
    );
    await tester.tap(find.byTooltip(l10n.passport_history_delete));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, l10n.passport_history_delete),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(l10n.passport_history_deleteFailed), findsOneWidget);
  });

  testWidgets('a failed delete of a tied fill says so', (tester) async {
    final l10n = await pump(
      tester,
      fills: [fill('f1', together: 'g')],
      tied: {'f1': partnerFill},
      twin: _Twin(deleteError: StateError('locked')),
    );
    await tester.tap(find.byTooltip(l10n.passport_history_delete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.passport_history_deleteBoth));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(l10n.passport_history_deleteFailed), findsOneWidget);
  });

  testWidgets('a tied fill whose other row is gone deletes as before', (
    tester,
  ) async {
    final repository = _Fills(const {});
    final l10n = await pump(
      tester,
      fills: [fill('f1', together: 'g')],
      repository: repository,
    );
    await tester.tap(find.byTooltip(l10n.passport_history_delete));
    await tester.pumpAndSettle();
    expect(find.text(l10n.passport_history_deleteConfirm), findsOneWidget);
    await tester.tap(
      find.widgetWithText(FilledButton, l10n.passport_history_delete),
    );
    await tester.pumpAndSettle();
    expect(repository.deleted, ['f1']);
  });
}
