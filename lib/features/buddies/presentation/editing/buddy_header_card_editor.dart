import 'package:flutter/material.dart';

import 'package:submersion/features/buddies/data/services/contact_photo_loader.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_edit_fields.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/utils/contact_import_support.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_photo_picker.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/field_text_binding.dart';

/// The buddy header block's editor (issue #4527, phase 3): the photo, the
/// name, which is required, and the favourite star.
class BuddyHeaderCardEditor extends StatefulWidget {
  const BuddyHeaderCardEditor({super.key, required this.session});

  final EditSession<Buddy> session;

  @override
  State<BuddyHeaderCardEditor> createState() => _BuddyHeaderCardEditorState();
}

class _BuddyHeaderCardEditorState extends State<BuddyHeaderCardEditor> {
  EditSession<Buddy> get _session => widget.session;

  late final _name = FieldTextBinding<Buddy, String>(
    session: _session,
    field: buddyNameField,
    format: (v) => v,
    parse: FieldValue<String>.new,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final result = await pickProfilePhoto(
      context: context,
      hasPhoto: _session.valueOf(buddyPhotoField) != null,
      allowContacts: isContactImportSupported,
      contactPhotoLoader: loadContactPhoto,
    );
    if (result == null || _session.isDisposed) return;
    _session.set(buddyPhotoField, result.removed ? null : result.bytes);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        final name = _session.valueOf(buddyNameField);
        final favorite = _session.valueOf(buddyFavoriteField);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Semantics(
                button: true,
                label: l10n.profilePhoto_sheet_title,
                child: InkWell(
                  key: const ValueKey('buddy-edit-photo'),
                  customBorder: const CircleBorder(),
                  onTap: _pickPhoto,
                  child: Stack(
                    children: [
                      ProfileAvatar(
                        photo: _session.valueOf(buddyPhotoField),
                        // As the page draws them.
                        initials: _session.working.initials,
                        radius: 50,
                        textStyle: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: ExcludeSemantics(
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: theme.colorScheme.primary,
                            child: Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('buddy-edit-name'),
                    controller: _name.controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: l10n.buddies_field_nameRequired,
                      prefixIcon: const Icon(Icons.person),
                      hintText: l10n.buddies_field_nameHint,
                      errorText: buddyNameValid(name)
                          ? null
                          : l10n.buddies_validation_nameRequired,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('buddy-edit-favorite'),
                  icon: Icon(
                    favorite ? Icons.star : Icons.star_border,
                    color: favorite ? theme.colorScheme.primary : null,
                  ),
                  tooltip: favorite
                      ? l10n.diveLog_detail_tooltip_removeFromFavorites
                      : l10n.diveLog_detail_tooltip_addToFavorites,
                  onPressed: () => _session.set(buddyFavoriteField, !favorite),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
