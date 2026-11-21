import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../helpers/test_database.dart';
import 'equipment_detail_page_unlock_harness.dart';

/// A gear item saved on its full page stays on the item (issue #4527,
/// phase 3), so which of the list's views shows it is not that page's
/// business: only a Save in the list's pane offers the view that shows it
/// (equipment_detail_page_unlock_test.dart).
void main() {
  final l = AppLocalizationsEn();

  setUp(() async {
    await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
  });
  tearDown(tearDownTestDatabase);

  testWidgets('a full page Save of an item the view hides offers nothing', (
    tester,
  ) async {
    final wanted = apex.copyWith(
      status: EquipmentStatus.wanted,
      isActive: false,
    );
    await EquipmentRepository().createEquipment(wanted);
    await pumpGearPage(tester, item: wanted, openUnlocked: true);
    RecordEditScope.maybeOf<EquipmentItem>(
      tester.element(find.byType(RecordCardFrame<EquipmentItem>).first),
    )!.session!.set(gearNotesField, 'Rinse');
    await tester.pumpAndSettle();

    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();

    expect(find.text(l.equipment_edit_snackbar_hiddenByView), findsNothing);
  });
}
