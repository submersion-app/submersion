import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/features/shared_library/domain/storage_policy_examples.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// How to set up the storage for a shared site library (issue #2567): where
/// it lives, the two kinds of keys, and copyable example policies.
Future<void> showStorageSetupSheet(
  BuildContext context, {
  required String bucket,
  required String folder,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (sheetContext) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.85,
    maxChildSize: 0.95,
    builder: (_, controller) =>
        _SetupGuide(controller: controller, bucket: bucket, folder: folder),
  ),
);

class _SetupGuide extends StatelessWidget {
  const _SetupGuide({
    required this.controller,
    required this.bucket,
    required this.folder,
  });

  final ScrollController controller;
  final String bucket;
  final String folder;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final where = folder.trim().replaceAll(RegExp(r'^/+|/+$'), '').trim();
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(l10n.sharedLibrary_setup_title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(
          l10n.sharedLibrary_setup_where(
            where.isEmpty ? 'submersion-sites/' : 'submersion-sites/$where/',
          ),
        ),
        const SizedBox(height: 8),
        Text(l10n.sharedLibrary_setup_keys),
        const SizedBox(height: 16),
        _Policy(
          copyKey: const Key('copy-full-policy'),
          title: l10n.sharedLibrary_setup_s3Full,
          policy: s3FullAccessPolicy(bucket: bucket, folder: folder),
        ),
        const SizedBox(height: 16),
        _Policy(
          copyKey: const Key('copy-reader-policy'),
          title: l10n.sharedLibrary_setup_s3Reader,
          policy: s3ReaderPolicy(bucket: bucket, folder: folder),
        ),
        const SizedBox(height: 16),
        Text(l10n.sharedLibrary_setup_webdav),
      ],
    );
  }
}

class _Policy extends StatelessWidget {
  const _Policy({
    required this.copyKey,
    required this.title,
    required this.policy,
  });

  final Key copyKey;
  final String title;
  final String policy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
            TextButton.icon(
              key: copyKey,
              icon: const Icon(Icons.copy, size: 18),
              label: Text(l10n.sharedLibrary_setup_copy),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: policy));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.sharedLibrary_setup_copied)),
                );
              },
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            policy,
            style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }
}
