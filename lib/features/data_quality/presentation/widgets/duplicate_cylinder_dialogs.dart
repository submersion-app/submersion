import 'package:flutter/material.dart';

import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/features/data_quality/data/services/duplicate_cylinder_service.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding_subjects.dart';
import 'package:submersion/features/data_quality/presentation/widgets/quality_finding_card.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_tank.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The diver's answer to a duplicate cylinder removal (issue #4393).
class DuplicateRemovalChoice {
  const DuplicateRemovalChoice({this.mix});

  /// The gas the kept cylinder carries, when the rows disagreed.
  final ({double o2, double he})? mix;
}

/// How a cylinder of a merge is named: "Tank 2" or "Tank 2 · AL80".
String duplicateCylinderLabel(AppLocalizations l10n, CylinderSummary c) =>
    qualityTankLabel(l10n, QualityTankRef(number: c.number, name: c.name));

/// What a removal did, in one line, or null when it changed nothing (a
/// stale finding whose rows had already gone).
String? duplicateRemovalSummary(
  AppLocalizations l10n,
  DuplicateRemovalResult result,
) {
  if (result.merged == 0 && result.skippedMixes == 0 && result.failed == 0) {
    return null;
  }
  return [
    l10n.dataQuality_bulk_removeDuplicates_done(result.merged),
    if (result.skippedMixes > 0)
      l10n.dataQuality_bulk_skippedMixes(result.skippedMixes),
    if (result.failed > 0) l10n.dataQuality_bulk_failed(result.failed),
  ].join('. ');
}

/// Asks before merging one dive's duplicate rows. When they disagree on gas
/// it also asks which gas the cylinder held, defaulting to the kept row's.
/// Null on cancel.
Future<DuplicateRemovalChoice?> confirmRemoveDuplicate(
  BuildContext context,
  CylinderMergePreview preview,
) {
  return showDialog<DuplicateRemovalChoice>(
    context: context,
    builder: (context) => _RemoveDuplicateDialog(preview: preview),
  );
}

class _RemoveDuplicateDialog extends StatefulWidget {
  const _RemoveDuplicateDialog({required this.preview});
  final CylinderMergePreview preview;

  @override
  State<_RemoveDuplicateDialog> createState() => _RemoveDuplicateDialogState();
}

class _RemoveDuplicateDialogState extends State<_RemoveDuplicateDialog> {
  // Every distinct recorded mix, the kept row's first so the choice starts
  // on an option. Exact values, not the clash tolerance: tolerance is not
  // transitive, so folding by it could hide a mix the clash check counted.
  late final List<({double o2, double he})> _mixes = <({double o2, double he})>{
    (o2: widget.preview.survivor.o2, he: widget.preview.survivor.he),
    for (final c in widget.preview.cylinders) (o2: c.o2, he: c.he),
  }.toList();

  /// The mix's gas name, with its exact percentages when another option
  /// rounds to the same name ("Air (21.04% O2)"). Two decimals, since the
  /// options can sit closer than the one decimal a gas column shows, in the
  /// locale's own separator.
  String _label(({double o2, double he}) mix) {
    String name(({double o2, double he}) m) => GasMix(o2: m.o2, he: m.he).name;
    final own = name(mix);
    if (_mixes.where((m) => name(m) == own).length < 2) return own;
    String pct(double v) => formatFixedForDisplay(v, 2);
    final he = mix.he > 0 ? ', ${pct(mix.he)}% He' : '';
    return '$own (${pct(mix.o2)}% O2$he)';
  }

  late ({double o2, double he}) _chosen = (
    o2: widget.preview.survivor.o2,
    he: widget.preview.survivor.he,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final preview = widget.preview;
    final keep = duplicateCylinderLabel(l10n, preview.survivor);
    final askMix = preview.mixesDiffer;
    return AlertDialog(
      title: Text(
        askMix
            ? l10n.dataQuality_removeDuplicate_mixTitle
            : l10n.dataQuality_removeDuplicate_title(
                preview.duplicateIds.length,
              ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            askMix
                ? l10n.dataQuality_removeDuplicate_mixBody
                : l10n.dataQuality_removeDuplicate_body(keep),
          ),
          if (askMix)
            RadioGroup<({double o2, double he})>(
              groupValue: _chosen,
              onChanged: (mix) {
                if (mix != null) setState(() => _chosen = mix);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final mix in _mixes)
                    RadioListTile<({double o2, double he})>(
                      value: mix,
                      title: Text(_label(mix)),
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(DuplicateRemovalChoice(mix: askMix ? _chosen : null)),
          child: Text(l10n.dataQuality_removeDuplicate_confirm),
        ),
      ],
    );
  }
}
