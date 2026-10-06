import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/weight_label.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The optional name of a weight row (issue #956), shared by the dive editor
/// and the weight preset editor. The counter appears only in the last
/// [_counterThreshold] characters before [weightLabelMaxLength].
class WeightLabelField extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final ValueChanged<String>? onChanged;

  const WeightLabelField({
    super.key,
    this.controller,
    this.initialValue,
    this.onChanged,
  }) : assert(controller == null || initialValue == null);

  static const _counterThreshold = 20;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: l10n.diveLog_edit_label_weightName,
        hintText: l10n.diveLog_edit_hint_weightName,
        isDense: true,
      ),
      maxLength: weightLabelMaxLength,
      buildCounter:
          (
            context, {
            required currentLength,
            required isFocused,
            required maxLength,
          }) => currentLength < weightLabelMaxLength - _counterThreshold
          ? null
          : Text('$currentLength/$maxLength'),
      textCapitalization: TextCapitalization.sentences,
      onChanged: onChanged,
    );
  }
}
