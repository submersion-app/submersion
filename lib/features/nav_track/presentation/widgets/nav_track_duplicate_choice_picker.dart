import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// What the review page does with a file whose recording is already stored
/// (issue #4231).
enum NavTrackDuplicateChoice {
  /// Re-read the stored route's data from this file and keep its settings.
  update,

  /// Store this file as a route of its own.
  newTrack,
}

/// Update the stored route from this file, or store it as a new one
/// (issue #4231). Updating is first: re-reading the same recording is what
/// a duplicate almost always is.
class NavTrackDuplicateChoicePicker extends StatelessWidget {
  const NavTrackDuplicateChoicePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final NavTrackDuplicateChoice value;
  final ValueChanged<NavTrackDuplicateChoice> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return RadioGroup<NavTrackDuplicateChoice>(
      groupValue: value,
      onChanged: (choice) {
        if (choice != null) onChanged(choice);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RadioListTile<NavTrackDuplicateChoice>(
            key: const ValueKey('nav-track-duplicate-update'),
            value: NavTrackDuplicateChoice.update,
            dense: true,
            title: Text(l10n.navTrack_review_duplicateUpdate),
            subtitle: Text(l10n.navTrack_review_duplicateUpdateHint),
          ),
          RadioListTile<NavTrackDuplicateChoice>(
            key: const ValueKey('nav-track-duplicate-new'),
            value: NavTrackDuplicateChoice.newTrack,
            dense: true,
            title: Text(l10n.navTrack_review_duplicateNew),
          ),
        ],
      ),
    );
  }
}
