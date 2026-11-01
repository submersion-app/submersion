import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/record_list_card.dart';

/// One track entry's card, shared by [GpsTrackListTile] and
/// [NavTrackListRow] so both kinds of entry in the Tracks list look and
/// react like a dive entry (#4101): the same [RecordListCard], the same
/// highlight fill, and the dive card's text colours for the [ListTile]
/// [builder] returns. [builder] receives those colours for anything the
/// tile theme does not reach, such as the stat row's accent.
///
/// The tile inside takes the dive card's 12px inner padding instead of
/// ListTile's 16/24: the card's own 16px side margin would otherwise leave
/// a German "Tauchgang #412" link chip too little width on a narrow phone
/// and squeeze it into an ellipsis (#2692, #3749), which is why #4038 had
/// dropped that margin.
class TrackListCard extends StatelessWidget {
  const TrackListCard({
    super.key,
    required this.selected,
    required this.onTap,
    required this.builder,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget Function(BuildContext context, RecordCardColors colors) builder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fill = selected ? recordCardSelectionFill(theme.colorScheme) : null;
    final colors = RecordCardColors.forFill(theme.colorScheme, fill);
    return RecordListCard(
      color: fill,
      onTap: onTap,
      child: ListTileTheme.merge(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        // The dive card's title and date line.
        titleTextStyle: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: colors.primaryText,
        ),
        subtitleTextStyle: theme.textTheme.bodyMedium?.copyWith(
          color: colors.secondaryText,
        ),
        iconColor: colors.secondaryText,
        child: Builder(builder: (context) => builder(context, colors)),
      ),
    );
  }
}
