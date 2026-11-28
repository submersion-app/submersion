import 'package:submersion/features/equipment/domain/catalogue/equipment_catalogue_offer.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// What the diver chose in an equipment catalogue review (issue #5118).
sealed class GearCatalogueReviewResult {
  const GearCatalogueReviewResult();
}

/// Apply: link the item and take the ticked fields, by their names.
class GearCatalogueApply extends GearCatalogueReviewResult {
  const GearCatalogueApply(this.ticked);

  final Set<String> ticked;
}

/// The record is not this item.
class GearCatalogueNotThisModel extends GearCatalogueReviewResult {
  const GearCatalogueNotThisModel();
}

const String _revisionKey = 'gear.catalogue.revision';

/// How many reviews the sitting has applied. The attribute inputs take
/// their values once, so the editor rebuilds them when this moves.
int gearCatalogueRevision(EditSession<EquipmentItem> session) =>
    session.isDisposed ? 0 : session.recall<int>(_revisionKey) ?? 0;

bool _blank(String? value) => value == null || value.trim().isEmpty;

/// Holds in the sitting what the diver chose in the review of [offer]:
/// written only by the editor's Save, gone with a Cancel.
///
/// Apply sets each ticked field, links the item, and records the empty
/// fields left unticked as declined for the record. A ticked empty field
/// is set only while it is still empty: a value the diver typed after the
/// sheet opened stays. A ticked differing field is set: the diver chose it
/// beside their own. Not this model records only that answer.
void holdGearCatalogueReview(
  EditSession<EquipmentItem> session,
  CatalogueOffer offer,
  GearCatalogueReviewResult result,
) {
  if (session.isDisposed || session.isFrozen) return;
  final record = offer.record;
  final answers = session.valueOf(gearCatalogueAnswersField);
  switch (result) {
    case GearCatalogueNotThisModel():
      session.set(gearCatalogueAnswersField, answers.withNotSame(record.id));
    case GearCatalogueApply(:final ticked):
      for (final row in offer.rows) {
        if (!ticked.contains(row.fieldName)) continue;
        switch (row.kind) {
          case CatalogueOfferFieldKind.brand:
            if (!row.startTicked || _blank(session.valueOf(gearBrandField))) {
              session.set(gearBrandField, record.manufacturer);
            }
          case CatalogueOfferFieldKind.model:
            if (!row.startTicked || _blank(session.valueOf(gearModelField))) {
              session.set(gearModelField, record.model);
            }
          case CatalogueOfferFieldKind.attribute:
            final field = gearAttributeField(row.fieldName);
            final current = session.valueOf(field);
            final value = record.attributeFor(row.fieldName);
            if (value == null) continue;
            if (row.startTicked && current != null && current.hasContent) {
              continue;
            }
            session.set(
              field,
              value.copyWith(
                id: current?.id ?? '',
                equipmentId: session.stored.id,
              ),
            );
        }
      }
      final declined = [
        for (final row in offer.rows)
          if (row.startTicked && !ticked.contains(row.fieldName)) row.fieldName,
      ];
      session
        ..set(gearCatalogueIdField, record.id)
        ..set(
          gearCatalogueAnswersField,
          answers.withDeclined(record.id, declined),
        );
  }
  session.remember(_revisionKey, gearCatalogueRevision(session) + 1);
}
