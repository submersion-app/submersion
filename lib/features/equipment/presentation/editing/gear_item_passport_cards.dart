import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_current_fill_card.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_fill_history_card.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_service_card.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_tag_card.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_trip_card.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_card_ids.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_passport_sitting.dart';
import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';
import 'package:submersion/features/gear_passports/presentation/widgets/gear_tag_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

// The cards of a gear item's passports (issue #4527, phase 3, plan 7).
// They are cards of the item, held in its sitting: a passport opened alone
// holds them in its own sitting on the item, and one pushed from an
// unlocked item page joins the item's. The item page lists them too, so
// its Save checks them.

/// What a tag-card's buttons need from the page it is on.
typedef PassportPrint = Future<void> Function(BuildContext buttonContext);

/// The fills card: the current fill and every fill, one card, since both
/// edit the cylinder's fills.
final EditCard<EquipmentItem> passportFillsCard = EditCard<EquipmentItem>(
  id: GearItemCardId.passportFills.name,
  title: (context) =>
      GearItemCardId.passportFills.localizedDisplayName(context.l10n),
  isEmpty: (_) => false,
  editorBuilder: (context, session) => PassportFillsEditor(session: session),
);

/// The cylinder passport's Service card: Track O2 clean holds a clock in
/// the item's service clocks, so it is that card on this page.
final EditCard<EquipmentItem> passportServiceCard = EditCard<EquipmentItem>(
  id: GearItemCardId.serviceClocks.name,
  title: (context) =>
      GearItemCardId.serviceClocks.localizedDisplayName(context.l10n),
  isEmpty: (_) => false,
  editorBuilder: (context, session) =>
      PassportServiceCard(equipment: session.working, editing: session),
);

/// The Trip card: the trips the item is packed for.
final EditCard<EquipmentItem> passportTripCard = EditCard<EquipmentItem>(
  id: GearItemCardId.passportTrip.name,
  title: (context) =>
      GearItemCardId.passportTrip.localizedDisplayName(context.l10n),
  isEmpty: (_) => false,
  editorBuilder: (context, session) =>
      PassportTripCard(equipmentId: session.stored.id, editing: session),
);

/// The Tag card of the item's passport: a cylinder's, or other gear's.
/// [scannedTag] and [onPrintLabel] are the page's, so the open card keeps
/// its stale hint and its Print button.
EditCard<EquipmentItem> passportTagCard({
  Object? scannedTag,
  PassportPrint? onPrintLabel,
}) => EditCard<EquipmentItem>(
  id: GearItemCardId.passportTag.name,
  title: (context) =>
      GearItemCardId.passportTag.localizedDisplayName(context.l10n),
  isEmpty: (_) => false,
  editorBuilder: (context, session) =>
      session.working.type == EquipmentType.tank
      ? PassportTagCard(
          equipment: session.working,
          scannedTag: scannedTag is CylinderPassportPayload ? scannedTag : null,
          onPrintLabel: onPrintLabel,
          editing: session,
        )
      : GearTagCard(
          equipment: session.working,
          scannedTag: scannedTag is GearTagPayload ? scannedTag : null,
          onPrintLabel: onPrintLabel,
          editing: session,
        ),
);

/// The fills card's editor: the current fill, logged under the passport id
/// the sitting shows, and every fill.
class PassportFillsEditor extends ConsumerWidget {
  const PassportFillsEditor({super.key, required this.session});

  final EditSession<EquipmentItem> session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = session.stored.id;
    final stored = ref.watch(passportIdProvider(id)).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PassportCurrentFillCard(
          equipmentId: id,
          passportId: passportIdInSitting(session, stored),
          editing: session,
        ),
        const SizedBox(height: 16),
        PassportFillHistoryCard(equipmentId: id, editing: session),
      ],
    );
  }
}
