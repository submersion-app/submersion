import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/shared_library/library_details_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/shared_library/presentation/providers/library_connection_providers.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_error_text.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';
import 'package:submersion/core/text/markdown/notes_plain_text.dart';

/// The library's description, which an owner edits with its name
/// (issue #3389). Every member's device reads both at its next sync.
class LibraryAboutSection extends ConsumerWidget {
  const LibraryAboutSection({
    super.key,
    required this.library,
    required this.role,
    required this.membership,
  });

  final SharedLibrary library;
  final SharedLibraryRole role;
  final SharedLibraryMembership? membership;

  /// Lines of the description shown on the page: any member's storage keys
  /// can write it, so a long one never floods the page.
  static const descriptionLines = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = membership;
    final owner = role == SharedLibraryRole.owner && me != null;
    final description = library.description;
    if (!owner && description == null) return const SizedBox.shrink();
    return ListTile(
      leading: const Icon(Icons.info_outline),
      title: Text(context.l10n.sharedLibrary_about_title),
      subtitle: description == null
          ? null
          : Text(
              markdownToPlainText(description),
              maxLines: descriptionLines,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: owner ? const Icon(Icons.edit_outlined) : null,
      onTap: owner ? () => _edit(context, ref, me) : null,
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    SharedLibraryMembership me,
  ) async {
    final details = ref.read(libraryDetailsServiceProvider);
    await showDialog<void>(
      context: context,
      builder: (_) => _DetailsDialog(
        library: library,
        // Written to the library folder: offline, or with keys that only
        // read, it fails, and the dialog stays open with what was typed.
        onSave: (name, description) => details.save(
          libraryId: library.id,
          diverId: me.diverId,
          name: name,
          description: description,
        ),
      ),
    );
  }
}

class _DetailsDialog extends StatefulWidget {
  const _DetailsDialog({required this.library, required this.onSave});

  final SharedLibrary library;
  final Future<void> Function(String name, String description) onSave;

  @override
  State<_DetailsDialog> createState() => _DetailsDialogState();
}

class _DetailsDialogState extends State<_DetailsDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.library.name);
  late final _description = TextEditingController(
    text: widget.library.description ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_name.text.trim(), _description.text.trim());
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = libraryErrorText(context.l10n, e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.sharedLibrary_about_edit_title),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                maxLength: LibraryDetailsService.maxNameLength,
                decoration: InputDecoration(
                  labelText: l10n.sharedLibrary_about_name_label,
                ),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? l10n.sharedLibrary_about_nameRequired
                    : null,
              ),
              const SizedBox(height: 8),
              MarkdownNotesField(
                controller: _description,
                minLines: 2,
                maxLines: 5,
                maxLength: LibraryDetailsService.maxDescriptionLength,
                decoration: InputDecoration(
                  labelText: l10n.sharedLibrary_about_description_label,
                  helperText: l10n.sharedLibrary_about_description_help,
                  helperMaxLines: 3,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(l10n.common_action_save),
        ),
      ],
    );
  }
}
