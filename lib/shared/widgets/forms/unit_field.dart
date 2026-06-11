import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Boxed numeric input with a unit suffix, for dense clusters inside
/// expanded editors (tank pressures, weights). Unit symbols always come
/// from UnitFormatter at the call site - never hard-code them.
class UnitField extends StatelessWidget {
  const UnitField({
    super.key,
    required this.controller,
    required this.label,
    required this.unitSymbol,
    this.validator,
    this.onChanged,
    this.allowDecimal = true,
    this.helperText,
  });

  final TextEditingController controller;
  final String label;
  final String unitSymbol;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool allowDecimal;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
      inputFormatters: [
        // keyboardType is only a hint; enforce numeric input against
        // paste and desktop/physical keyboards.
        allowDecimal
            ? FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
            : FilteringTextInputFormatter.digitsOnly,
      ],
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        suffixText: unitSymbol,
        helperText: helperText,
        isDense: true,
      ),
    );
  }
}
