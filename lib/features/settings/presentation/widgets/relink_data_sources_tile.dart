import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/data_row_tile.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings > Data tools > Relink data sources (issue #4465): links the
/// downloaded data sources that lost their dive computer, when its entry was
/// deleted, back to the computer they came from. A one-tap repair after a
/// confirmation, so it runs in place rather than on a page of its own. A tap
/// while it runs is ignored.
class RelinkDataSourcesTile extends ConsumerStatefulWidget {
  const RelinkDataSourcesTile({super.key});

  @override
  ConsumerState<RelinkDataSourcesTile> createState() =>
      _RelinkDataSourcesTileState();
}

class _RelinkDataSourcesTileState extends ConsumerState<RelinkDataSourcesTile> {
  bool _running = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DataRowTile(
      icon: Icons.link,
      title: l10n.settings_relinkSources_title,
      subtitle: l10n.settings_relinkSources_subtitle,
      onTap: _relink,
    );
  }

  Future<void> _relink() async {
    if (_running) return;
    _running = true;
    try {
      if (!await _confirm() || !mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      // showDialog pushes onto the root navigator, but this page sits in the
      // app's ShellRoute, whose nearest navigator is the shell's: popping
      // that one would close the page and strand the progress dialog.
      final navigator = Navigator.of(context, rootNavigator: true);
      final l10n = context.l10n;
      // A library-wide relink can take a while: say so, and keep the page
      // from taking another tap until it is done.
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => PopScope(
            canPop: false,
            child: AlertDialog(
              content: Row(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 24),
                  Expanded(child: Text(l10n.settings_relinkSources_title)),
                ],
              ),
            ),
          ),
        ),
      );
      String message;
      try {
        final linked = await ref
            .read(diveComputerRepositoryProvider)
            .relinkOrphanedSources();
        message = l10n.settings_relinkSources_result(linked);
      } catch (_) {
        // The repository has logged the cause; the relink ran in one
        // transaction, so the diver only needs to know nothing changed.
        message = l10n.settings_relinkSources_failed;
      }
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } finally {
      _running = false;
    }
  }

  Future<bool> _confirm() async {
    final l10n = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settings_relinkSources_title),
        content: Text(l10n.settings_relinkSources_confirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.settings_relinkSources_confirmApply),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
