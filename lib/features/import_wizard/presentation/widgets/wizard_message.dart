import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/l10n/l10n_extension.dart';

final _log = LoggerService.forClass(WizardMessage);

/// Inline message strip shown between a wizard step's content and its
/// bottom bar.
///
/// The text can be selected, and an error has a copy button, so a diver can
/// paste it into a report rather than screenshot it (#3629).
class WizardMessage extends StatelessWidget {
  const WizardMessage({
    super.key,
    required this.message,
    required this.icon,
    required this.isError,
  });

  final String message;
  final IconData icon;
  final bool isError;

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await Clipboard.setData(ClipboardData(text: message));
    } on PlatformException catch (e, stackTrace) {
      _log.error(
        'Could not copy to the clipboard',
        error: e,
        stackTrace: stackTrace,
      );
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.common_error_tryAgain)),
        );
      }
      return;
    }
    if (messenger.mounted) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.common_snackbar_copiedToClipboard)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = isError
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onTertiaryContainer;

    return Container(
      width: double.infinity,
      color: isError
          ? theme.colorScheme.errorContainer
          : theme.colorScheme.tertiaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Icon(icon, size: 20, color: foreground)),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: foreground),
            ),
          ),
          if (isError) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: context.l10n.common_action_copy,
              onPressed: () => _copy(context),
              iconSize: 18,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              color: foreground,
              icon: const Icon(Icons.content_copy),
            ),
          ],
        ],
      ),
    );
  }
}
