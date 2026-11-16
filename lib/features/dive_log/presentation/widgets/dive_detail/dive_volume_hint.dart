import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_volume_hint.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

/// Why SAC is shown per pressure unit: no cylinder has a volume. Under the
/// air consumption rows and on the gas consumption card.
///
/// During a sitting it opens the Cylinders card, where the volume is
/// entered, and asks for it to be shown (it is brought in from the Add
/// strip if the page was leaving it out). Otherwise it leads to the dive
/// form, as it did before the dive page could be edited in place
/// (issue #4527, plan 5).
///
/// A widget of its own, so that it alone, and not the rows around it, is
/// rebuilt as the page is locked and unlocked.
class DiveVolumeHint extends StatelessWidget {
  const DiveVolumeHint({
    super.key,
    required this.diveId,
    required this.volumeSymbol,
  });

  final String diveId;
  final String volumeSymbol;

  @override
  Widget build(BuildContext context) {
    final edit = RecordEditScope.maybeOf<Dive>(context);
    return SacVolumeHint(
      volumeSymbol: volumeSymbol,
      onTap: edit != null && edit.isUnlocked
          ? () => edit.addCard(DiveDetailSectionId.tanks.name)
          : () => context.push('/dives/$diveId/edit'),
    );
  }
}
