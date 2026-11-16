import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// An open card whose rows could not be read for the sitting (issue #4527):
/// says so and offers to read them again, where a spinner would otherwise
/// wait for rows that are not coming.
class SittingLoadFailed extends StatelessWidget {
  const SittingLoadFailed({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.recordEdit_loadFailed, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: Text(l10n.recordEdit_tryAgain)),
        ],
      ),
    );
  }
}
