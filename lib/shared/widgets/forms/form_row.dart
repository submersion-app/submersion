import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/shared/widgets/forms/form_style.dart';

/// A value derived from the dive profile, offered as a one-tap fill on a
/// [FormRow.text] row. When [value] differs from the row's current text, the
/// resting row shows a calculate icon (tooltip [tooltip]) that calls [onUse].
class ProfileSuggestion {
  const ProfileSuggestion({
    required this.value,
    required this.onUse,
    required this.tooltip,
  });

  /// Already formatted in the diver's units (e.g. "18.5").
  final String value;
  final VoidCallback onUse;
  final String tooltip;
}

enum _RowKind { text, picker, display, toggle, rating, custom }

/// Label-left / value-right row used inside [FormSection] groups.
///
/// Variants:
/// - [FormRow.text]: tap expands inline into a real TextFormField
///   (styled by the app InputDecorationTheme); commits on done/unfocus.
/// - [FormRow.picker]: formatted value + chevron, opens a picker sheet.
/// - [FormRow.display]: muted, non-tappable (auto-computed values).
/// - [FormRow.toggle], [FormRow.rating], [FormRow.custom].
class FormRow extends StatefulWidget {
  const FormRow.text({
    super.key,
    required this.label,
    required this.controller,
    this.placeholder,
    this.suffixText,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.alwaysEditing = false,
    this.validator,
    this.onChanged,
    this.decoration,
    this.profileSuggestion,
  }) : _kind = _RowKind.text,
       enabled = true,
       helpText = null,
       value = null,
       onTap = null,
       onClear = null,
       clearTooltip = null,
       boolValue = null,
       onBoolChanged = null,
       intValue = null,
       onIntChanged = null,
       child = null;

  const FormRow.picker({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.placeholder,
    this.onClear,
    this.clearTooltip,
  }) : _kind = _RowKind.picker,
       enabled = true,
       helpText = null,
       profileSuggestion = null,
       decoration = null,
       controller = null,
       suffixText = null,
       keyboardType = null,
       inputFormatters = null,
       maxLines = 1,
       alwaysEditing = false,
       validator = null,
       onChanged = null,
       boolValue = null,
       onBoolChanged = null,
       intValue = null,
       onIntChanged = null,
       child = null;

  const FormRow.display({super.key, required this.label, required this.value})
    : _kind = _RowKind.display,
      enabled = true,
      helpText = null,
      profileSuggestion = null,
      decoration = null,
      controller = null,
      inputFormatters = null,
      onClear = null,
      clearTooltip = null,
      placeholder = null,
      suffixText = null,
      keyboardType = null,
      maxLines = 1,
      alwaysEditing = false,
      validator = null,
      onChanged = null,
      onTap = null,
      boolValue = null,
      onBoolChanged = null,
      intValue = null,
      onIntChanged = null,
      child = null;

  /// Set [enabled] to false to render the switch in its current position but
  /// inert, for a value that is implied by another control rather than freely
  /// chosen. Prefer this over silently overriding what the user picked.
  const FormRow.toggle({
    super.key,
    required this.label,
    required bool value,
    required ValueChanged<bool> onChanged,
    this.enabled = true,
    this.helpText,
  }) : _kind = _RowKind.toggle,
       profileSuggestion = null,
       decoration = null,
       inputFormatters = null,
       onClear = null,
       clearTooltip = null,
       boolValue = value,
       onBoolChanged = onChanged,
       controller = null,
       value = null,
       placeholder = null,
       suffixText = null,
       keyboardType = null,
       maxLines = 1,
       alwaysEditing = false,
       validator = null,
       onChanged = null,
       onTap = null,
       intValue = null,
       onIntChanged = null,
       child = null;

  const FormRow.rating({
    super.key,
    required this.label,
    required int value,
    required ValueChanged<int> onChanged,
    this.onClear,
    this.clearTooltip,
  }) : _kind = _RowKind.rating,
       enabled = true,
       helpText = null,
       profileSuggestion = null,
       decoration = null,
       inputFormatters = null,
       intValue = value,
       onIntChanged = onChanged,
       controller = null,
       value = null,
       placeholder = null,
       suffixText = null,
       keyboardType = null,
       maxLines = 1,
       alwaysEditing = false,
       validator = null,
       onChanged = null,
       onTap = null,
       boolValue = null,
       onBoolChanged = null,
       child = null;

  const FormRow.custom({super.key, required this.label, required this.child})
    : _kind = _RowKind.custom,
      enabled = true,
      helpText = null,
      profileSuggestion = null,
      decoration = null,
      controller = null,
      inputFormatters = null,
      onClear = null,
      clearTooltip = null,
      value = null,
      placeholder = null,
      suffixText = null,
      keyboardType = null,
      maxLines = 1,
      alwaysEditing = false,
      validator = null,
      onChanged = null,
      onTap = null,
      boolValue = null,
      onBoolChanged = null,
      intValue = null,
      onIntChanged = null;

  /// Toggle rows only: false renders the switch inert.
  final bool enabled;

  /// Optional explanatory line rendered under the row, for a control whose
  /// label cannot carry the whole meaning on its own.
  final String? helpText;

  final _RowKind _kind;
  final String label;
  final TextEditingController? controller;
  final String? value;
  final String? placeholder;
  final String? suffixText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final bool alwaysEditing;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final InputDecoration? decoration;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  /// Names the clear affordance for pointer and screen-reader users. Passed
  /// in already localized: this widget sits below the l10n layer, and
  /// reaching for it here would throw in every consumer test that pumps a
  /// bare MaterialApp.
  final String? clearTooltip;
  final bool? boolValue;
  final ValueChanged<bool>? onBoolChanged;
  final int? intValue;
  final ValueChanged<int>? onIntChanged;
  final Widget? child;
  final ProfileSuggestion? profileSuggestion;

  @override
  State<FormRow> createState() => _FormRowState();
}

class _FormRowState extends State<FormRow> {
  bool _editing = false;

  /// A row with a validator must keep its field mounted, or Form.validate()
  /// cannot see it.
  bool get _persistent => widget.alwaysEditing || widget.validator != null;
  final _focusNode = FocusNode();

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

  TextStyle _labelTextStyle(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium!;

  TextStyle _valueTextStyle(BuildContext context, {required bool muted}) {
    final theme = Theme.of(context);
    return theme.textTheme.bodyMedium!.copyWith(
      color: muted
          ? theme.colorScheme.onSurfaceVariant
          : theme.colorScheme.onSurface,
    );
  }

  InputDecoration _bareDecoration(BuildContext context) {
    return InputDecoration(
      isDense: true,
      filled: false,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      contentPadding: EdgeInsets.zero,
      hintText: widget.placeholder,
      suffixText: widget.suffixText,
    );
  }

  Widget _shell(
    BuildContext context, {
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    final row = Padding(
      padding: FormStyle.rowPadding,
      child: Row(
        children: [
          Text(widget.label, style: _labelTextStyle(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: trailing),
          ),
        ],
      ),
    );
    final help = widget.helpText;
    final content = help == null
        ? row
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              row,
              Padding(
                padding: EdgeInsets.only(
                  left: FormStyle.rowPadding.left,
                  right: FormStyle.rowPadding.right,
                  bottom: FormStyle.rowPadding.bottom,
                ),
                child: Text(
                  help,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    switch (widget._kind) {
      case _RowKind.text:
        if (_persistent || _editing) {
          return Padding(
            padding: FormStyle.rowPadding,
            child: Row(
              crossAxisAlignment: widget.maxLines > 1
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Text(widget.label, style: _labelTextStyle(context)),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: widget.controller,
                    focusNode: _persistent ? null : _focusNode,
                    autofocus: !_persistent,
                    maxLines: widget.maxLines,
                    keyboardType: widget.keyboardType,
                    inputFormatters: widget.inputFormatters,
                    validator: widget.validator,
                    onChanged: widget.onChanged,
                    textAlign: widget.maxLines > 1
                        ? TextAlign.start
                        : TextAlign.end,
                    style: theme.textTheme.bodyMedium,
                    decoration: widget.decoration ?? _bareDecoration(context),
                    onFieldSubmitted: _persistent
                        ? null
                        : (_) => setState(() => _editing = false),
                  ),
                ),
              ],
            ),
          );
        }
        return AnimatedBuilder(
          animation: widget.controller!,
          builder: (context, _) {
            final text = widget.controller!.text;
            final empty = text.isEmpty;
            final shown = empty
                ? (widget.placeholder ?? '')
                : (widget.suffixText == null
                      ? text
                      : '$text ${widget.suffixText}');
            final valueText = Text(
              shown,
              style: _valueTextStyle(context, muted: empty),
              maxLines: widget.maxLines > 1 ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            );
            final suggestion = widget.profileSuggestion;
            final showCalc = suggestion != null && suggestion.value != text;
            return _shell(
              context,
              onTap: () => setState(() => _editing = true),
              trailing: showCalc
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: valueText),
                        const SizedBox(width: 6),
                        Tooltip(
                          message: suggestion.tooltip,
                          child: InkWell(
                            onTap: suggestion.onUse,
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(
                                Icons.calculate_outlined,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : valueText,
            );
          },
        );

      case _RowKind.picker:
        final empty = widget.value == null || widget.value!.isEmpty;
        return _shell(
          context,
          onTap: widget.onTap,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  empty ? (widget.placeholder ?? '') : widget.value!,
                  style: _valueTextStyle(context, muted: empty),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.onClear != null && !empty) ...[
                const SizedBox(width: 4),
                _clearAffordance(context, widget.onClear!),
              ],
              Icon(
                Icons.chevron_right,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        );

      case _RowKind.display:
        return _shell(
          context,
          trailing: Text(
            widget.value ?? '',
            style: _valueTextStyle(context, muted: true),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );

      case _RowKind.toggle:
        return _shell(
          context,
          trailing: Switch(
            value: widget.boolValue!,
            onChanged: widget.enabled ? widget.onBoolChanged : null,
          ),
        );

      case _RowKind.rating:
        final rating = widget.intValue!;
        // Zero stars is a real answer, not the absence of one, so the row keeps
        // two ways back to it: re-tapping the star that already holds the
        // rating (what divers reach for first), and the explicit clear icon.
        // Both go through the same callback, so a caller whose onClear does
        // extra bookkeeping cannot have it skipped by the gesture it did not
        // anticipate.
        final clear = widget.onClear ?? () => widget.onIntChanged!(0);
        return _shell(
          context,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...List.generate(5, (i) {
                final stars = i + 1;
                final filled = i < rating;
                return InkWell(
                  onTap: () =>
                      stars == rating ? clear() : widget.onIntChanged!(stars),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      filled ? Icons.star : Icons.star_border,
                      size: 22,
                      color: filled
                          ? Colors.amber
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }),
              if (rating > 0) ...[
                const SizedBox(width: 4),
                _clearAffordance(context, clear),
              ],
            ],
          ),
        );

      case _RowKind.custom:
        return _shell(context, trailing: widget.child!);
    }
  }

  /// The bare X shared by the picker and rating rows. Wrapped in a [Tooltip]
  /// only when the caller named it, so rows that never supplied a label keep
  /// rendering exactly as before.
  Widget _clearAffordance(BuildContext context, VoidCallback onTap) {
    final button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(FormStyle.clearTapTarget / 2),
      child: SizedBox(
        width: FormStyle.clearTapTarget,
        height: FormStyle.clearTapTarget,
        child: Icon(
          Icons.clear,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
    final tooltip = widget.clearTooltip;
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}
