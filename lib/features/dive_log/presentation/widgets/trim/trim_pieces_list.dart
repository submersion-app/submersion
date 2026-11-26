import 'package:flutter/material.dart';

import 'package:submersion/core/buoyancy/trim/trim_moment.dart';
import 'package:submersion/core/buoyancy/trim/trim_spot.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trim/trim_strings.dart';
import 'package:submersion/features/dive_log/presentation/widgets/trim/trim_tryout_controller.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A choice from a piece's menu.
sealed class TrimPieceAction {
  const TrimPieceAction();
}

class TrimPieceMove extends TrimPieceAction {
  const TrimPieceMove();
}

class TrimPieceSide extends TrimPieceAction {
  const TrimPieceSide(this.lateral);
  final TrimLateral lateral;
}

/// Every element of the try-out scene, with a menu to move it or change its
/// side (issue #5028): the way to do what dragging does without dragging,
/// for a screen reader, a keyboard, or an element another one covers.
class TrimPiecesList extends StatelessWidget {
  const TrimPiecesList({
    super.key,
    required this.controller,
    required this.units,
  });

  final TrimTryoutController controller;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in controller.scene.elements)
          ListTile(
            key: ValueKey('trim-piece-${e.id}'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(trimElementName(e, l10n)),
            subtitle: Text(_where(e, context)),
            trailing: controller.canMove(e) || e.spot.sided
                ? PopupMenuButton<TrimPieceAction>(
                    tooltip: l10n.trim_tryout_pieceMenu,
                    onSelected: (action) => _act(context, e, action),
                    itemBuilder: (context) => [
                      if (controller.canMove(e))
                        PopupMenuItem(
                          value: const TrimPieceMove(),
                          child: Text(l10n.trim_tryout_moveTo),
                        ),
                      if (e.spot.sided) ...[
                        const PopupMenuDivider(),
                        for (final (lateral, label) in [
                          (TrimLateral.centre, l10n.diveLog_weight_side_both),
                          (TrimLateral.left, l10n.diveLog_weight_side_left),
                          (TrimLateral.right, l10n.diveLog_weight_side_right),
                        ])
                          CheckedPopupMenuItem(
                            value: TrimPieceSide(lateral),
                            checked: e.lateral == lateral,
                            child: Text(label),
                          ),
                      ],
                    ],
                  )
                : null,
          ),
      ],
    );
  }

  String _where(TrimElement e, BuildContext context) {
    final l10n = context.l10n;
    final side = trimSideMark(e, l10n);
    final spot = e.spot.label(l10n);
    final weight = units.formatWeight(e.sinkKg);
    return side.isEmpty ? '$weight, $spot' : '$weight, $spot ($side)';
  }

  Future<void> _act(
    BuildContext context,
    TrimElement e,
    TrimPieceAction action,
  ) async {
    switch (action) {
      case TrimPieceSide(:final lateral):
        controller.setSide(e.id, lateral);
      case TrimPieceMove():
        final l10n = context.l10n;
        final spot = await showDialog<TrimSpot>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(l10n.trim_tryout_moveTo),
            children: [
              for (final s in controller.spotsFor(e))
                SimpleDialogOption(
                  onPressed: () => Navigator.of(context).pop(s),
                  child: Text(s.label(l10n)),
                ),
            ],
          ),
        );
        if (spot != null) controller.move(e.id, spot);
    }
  }
}
