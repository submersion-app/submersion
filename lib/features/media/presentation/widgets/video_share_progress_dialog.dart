import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/features/media/presentation/helpers/share_preparation.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Shown while a share re-encodes colour-corrected videos (issue #3521):
/// which video of how many, how far along, and Cancel. Back cancels too,
/// so the encode is never left running under a dismissed dialog.
class VideoShareProgressDialog extends StatefulWidget {
  const VideoShareProgressDialog({
    super.key,
    required this.progress,
    required this.onCancel,
  });

  final ValueListenable<VideoShareProgress> progress;
  final VoidCallback onCancel;

  @override
  State<VideoShareProgressDialog> createState() =>
      _VideoShareProgressDialogState();
}

class _VideoShareProgressDialogState extends State<VideoShareProgressDialog> {
  var _cancelled = false;

  void _cancel() {
    if (_cancelled) return;
    setState(() => _cancelled = true);
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: ValueListenableBuilder<VideoShareProgress>(
        valueListenable: widget.progress,
        builder: (context, progress, _) {
          final fraction = progress.fraction;
          return AlertDialog(
            title: Text(
              progress.total > 1
                  ? l10n.media_share_preparingVideoOf(
                      progress.index,
                      progress.total,
                    )
                  : l10n.media_share_preparingVideo,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                LinearProgressIndicator(value: fraction),
                const SizedBox(height: 8),
                Text(
                  fraction == null ? '' : '${(fraction * 100).round()}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: _cancelled ? null : _cancel,
                child: Text(l10n.common_action_cancel),
              ),
            ],
          );
        },
      ),
    );
  }
}
