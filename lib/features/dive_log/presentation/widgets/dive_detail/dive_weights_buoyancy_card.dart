import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/buoyancy_twin_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_header_actions.dart';
import 'package:submersion/features/dive_log/presentation/widgets/buoyancy_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_weight_rows.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';

/// The dive page's Weights and buoyancy card: the lead the diver carried,
/// then the modeled buoyancy of the dive (issue #5005).
///
/// It is the Weights section's card, so it can be edited in place: unlocked,
/// its title row gains the pencil, which opens the weights editor in place of
/// the whole card.
///
/// [dive] draws the weights, which can be edited; [stored] drives the model,
/// which is worked out, so nothing typed in a sitting reworks it before Save
/// (the way the Environment card's satellite conditions read the stored dive).
/// [showWeights] is false when there is no lead to list. The model part shows
/// once it has an outcome; until then, or for a dive it cannot model, the card
/// holds the weights alone.
class DiveWeightsBuoyancyCard extends ConsumerWidget {
  const DiveWeightsBuoyancyCard({
    super.key,
    required this.dive,
    required this.stored,
    required this.showWeights,
  });

  final Dive dive;
  final Dive stored;
  final bool showWeights;

  /// The waves icon and its gap before the title.
  static const double _leadingWidth = 32;

  /// The pencil and its gap, and the unsaved-changes dot beside the title,
  /// drawn while the dive is unlocked. Reserved while locked too, so that
  /// unlocking never changes which form the What if? button takes: the title
  /// would rewrap and the row change height under the diver's finger.
  static const double _pencilWidth = 48;

  /// The least the title keeps before the What if? button gives up its
  /// label: the title wraps rather than ellipsizing, so without a floor it
  /// would fold into a column of single words.
  static const double _minTitleWidth = 96;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // AsyncValue.value keeps the last outcome while the provider reloads, as
    // it does behind every refresh of the dive, so the model stays on screen.
    final outcome = ref.watch(buoyancyTwinProvider(stored.id)).value;
    final units = ref.watch(unitFormatterProvider);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                const room = _leadingWidth + _minTitleWidth + _pencilWidth;
                return RecordCardHeader(
                  title: context.l10n.diveDetailSection_weights_name,
                  leading: Icon(Icons.waves, color: theme.colorScheme.primary),
                  trailing: outcome == null
                      ? null
                      : BuoyancyHeaderActions(
                          outcome: outcome,
                          units: units,
                          compact:
                              constraints.maxWidth <
                              room + BuoyancyHeaderActions.fullWidth(context),
                        ),
                );
              },
            ),
            if (showWeights) ...[
              const SizedBox(height: 12),
              DiveWeightRows(dive: dive),
            ],
            if (showWeights && outcome != null) const Divider(height: 24),
            if (!showWeights && outcome != null) const SizedBox(height: 12),
            BuoyancySection(diveId: stored.id, dive: stored, units: units),
          ],
        ),
      ),
    );
  }
}
