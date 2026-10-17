import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Progress of a documents export: files written so far and in total.
typedef DocumentExportProgress = ({int done, int total});

/// Shows how far a documents export has got, with a Cancel button. It cannot
/// be dismissed any other way; the flow that opened it closes it.
class DocumentExportProgressDialog extends StatelessWidget {
  final ValueListenable<DocumentExportProgress> progress;
  final VoidCallback onCancel;

  const DocumentExportProgressDialog({
    super.key,
    required this.progress,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(l10n.documents_export_title),
        content: ValueListenableBuilder<DocumentExportProgress>(
          valueListenable: progress,
          builder: (context, p, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(
                value: p.total == 0 ? null : p.done / p.total,
              ),
              const SizedBox(height: 12),
              Text(l10n.documents_export_progress(p.done, p.total)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: onCancel,
            child: Text(l10n.documents_export_cancel),
          ),
        ],
      ),
    );
  }
}
