import 'package:flutter/material.dart';

/// A short list of values to pick one from, the current one checked; null
/// when the diver backs out.
Future<T?> showBackupChoiceDialog<T>(
  BuildContext context, {
  required String title,
  required List<T> values,
  required T selected,
  required String Function(T value) label,
}) => showDialog<T>(
  context: context,
  builder: (context) => SimpleDialog(
    title: Text(title),
    children: [
      for (final value in values)
        ListTile(
          title: Text(label(value)),
          selected: value == selected,
          trailing: value == selected ? const Icon(Icons.check) : null,
          onTap: () => Navigator.of(context).pop(value),
        ),
    ],
  ),
);
