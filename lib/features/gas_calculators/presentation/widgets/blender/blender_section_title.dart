import 'package:flutter/material.dart';

/// The heading style shared by every blender card section.
class BlenderSectionTitle extends StatelessWidget {
  const BlenderSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
  );
}
