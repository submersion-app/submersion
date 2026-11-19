import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';

/// The top bar of a satellite page (a passport, the cylinder board) that
/// joined its record's sitting (issue #4527, phase 3): the title and Done.
///
/// The changes made here belong to the record's sitting, which the record's
/// own page saves or cancels, so there is no Cancel or Save here. It is
/// tinted and underlined as [RecordEditBar] is, so the page reads as
/// unlocked, and like it has no back arrow.
class RecordSatelliteBar extends StatelessWidget
    implements PreferredSizeWidget {
  const RecordSatelliteBar({
    super.key,
    required this.title,
    required this.onDone,
  });

  final String title;
  final VoidCallback onDone;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final style = unlockedRecordBarStyle(Theme.of(context).colorScheme);
    return AppBar(
      automaticallyImplyLeading: false,
      scrolledUnderElevation: 0,
      backgroundColor: style.background,
      foregroundColor: style.foreground,
      shape: style.shape,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        AppBarTextAction(
          label: context.l10n.common_action_done,
          onPressed: onDone,
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
