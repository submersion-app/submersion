import 'package:flutter/material.dart';

import 'package:submersion/core/built_ins/built_in_catalog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Width of the "Show" column on the Manage pages (issue #401). The header
/// label and each row's switch are centred in a box this wide, so the two
/// line up whatever size the switch or the translated label has.
const double kBuiltInShowColumnWidth = 64;

/// ListTile's default end padding, which the row switches sit inside. No app
/// theme overrides ListTile padding.
const double _tileEndPadding = 24;

/// The key of the show switch on [catalog]'s Manage page row for [id].
Key builtInShowSwitchKey(BuiltInCatalog catalog, String id) =>
    ValueKey('built-in-show-${catalog.key}-$id');

/// A Manage page section header with a "Show" label over the switch column
/// of the rows below it. [trailingInset] is the width of anything that sits
/// after the switch in those rows, such as a 48-wide menu button.
class BuiltInShowColumnHeader extends StatelessWidget {
  const BuiltInShowColumnHeader({
    super.key,
    this.title,
    this.titleStyle,
    this.trailingInset = 0,
    this.top = 16,
    this.bottom = 8,
  });

  final String? title;
  final TextStyle? titleStyle;
  final double trailingInset;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        16,
        top,
        _tileEndPadding + trailingInset,
        bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: title == null
                ? const SizedBox.shrink()
                : Text(title!, style: titleStyle),
          ),
          SizedBox(
            width: kBuiltInShowColumnWidth,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                context.l10n.builtIns_showColumnLabel,
                maxLines: 1,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The switch in a built-in row's "Show" column. Off hides the entry from the
/// pickers. Place it last in the row's trailing widgets, or give the header a
/// matching [BuiltInShowColumnHeader.trailingInset].
class BuiltInShowSwitch extends StatelessWidget {
  const BuiltInShowSwitch({
    super.key,
    required this.shown,
    required this.onChanged,
    this.switchKey,
    this.tooltip,
  });

  final bool shown;
  final ValueChanged<bool>? onChanged;
  final Key? switchKey;

  /// Defaults to the generic "Show in pickers".
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kBuiltInShowColumnWidth,
      child: Center(
        child: Tooltip(
          message: tooltip ?? context.l10n.builtIns_showInPickers,
          child: Switch(key: switchKey, value: shown, onChanged: onChanged),
        ),
      ),
    );
  }
}
