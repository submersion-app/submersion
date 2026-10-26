import 'package:flutter/material.dart';

import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// Modal sheet for entering a time-shift offset (pre-filled with the detected
/// value). [widenLabel], when given, adds a checkbox that applies the same
/// shift beyond the one finding: the whole import for a logbook shift, every
/// dive of the computer for a source clock fix (#3655). `widen` reports it.
Future<({Duration offset, bool widen})?> showTimeShiftSheet(
  BuildContext context, {
  required Duration suggestedOffset,
  String? widenLabel,
}) {
  final controller = TextEditingController(
    text: suggestedOffset == Duration.zero
        ? ''
        : formatDecimalForInput(suggestedOffset.inHours.toDouble()),
  );
  var widen = false;
  final formKey = GlobalKey<FormState>();
  return showModalBottomSheet<({Duration offset, bool widen})>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      final l10n = context.l10n;
      return StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Form(
                key: formKey,
                child: TextFormField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                  ),
                  validator: numberValidator(context, integer: true),
                  decoration: InputDecoration(
                    labelText: l10n.dataQuality_repairLabel_shiftTime('h'),
                  ),
                ),
              ),
              if (widenLabel != null)
                CheckboxListTile(
                  value: widen,
                  onChanged: (v) => setSheetState(() => widen = v ?? false),
                  title: Text(widenLabel),
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  // Unreadable hours used to apply no shift and report
                  // success (#1900).
                  if (!formKey.currentState!.validate()) return;
                  final hours = switch (readNumber(
                    controller.text,
                    integer: true,
                  )) {
                    NumberValue(:final value) => value.toInt(),
                    // Blank applies no shift, as before; invalid cannot
                    // reach here, the form having validated above.
                    NumberBlank() || NumberInvalid() => 0,
                  };
                  Navigator.of(
                    context,
                  ).pop((offset: Duration(hours: hours), widen: widen));
                },
                child: Text(MaterialLocalizations.of(context).okButtonLabel),
              ),
            ],
          ),
        ),
      );
    },
  );
}
