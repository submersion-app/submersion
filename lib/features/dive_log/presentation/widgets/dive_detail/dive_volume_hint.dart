import 'package:flutter/material.dart';

import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_volume_hint.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

/// Why SAC is shown per pressure unit: no cylinder has a volume. Under the
/// air consumption rows and on the gas consumption card.
///
/// During a sitting it opens the Cylinders card, where the volume is
/// entered, and asks for it to be shown (it is brought in from the Add
/// strip if the page was leaving it out). Locked, it reads only
/// (issue #4527, plans 5 and 11).
///
/// A widget of its own, so that it alone, and not the rows around it, is
/// rebuilt as the page is locked and unlocked.
class DiveVolumeHint extends StatelessWidget {
  const DiveVolumeHint({super.key, required this.volumeSymbol});

  final String volumeSymbol;

  @override
  Widget build(BuildContext context) {
    final edit = RecordEditScope.maybeOf<Dive>(context);
    return SacVolumeHint(
      volumeSymbol: volumeSymbol,
      // Locked, the hint reads only (issue #4527).
      onTap: edit != null && edit.isUnlocked
          ? () => edit.addCard(DiveDetailSectionId.tanks.name)
          : null,
    );
  }
}
