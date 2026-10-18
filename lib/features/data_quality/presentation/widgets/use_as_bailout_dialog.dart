import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/as_imported_gas_cylinder.dart';
import 'package:submersion/features/dive_log/domain/services/ccr_bailout_timeline.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the diver confirmed: whether to also register the transmitter.
typedef UseAsBailoutChoice = ({bool register});

/// Asks before a name-derived transmitter tank becomes the bailout (issue
/// #3307). Null when the diver cancels.
///
/// [tankNumber] is the tank's number as the dive page shows it. [ocTank] is
/// the open-circuit cylinder whose mix it takes; the merge line appears when
/// that cylinder is still as imported (the executor makes the final call).
Future<UseAsBailoutChoice?> showUseAsBailoutDialog(
  BuildContext context, {
  required DiveTank tank,
  required int tankNumber,
  required DiveTank? ocTank,
  bool ocHasPressureSeries = false,
}) => showDialog<UseAsBailoutChoice>(
  context: context,
  builder: (_) => UseAsBailoutDialog(
    tank: tank,
    tankNumber: tankNumber,
    ocTank: ocTank,
    ocHasPressureSeries: ocHasPressureSeries,
  ),
);

class UseAsBailoutDialog extends StatefulWidget {
  const UseAsBailoutDialog({
    super.key,
    required this.tank,
    required this.tankNumber,
    required this.ocTank,
    this.ocHasPressureSeries = false,
  });

  final DiveTank tank;
  final int tankNumber;
  final DiveTank? ocTank;

  /// Whether [ocTank] carries a pressure series, which the executor never
  /// merges, so the dialog promises the merge on the same rule.
  final bool ocHasPressureSeries;

  @override
  State<UseAsBailoutDialog> createState() => _UseAsBailoutDialogState();
}

class _UseAsBailoutDialogState extends State<UseAsBailoutDialog> {
  var _register = true;

  bool get _canRegister => widget.tank.transmitterSerial != null;

  bool get _willMerge {
    final oc = widget.ocTank;
    return oc != null &&
        oc.computerId == widget.tank.computerId &&
        isAsImportedGasCylinder(
          oc,
          hasPressureSeries: widget.ocHasPressureSeries,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tank = widget.tank;
    final oc = widget.ocTank;
    final targetRole = openCircuitTargetRole(oc?.role.name);
    String line(String field, String from, String to) =>
        l10n.cylinderConfigs_overwriteChange(field, from, to);

    return AlertDialog(
      title: Text(l10n.dataQuality_useAsBailout_title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              line(
                l10n.cylinderConfigs_role,
                l10n.diveLog_tank_roleFromTransmitterName(
                  tank.role.localizedName(l10n),
                ),
                targetRole.localizedName(l10n),
              ),
            ),
            if (oc != null && oc.gasMix.name != tank.gasMix.name)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  line(
                    l10n.cylinderConfigs_fieldGasMix,
                    tank.gasMix.name,
                    oc.gasMix.name,
                  ),
                ),
              ),
            if (_willMerge)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  l10n.dataQuality_useAsBailout_merge(widget.tankNumber),
                ),
              ),
            if (_canRegister) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _register,
                onChanged: (v) => setState(() => _register = v ?? false),
                title: Text(
                  l10n.dataQuality_useAsBailout_register(
                    targetRole.localizedName(l10n),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop((register: _canRegister && _register)),
          child: Text(l10n.dataQuality_repairLabel_useAsBailout),
        ),
      ],
    );
  }
}
