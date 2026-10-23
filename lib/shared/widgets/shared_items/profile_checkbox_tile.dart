import 'package:flutter/material.dart';

import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

/// One profile's checkbox in a profile picker: its avatar and name. Used by
/// the equipment checklist (issue #2046) and the trip and site share dialog
/// (issue #2151).
class ProfileCheckboxTile extends StatelessWidget {
  const ProfileCheckboxTile({
    super.key,
    required this.diver,
    required this.value,
    required this.onChanged,
  });

  final Diver diver;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      secondary: ProfileAvatar(
        photo: diver.photo,
        initials: diver.initials,
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
      ),
      title: Text(diver.name),
      onChanged: (checked) => onChanged(checked == true),
    );
  }
}
