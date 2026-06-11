import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_style.dart';

/// Hero numbers row: big values with units and uppercase micro-labels,
/// separated by hairline vertical dividers. Editable cells swap to an
/// in-place numeric field on tap.
class StatStrip extends StatelessWidget {
  const StatStrip({super.key, required this.cells});

  final List<StatCell> cells;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < cells.length; i++) {
      children.add(Expanded(child: cells[i]));
      if (i < cells.length - 1) {
        children.add(
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: FormStyle.dividerColor(context),
          ),
        );
      }
    }
    return Padding(
      padding: FormStyle.heroPadding,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// One cell of a [StatStrip]. Editable when [controller] is provided,
/// display-only when [displayValue] is provided (exactly one is required).
class StatCell extends StatefulWidget {
  const StatCell({
    super.key,
    required this.label,
    this.unit,
    this.controller,
    this.displayValue,
    this.profileValue,
    this.onUseProfileValue,
    this.keyboardType = const TextInputType.numberWithOptions(decimal: true),
    this.dense = false,
  }) : assert(
         (controller == null) != (displayValue == null),
         'Provide exactly one of controller or displayValue',
       );

  final String label;
  final String? unit;
  final TextEditingController? controller;
  final String? displayValue;

  /// Renders the value at a reduced size for nested cells (e.g. tank cards)
  /// where compound values share a narrow cell. The value scales down to
  /// fit rather than truncating.
  final bool dense;

  /// Value computed from the dive profile; when it differs from the current
  /// text, a sync glyph offers to apply it via [onUseProfileValue].
  final String? profileValue;
  final ValueChanged<String>? onUseProfileValue;
  final TextInputType keyboardType;

  @override
  State<StatCell> createState() => _StatCellState();
}

class _StatCellState extends State<StatCell> {
  bool _editing = false;
  final _focusNode = FocusNode();

  bool get _editable => widget.controller != null;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _editing) {
        setState(() => _editing = false);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    if (!_editable) return;
    setState(() => _editing = true);
    widget.controller!.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.controller!.text.length,
    );
  }

  bool get _showProfileGlyph =>
      widget.profileValue != null &&
      widget.onUseProfileValue != null &&
      widget.profileValue != widget.controller?.text;

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return _buildEditor(context);
    }
    if (_editable) {
      // Rebuild the resting view whenever the controller changes externally
      // (load, use-profile-value, calculate buttons).
      return AnimatedBuilder(
        animation: widget.controller!,
        builder: (context, _) => _buildResting(context),
      );
    }
    return _buildResting(context);
  }

  Widget _buildResting(BuildContext context) {
    final text = _editable
        ? (widget.controller!.text.isEmpty ? '--' : widget.controller!.text)
        : widget.displayValue!;
    final valueStyle = FormStyle.heroValueStyle(context, dense: widget.dense);
    // Dense cells hold compound values (pressure ranges, psi, trimix names)
    // that can exceed a narrow cell; scale them down instead of truncating.
    final Widget value = widget.dense
        ? FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(text, style: valueStyle, maxLines: 1, softWrap: false),
          )
        : Text(
            text,
            style: valueStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
    return Semantics(
      button: _editable,
      label: widget.label,
      value: '$text ${widget.unit ?? ''}'.trim(),
      child: InkWell(
        onTap: _editable ? _startEditing : null,
        borderRadius: BorderRadius.circular(9),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: widget.dense
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(child: value),
                if (widget.unit != null)
                  Text(
                    ' ${widget.unit}',
                    style: FormStyle.heroUnitStyle(context),
                  ),
                if (_showProfileGlyph) _buildProfileGlyph(context),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              widget.label.toUpperCase(),
              style: FormStyle.heroLabelStyle(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileGlyph(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: context.l10n.forms_statCell_useProfileValue(
        widget.profileValue!,
      ),
      padding: EdgeInsets.zero,
      icon: Icon(
        Icons.sync_outlined,
        size: 14,
        color: Theme.of(context).colorScheme.primary,
      ),
      onSelected: widget.onUseProfileValue,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: widget.profileValue!,
          child: Text(
            context.l10n.forms_statCell_useProfileValue(widget.profileValue!),
          ),
        ),
      ],
    );
  }

  Widget _buildEditor(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        border: Border.all(color: theme.colorScheme.primary, width: 1.5),
        borderRadius: BorderRadius.circular(9),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            autofocus: true,
            textAlign: TextAlign.center,
            keyboardType: widget.keyboardType,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.,:-]')),
            ],
            style: FormStyle.heroValueStyle(context, dense: widget.dense),
            decoration: const InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              filled: false,
            ),
            onSubmitted: (_) => setState(() => _editing = false),
          ),
          const SizedBox(height: 2),
          Text(
            widget.unit == null
                ? widget.label.toUpperCase()
                : '${widget.label.toUpperCase()} (${widget.unit})',
            style: FormStyle.heroLabelStyle(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
