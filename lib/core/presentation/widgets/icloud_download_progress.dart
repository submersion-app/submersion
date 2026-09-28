import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Shown under the splash logo while iCloud fetches the dive log (issue
/// #2177). Indeterminate: iCloud reports no percentage that a coordinated
/// read can see.
class ICloudDownloadProgress extends StatelessWidget {
  const ICloudDownloadProgress({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LinearProgressIndicator(
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
        ),
        const SizedBox(height: 12),
        Text(
          context.l10n.startup_diveLogUnavailable_downloading,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.8),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
