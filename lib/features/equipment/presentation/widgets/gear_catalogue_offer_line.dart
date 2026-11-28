import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/catalogue/equipment_catalogue_offer.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_catalogue_sitting.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_catalogue_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/gear_catalogue_review_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// Under the gear editor's brand and model: that the built-in equipment
/// catalogue has the model typed, and the way to review it (issue #5118).
/// Nothing shows while the catalogue loads, for a name it lacks, or when
/// there is nothing left to offer ([showOfferLine]). The review never opens
/// by itself.
class GearCatalogueOfferLine extends ConsumerWidget {
  const GearCatalogueOfferLine({super.key, required this.session});

  final EditSession<EquipmentItem> session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(equipmentCatalogueProvider).value;
    if (catalogue == null || session.isDisposed) return const SizedBox.shrink();
    final working = session.working;
    final record = catalogue.resolve(
      working.type,
      working.brand,
      working.model,
    );
    if (record == null) return const SizedBox.shrink();
    final offer = offerFor(working, record);
    if (!showOfferLine(working, offer)) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Text(
            l10n.equipment_catalogue_offerLine,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          TextButton(
            key: const ValueKey('gear-catalogue-review'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () async {
              final result = await showGearCatalogueReview(context, offer);
              if (result != null) {
                holdGearCatalogueReview(session, offer, result);
              }
            },
            child: Text(l10n.equipment_catalogue_review),
          ),
        ],
      ),
    );
  }
}
