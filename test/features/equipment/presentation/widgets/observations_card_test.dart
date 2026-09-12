import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_observation_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/observations_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  final reg = EquipmentItem(
    id: 'reg',
    name: 'Reg',
    type: EquipmentType.regulator,
    createdAt: DateTime.utc(2026),
  );

  late _FakeRepo repo;
  late int detailReads;

  setUp(() {
    repo = _FakeRepo();
    detailReads = 0;
  });

  Future<void> pump(
    WidgetTester tester,
    List<EquipmentObservation> observations,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          equipmentObservationRepositoryProvider.overrideWithValue(repo),
          observationsForEquipmentProvider(
            'reg',
          ).overrideWith((ref) async => observations),
          // One batch for the whole card. d-unresolved is absent: a dive
          // that has not resolved, whose row must not show its id.
          observationDiveNumbersProvider(
            'reg',
          ).overrideWith((ref) async => {'d1': 42}),
          // Counts any per-row detail read, which the card must not make.
          diveProvider.overrideWith((ref, id) async {
            detailReads++;
            return Dive(id: id, dateTime: DateTime.utc(2026));
          }),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ObservationsCard(equipment: reg),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty state names the section', (tester) async {
    await pump(tester, const []);
    expect(find.text('Check-ins'), findsOneWidget);
    expect(find.text('No check-ins recorded for this item.'), findsOneWidget);
  });

  testWidgets('rows show tags, the dive number and bench', (tester) async {
    await pump(tester, [
      EquipmentObservation(
        id: 'o1',
        equipmentId: 'reg',
        diveId: 'd1',
        observedAt: DateTime.utc(2026, 3, 1),
        status: ObservationStatus.issue,
        issueTags: const [ObservationTag.freeFlow, ObservationTag.leak],
        note: 'Cold water',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
      EquipmentObservation(
        id: 'o2',
        equipmentId: 'reg',
        observedAt: DateTime.utc(2026, 2, 1),
        status: ObservationStatus.ok,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    ]);
    expect(find.text('Free flow, Leak'), findsOneWidget);
    expect(find.textContaining('Dive #42'), findsOneWidget);
    expect(find.textContaining('Bench'), findsOneWidget);
    expect(find.textContaining('Cold water'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });

  EquipmentObservation observation({
    String id = 'o1',
    String? diveId,
    ObservationStatus status = ObservationStatus.issue,
    List<ObservationTag> tags = const [ObservationTag.freeFlow],
    String note = '',
  }) => EquipmentObservation(
    id: id,
    equipmentId: 'reg',
    diveId: diveId,
    observedAt: DateTime.utc(2026, 3, 1),
    status: status,
    issueTags: tags,
    note: note,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  testWidgets('an issue whose tags were all dropped still has a title', (
    tester,
  ) async {
    // A newer build's tag names are dropped on read, which can leave an
    // issue with no tags at all. The row falls back to the status.
    await pump(tester, [observation(tags: const [])]);
    expect(find.text('Issue'), findsOneWidget);
  });

  testWidgets('a multi-line note shows on one line', (tester) async {
    await pump(tester, [observation(note: 'Cold water\nat depth\n\nagain')]);
    expect(find.text('Cold water at depth again'), findsOneWidget);
  });

  testWidgets('a dive that has not resolved shows a label, not its id', (
    tester,
  ) async {
    await pump(tester, [observation(diveId: 'd-unresolved')]);
    expect(find.textContaining('d-unresolved'), findsNothing);
    expect(find.textContaining('Dive'), findsOneWidget);
  });

  testWidgets('rows take dive numbers from one batch, not a detail read', (
    tester,
  ) async {
    // The dive detail provider hydrates tanks, profile and pressures; an
    // item with check-ins on many dives must not load each one for a
    // number.
    await pump(tester, [
      observation(id: 'o1', diveId: 'd1'),
      observation(id: 'o2', diveId: 'd2'),
      observation(id: 'o3', diveId: 'd3'),
    ]);
    expect(detailReads, 0);
    expect(find.textContaining('Dive #42'), findsOneWidget);
  });

  testWidgets('the edit button opens that check-in in the editor', (
    tester,
  ) async {
    await pump(tester, [observation(diveId: 'd1', note: 'Cold water')]);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Cold water'), findsOneWidget);
  });

  testWidgets('the delete button asks first and then deletes that row', (
    tester,
  ) async {
    await pump(tester, [observation(diveId: 'd1')]);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete this check-in?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(repo.deleted, ['o1']);
  });

  testWidgets('cancelling the delete keeps the row', (tester) async {
    await pump(tester, [observation(diveId: 'd1')]);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.deleted, isEmpty);
  });
}

class _FakeRepo implements EquipmentObservationRepository {
  final deleted = <String>[];

  @override
  Future<void> delete(String id) async => deleted.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
