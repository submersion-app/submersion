import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_match_review_notifier.dart';
import 'package:submersion/features/equipment/presentation/providers/cylinder_proposal_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/cylinders_from_tanks_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/tile_subtitle_action.dart';

/// The download summary's offer to add the new dives' cylinders to the
/// diver's gear (issue #4494): how many tanks no owned cylinder covers (each
/// covers one tank per dive), and a Review button opening the sheet. Nothing
/// shows when every tank is covered or linked, so a diver on their own cylinders never sees it again.
class ImportCylindersTile extends ConsumerWidget {
  const ImportCylindersTile({super.key, required this.importedDiveIds});

  final List<String> importedDiveIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (importedDiveIds.isEmpty) return const SizedBox.shrink();
    final proposals =
        ref
            .watch(
              importCylinderProposalsProvider(ImportedDiveIds(importedDiveIds)),
            )
            .value ??
        const [];
    if (proposals.isEmpty) return const SizedBox.shrink();
    final tanks = proposals.fold(0, (n, p) => n + p.allTanks.length);
    final l10n = context.l10n;
    return ListTile(
      key: const Key('import_summary_cylinders'),
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.propane_tank_outlined),
      title: Text(l10n.cylindersFromTanks_summary(tanks)),
      // On its own line under the label, as the data-quality tile does, so
      // a longer translation keeps its room (issue #2717).
      subtitle: TileSubtitleAction(
        onPressed: () => showCylindersFromTanksSheet(context, proposals),
        label: l10n.cylindersFromTanks_review,
      ),
    );
  }
}
