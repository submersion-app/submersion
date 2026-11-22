import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_fills_sitting.dart';
import 'package:submersion/features/equipment/data/services/gear_item_edit_save_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_card_ids.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_cards.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_service_sitting.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_sitting_host.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_host.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';
import '../pages/equipment_detail_page_unlock_harness.dart';

/// A page of a gear item other than its own: what a passport is.
class _OtherItemPage extends ConsumerStatefulWidget {
  const _OtherItemPage();

  @override
  ConsumerState<_OtherItemPage> createState() => _OtherItemPageState();
}

class _OtherItemPageState extends ConsumerState<_OtherItemPage>
    with
        RecordEditHost<_OtherItemPage, EquipmentItem>,
        GearItemSittingHost<_OtherItemPage> {
  final saved = <EquipmentItem?>[];

  @override
  String get hostRecordId => apex.id;

  @override
  Iterable<EditCard<EquipmentItem>> get hostEditCards => [
    gearItemEditCards[GearItemCardId.notes]!,
  ];

  @override
  List<AddStripEntry> addStripEntries(EquipmentItem working) => const [];

  @override
  void onGearItemSaved(
    EditSession<EquipmentItem> session,
    EquipmentItem? after,
    ProviderContainer container,
  ) => saved.add(after);

  @override
  void dispose() {
    disposeEditing();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    followStored(equipmentItemProvider(apex.id));
    final stored = ref.watch(equipmentItemProvider(apex.id)).value;
    if (stored == null) return const SizedBox.shrink();
    return editScaffold(
      record: stored,
      shown: shownRecord(stored),
      lockedBar: AppBar(actions: [lockButton(stored)]),
      content: const SizedBox.shrink(),
    );
  }
}

void main() {
  setUp(() async {
    await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
  });
  tearDown(tearDownTestDatabase);

  Future<({FakeGearItemSave save, _OtherItemPageState state})> pump(
    WidgetTester tester, {
    List<Object> extraOverrides = const [],
  }) async {
    final stored = StateProvider<EquipmentItem?>((ref) => apex);
    late FakeGearItemSave save;
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...await getBaseOverrides(),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
          equipmentItemProvider(
            apex.id,
          ).overrideWith((ref) async => ref.watch(stored)),
          serviceRecordNotifierProvider(
            apex.id,
          ).overrideWith((ref) => CountingServiceRecords()),
          gearItemEditSaveServiceProvider.overrideWith(
            (ref) => save = FakeGearItemSave(ref.watch(stored.notifier)),
          ),
          ...extraOverrides,
        ],
        child: const _OtherItemPage(),
      ),
    );
    await tester.pumpAndSettle();
    final state = tester.state<_OtherItemPageState>(
      find.byType(_OtherItemPage),
    );
    state.ref.read(gearItemEditSaveServiceProvider);
    return (save: save, state: state);
  }

  testWidgets('a sitting saved through the mixin goes to the item\'s save '
      'service with its cards, and the page is told', (tester) async {
    final page = await pump(tester);
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
    final controller = page.state.editController;
    controller.session!.set(gearNotesField, 'Serviced in May');

    await controller.save();
    await tester.pumpAndSettle();

    expect(page.save.calls.single.cards, {GearItemCardId.notes.name});
    expect(page.save.calls.single.after.notes, 'Serviced in May');
    expect(page.state.saved.single?.notes, 'Serviced in May');
  });

  // The tag write offered after Save reads the stored fill back; a read
  // that fails there is the offer's, never an uncaught error.
  testWidgets('a failed read behind the tag offer after Save is logged, not '
      'thrown', (tester) async {
    final page = await pump(
      tester,
      extraOverrides: [
        cylinderFillRepositoryProvider.overrideWithValue(_BrokenFills()),
      ],
    );
    page.save.runHeld = false;
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
    final controller = page.state.editController;
    holdLoggedFill(
      controller.session!,
      CylinderFill(
        id: '',
        passportId: 'pp',
        equipmentId: apex.id,
        filledAt: DateTime(2026, 3, 3),
        o2Percent: 32,
        createdAt: DateTime(2026, 3, 3),
        updatedAt: DateTime(2026, 3, 3),
      ),
    );

    await controller.save();
    await tester.pumpAndSettle();

    expect(page.save.calls, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('its sitting loads the item\'s lists', (tester) async {
    final page = await pump(tester);
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();

    final session = page.state.editController.session!;
    await tester.runAsync(() => gearItemClocksList.currentOrRead(session));
    await tester.pumpAndSettle();

    expect(gearItemClocksList.loaded(session), isEmpty);
  });
}

/// A fills repository whose reads fail.
class _BrokenFills extends CylinderFillRepository {
  @override
  Future<CylinderFill?> getById(String id) =>
      Future.error(StateError('database is locked'));
}
