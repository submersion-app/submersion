import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_mix_pill.dart';

// Shares of the card width each column takes. Proportional rather than sized
// to their content, so the columns of every row line up at any card width
// (issue #3675); a number that does not fit scales down instead.
const _tankFlex = 32;
const _gasFlex = 22;
const _pressureFlex = 15;

/// The tank's role icon, and the space it and its gap take, so the detail
/// lines under a row start where the tank's name does.
const _iconSize = 20.0;
const _iconIndent = 28.0;

/// What a pressure cell shows for a value the tank does not have.
const _missing = '--';

/// The table's column names: drawn once in [CylinderTableHeader], and read
/// out with every cell by [CylinderTableRow], since a screen reader does not
/// pair a cell with the header above it.
typedef CylinderColumnLabels = ({
  String tank,
  String gas,
  String start,
  String end,
  String used,
});

/// Header of the Cylinders card's table: Tank, Gas, then the three pressure
/// columns with the pressure [unit] under each, so the cells below hold bare
/// numbers.
class CylinderTableHeader extends StatelessWidget {
  const CylinderTableHeader({
    super.key,
    required this.labels,
    required this.unit,
  });

  final CylinderColumnLabels labels;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w500,
    );
    final unitStyle = style?.copyWith(fontWeight: FontWeight.w400);

    Widget label(String text, TextStyle? style, AlignmentGeometry alignment) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: Text(text, maxLines: 1, style: style),
      );
    }

    Widget pressure(String text) => Expanded(
      flex: _pressureFlex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          label(text, style, AlignmentDirectional.centerEnd),
          label(unit, unitStyle, AlignmentDirectional.centerEnd),
        ],
      ),
    );

    // Every cell in a row announces its own column (and the pressure cells
    // their unit), so the visual header would only be read a second time.
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              flex: _tankFlex,
              child: label(
                labels.tank,
                style,
                AlignmentDirectional.centerStart,
              ),
            ),
            Expanded(
              flex: _gasFlex,
              child: label(labels.gas, style, AlignmentDirectional.centerStart),
            ),
            pressure(labels.start),
            pressure(labels.end),
            pressure(labels.used),
          ],
        ),
      ),
    );
  }
}

/// One cylinder in the Cylinders card's table: what the tank is, its gas
/// and its pressures on the row, then [details] under it in a single quiet
/// style, with [trailing] (the gear check-in) at the end of that block.
class CylinderTableRow extends StatelessWidget {
  const CylinderTableRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle = const [],
    required this.gasMix,
    required this.start,
    required this.end,
    required this.used,
    required this.columnLabels,
    required this.unit,
    this.details = const [],
    this.trailing,
  });

  final IconData icon;

  /// The tank's name, else its size, else its number.
  final String title;

  /// Items under the title (the size when the name took the title, and the
  /// role), joined by dots.
  final List<Widget> subtitle;
  final GasMix gasMix;

  /// The formatted pressures, each null when the tank does not have it.
  final String? start;
  final String? end;
  final String? used;
  final CylinderColumnLabels columnLabels;

  /// The pressure unit, read out with each cell for the same reason.
  final String unit;
  final List<Widget> details;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final number = theme.textTheme.bodyMedium;

    Widget pressure(String label, String? value, {bool emphasised = false}) =>
        Expanded(
          flex: _pressureFlex,
          child: Semantics(
            container: true,
            // A missing value has no unit to read out.
            label: value == null ? '$label $_missing' : '$label $value $unit',
            excludeSemantics: true,
            child: Align(
              alignment: AlignmentDirectional.topEnd,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value ?? _missing,
                  maxLines: 1,
                  style: emphasised
                      ? number?.copyWith(fontWeight: FontWeight.w700)
                      : number,
                ),
              ),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: _tankFlex,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      icon,
                      size: _iconSize,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: _iconIndent - _iconSize),
                    // One node that reads the column name, then the title and
                    // the items under it.
                    Expanded(
                      child: MergeSemantics(
                        child: Semantics(
                          label: columnLabels.tank,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: theme.textTheme.titleSmall),
                              if (subtitle.isNotEmpty)
                                DefaultTextStyle.merge(
                                  style: muted,
                                  child: DotJoinedWrap(children: subtitle),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: _gasFlex,
                child: Semantics(
                  container: true,
                  label: '${columnLabels.gas} ${gasMix.name}',
                  excludeSemantics: true,
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: GasMixPill(gasMix: gasMix),
                    ),
                  ),
                ),
              ),
              pressure(columnLabels.start, start),
              pressure(columnLabels.end, end),
              pressure(columnLabels.used, used, emphasised: true),
            ],
          ),
          if (details.isNotEmpty || trailing != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: _iconIndent,
                top: 4,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DefaultTextStyle.merge(
                      style: muted,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 2,
                        children: details,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// [children] in a wrapping line, each but the last followed by a dot, so a
/// line breaks between items rather than inside one; only an item wider
/// than the whole line wraps inside itself. The dots are not read out.
class DotJoinedWrap extends StatelessWidget {
  const DotJoinedWrap({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < children.length; i++)
          i == children.length - 1
              ? children[i]
              // Flexible lets an item wider than the whole line wrap inside
              // itself rather than overflow.
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: children[i]),
                    const ExcludeSemantics(child: Text(' · ')),
                  ],
                ),
      ],
    );
  }
}
