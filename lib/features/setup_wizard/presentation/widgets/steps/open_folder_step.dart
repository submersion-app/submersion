import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/storage_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/main.dart' show restartApp;

/// Points the app at a folder that already contains a Submersion database.
class OpenFolderStep extends ConsumerStatefulWidget {
  const OpenFolderStep({super.key});

  @override
  ConsumerState<OpenFolderStep> createState() => _OpenFolderStepState();
}

class _OpenFolderStepState extends ConsumerState<OpenFolderStep> {
  bool _busy = false;
  String? _error;

  Future<void> _pickFolder() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final l10n = context.l10n;
    try {
      final notifier = ref.read(storageConfigNotifierProvider.notifier);
      final picked = await notifier.pickCustomFolder();
      if (picked == null) return;

      final existing = await notifier.checkForExistingDatabase(picked.path);
      if (existing == null) {
        setState(() => _error = l10n.setup_folder_notFound_message);
        return;
      }

      final result = await notifier.switchToExistingDatabase(picked.path);
      if (result.success) {
        // Full provider rebuild: the swapped database has divers, so the
        // relaunch lands on the dashboard.
        restartApp();
      } else {
        setState(() => _error = result.errorMessage ?? '');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.setup_folder_title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          if (_busy) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(l10n.setup_folder_switching),
          ] else ...[
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: _pickFolder,
              icon: const Icon(Icons.folder_open),
              label: Text(l10n.setup_folder_pick),
            ),
          ],
        ],
      ),
    );
  }
}
