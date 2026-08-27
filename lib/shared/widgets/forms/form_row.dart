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
       value = null,
       onTap = null,
       onClear = null,
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
  }) : _kind = _RowKind.picker,
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
      profileSuggestion = null,
      decoration = null,
      controller = null,
      inputFormatters = null,
      onClear = null,
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

  const FormRow.toggle({
    super.key,
    required this.label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) : _kind = _RowKind.toggle,
       profileSuggestion = null,
       decoration = null,
       inputFormatters = null,
       onClear = null,
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
  }) : _kind = _RowKind.rating,
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
      profileSuggestion = null,
      decoration = null,
      controller = null,
      inputFormatters = null,
      onClear = null,
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
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
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
                InkWell(
                  onTap: widget.onClear,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.clear,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
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
            onChanged: widget.onBoolChanged,
          ),
        );

      case _RowKind.rating:
        return _shell(
          context,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...List.generate(5, (i) {
                final filled = i < widget.intValue!;
                return InkWell(
                  onTap: () => widget.onIntChanged!(i + 1),
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
              if (widget.onClear != null && widget.intValue! > 0) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: widget.onClear,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.clear,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );

      case _RowKind.custom:
        return _shell(context, trailing: widget.child!);
    }
  }
}
