import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_append_row.dart';
import 'package:submersion/shared/widgets/forms/form_caption.dart';
import 'package:submersion/shared/widgets/forms/form_overline.dart';
import 'package:submersion/shared/widgets/forms/minutes_seconds_field.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// Which part of a switch the diver changed, so the page knows whether to
/// refill the depth from the profile (a time change) or leave a depth the
/// diver typed alone.
enum GasSwitchField { time, tank, depth }

/// The gas switch list under the cylinders on the dive edit page (issue
/// #32): one row per switch in time order, each with the time from the
/// start of the dive, the cylinder switched to and the depth, plus a line
/// naming the cylinder the dive starts on. Validation runs through the
/// enclosing [Form], which is how the page blocks Save.
class GasSwitchesEditor extends StatelessWidget {
  const GasSwitchesEditor({
    super.key,
    required this.switches,
    required this.tanks,
    required this.units,
    required this.maxTimestamp,
    required this.startingTank,
    required this.removedWithTankCount,
    required this.onChanged,
    required this.onRemove,
    required this.onAdd,
  });

  /// The switches in any order; the editor shows them by time.
  final List<GasSwitch> switches;

  /// The dive's cylinders in editor order, which numbers them.
  final List<DiveTank> tanks;

  final UnitFormatter units;

  /// The dive's runtime in seconds; null when nothing says how long it was.
  final int? maxTimestamp;

  /// The cylinder the dive starts on; null hides the line.
  final DiveTank? startingTank;

  /// Switches dropped because their cylinder was removed, shown until the
  /// next edit.
  final int removedWithTankCount;

  final void Function(GasSwitch updated, GasSwitchField field) onChanged;
  final ValueChanged<String> onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sorted = [...switches]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final start = startingTank;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormOverline(label: l10n.diveLog_edit_overline_gasSwitches),
        FormCaption(l10n.diveLog_edit_gasSwitches_caption),
        if (start != null)
          FormCaption(
            l10n.diveLog_edit_gasSwitches_startsOn(
              gasSwitchTankLabel(l10n, tanks, start),
            ),
          ),
        if (removedWithTankCount > 0)
          FormCaption(
            l10n.diveLog_edit_gasSwitches_removedWithTank(removedWithTankCount),
          ),
        for (final sw in sorted)
          _GasSwitchRow(
            key: ValueKey('gas-switch-row-${sw.id}'),
            gasSwitch: sw,
            tanks: tanks,
            units: units,
            maxTimestamp: maxTimestamp,
            otherTimestamps: {
              for (final other in sorted)
                if (other.id != sw.id) other.timestamp,
            },
            onChanged: onChanged,
            onRemove: onRemove,
          ),
        FormAppendRow(label: l10n.diveLog_edit_gasSwitches_add, onTap: onAdd),
      ],
    );
  }
}

/// "Tank 2 · Deco · EAN50": the cylinder's number in [tanks], its role and
/// its gas, the way the cylinder rows name it.
String gasSwitchTankLabel(
  AppLocalizations l10n,
  List<DiveTank> tanks,
  DiveTank tank,
) {
  final number = tanks.indexWhere((t) => t.id == tank.id) + 1;
  return '${l10n.diveLog_edit_tankCard_title(number)} · '
      '${tank.role.localizedName(l10n)} · ${tank.gasMix.name}';
}

class _GasSwitchRow extends StatefulWidget {
  const _GasSwitchRow({
    super.key,
    required this.gasSwitch,
    required this.tanks,
    required this.units,
    required this.maxTimestamp,
    required this.otherTimestamps,
    required this.onChanged,
    required this.onRemove,
  });

  final GasSwitch gasSwitch;
  final List<DiveTank> tanks;
  final UnitFormatter units;
  final int? maxTimestamp;
  final Set<int> otherTimestamps;
  final void Function(GasSwitch updated, GasSwitchField field) onChanged;
  final ValueChanged<String> onRemove;

  @override
  State<_GasSwitchRow> createState() => _GasSwitchRowState();
}

class _GasSwitchRowState extends State<_GasSwitchRow> {
  late final TextEditingController _depth = TextEditingController(
    text: _depthText(widget.gasSwitch.depth),
  );

  String _depthText(double? meters) => meters == null
      ? ''
      : widget.units.convertDepth(meters).toStringAsFixed(1);

  double? _parseDepth(String text) =>
      switch (readNumber(text, allowNegative: false)) {
        NumberValue(:final value) => widget.units.depthToMeters(value),
        _ => null,
      };

  @override
  void didUpdateWidget(_GasSwitchRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A depth filled in from the profile replaces the text; a depth the
    // diver typed, which already reads as the new value, stays as typed.
    final depth = widget.gasSwitch.depth;
    if (depth != oldWidget.gasSwitch.depth &&
        _parseDepth(_depth.text) != depth) {
      _depth.text = _depthText(depth);
    }
  }

  @override
  void dispose() {
    _depth.dispose();
    super.dispose();
  }

  String? _timeError(AppLocalizations l10n, int seconds) {
    final max = widget.maxTimestamp;
    if (seconds < 0 || (max != null && seconds > max)) {
      return l10n.diveLog_edit_gasSwitches_timeRangeError;
    }
    if (widget.otherTimestamps.contains(seconds)) {
      return l10n.diveLog_edit_gasSwitches_duplicateError;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sw = widget.gasSwitch;
    final tankIds = {for (final t in widget.tanks) t.id};
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: MinutesSecondsField(
              key: ValueKey('gas-switch-time-${sw.id}'),
              seconds: sw.timestamp,
              label: l10n.diveLog_edit_gasSwitches_time,
              formatErrorText: l10n.diveLog_edit_gasSwitches_timeFormatError,
              validator: (seconds) => _timeError(l10n, seconds),
              onChanged: (seconds) {
                if (seconds == null) return;
                widget.onChanged(
                  sw.copyWith(timestamp: seconds),
                  GasSwitchField.time,
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              key: ValueKey('gas-switch-tank-${sw.id}'),
              initialValue: tankIds.contains(sw.tankId) ? sw.tankId : null,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.diveLog_edit_gasSwitches_switchTo,
                isDense: true,
              ),
              items: [
                for (final tank in widget.tanks)
                  DropdownMenuItem(
                    value: tank.id,
                    child: Text(
                      gasSwitchTankLabel(l10n, widget.tanks, tank),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (id) {
                if (id == null) return;
                widget.onChanged(sw.copyWith(tankId: id), GasSwitchField.tank);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: NumberField(
              key: ValueKey('gas-switch-depth-${sw.id}'),
              controller: _depth,
              decoration: InputDecoration(
                labelText: l10n.diveLog_edit_gasSwitches_depth,
                suffixText: widget.units.depthSymbol,
                isDense: true,
              ),
              onChanged: (read) => switch (read) {
                NumberValue(:final value) => widget.onChanged(
                  sw.copyWith(depth: widget.units.depthToMeters(value)),
                  GasSwitchField.depth,
                ),
                NumberBlank() => widget.onChanged(
                  sw.copyWith(clearDepth: true),
                  GasSwitchField.depth,
                ),
                // The field shows why the text cannot be read and blocks the
                // save; the stored depth stands until it can.
                NumberInvalid() => null,
              },
            ),
          ),
          IconButton(
            key: ValueKey('gas-switch-remove-${sw.id}'),
            icon: const Icon(Icons.remove_circle_outline),
            tooltip: l10n.diveLog_edit_gasSwitches_remove,
            onPressed: () => widget.onRemove(sw.id),
          ),
        ],
      ),
    );
  }
}
