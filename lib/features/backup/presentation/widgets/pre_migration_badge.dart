import 'package:flutter/material.dart';

/// Small "vFrom → vTo" badge used on pre-migration backup history rows.
class PreMigrationBadge extends StatelessWidget {
  final int fromVersion;
  final int toVersion;

  const PreMigrationBadge({
    super.key,
    required this.fromVersion,
    required this.toVersion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'v$fromVersion \u2192 v$toVersion',
        style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
