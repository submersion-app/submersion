import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Prompts for a smart album name.
///
/// Resolves to the trimmed name, or null when the diver cancels. Save stays
/// disabled while the trimmed field is empty, so an unnamed album can never
/// be created.
Future<String?> showMediaSmartAlbumNameDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _AlbumNameDialog(),
  );
}

/// Stateful so the controller lives and dies with the dialog subtree: the
/// dialog outlives its showDialog future by the length of the exit
/// animation, and disposing from the caller crashes those trailing frames.
class _AlbumNameDialog extends StatefulWidget {
  const _AlbumNameDialog();

  @override
  State<_AlbumNameDialog> createState() => _AlbumNameDialogState();
}

class _AlbumNameDialogState extends State<_AlbumNameDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.media_smartAlbum_saveTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _confirm(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: _controller.text.trim().isEmpty ? null : _confirm,
          child: Text(context.l10n.common_action_save),
        ),
      ],
    );
  }
}
