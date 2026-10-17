import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/shared_library/library_details_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/shared_library/presentation/providers/library_connection_providers.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_error_text.dart';
import 'package:submersion/l10n/l10n_extension.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = membership;
    final owner = role == SharedLibraryRole.owner && me != null;
    final description = library.description;
    if (!owner && description == null) return const SizedBox.shrink();
    return ListTile(
      leading: const Icon(Icons.info_outline),
      title: Text(context.l10n.sharedLibrary_about_title),
      subtitle: description == null ? null : Text(description),
      trailing: owner ? const Icon(Icons.edit_outlined) : null,
      onTap: owner ? () => _edit(context, ref, me) : null,
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    SharedLibraryMembership me,
  ) async {
    final edited = await showDialog<({String name, String description})>(
      context: context,
      builder: (_) => _DetailsDialog(library: library),
    );
    if (edited == null || !context.mounted) return;
    try {
      await ref
          .read(libraryDetailsServiceProvider)
          .save(
            libraryId: library.id,
            diverId: me.diverId,
            name: edited.name,
            description: edited.description,
          );
    } catch (e) {
      // Written to the library folder: offline, or with keys that only
      // read, it fails and nothing changes here.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(libraryErrorText(context.l10n, e))),
        );
      }
    }
  }
}

class _DetailsDialog extends StatefulWidget {
  const _DetailsDialog({required this.library});

  final SharedLibrary library;

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

  void _save() {
    if (!(_form.currentState?.validate() ?? false)) return;
    Navigator.of(
      context,
    ).pop((name: _name.text.trim(), description: _description.text.trim()));
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
              TextFormField(
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.common_action_save)),
      ],
    );
  }
}
