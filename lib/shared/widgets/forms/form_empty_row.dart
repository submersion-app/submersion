import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/forms/form_style.dart';

/// Quiet one-line empty state inside a section body ("No equipment yet").
/// Never pair with icons or instruction paragraphs; the relevant actions
/// belong on the group's [FormOverline].
class FormEmptyRow extends StatelessWidget {
  const FormEmptyRow({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: FormStyle.rowPadding,
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
          color: FormStyle.invitationColor(context),
        ),
      ),
    );
  }
}
