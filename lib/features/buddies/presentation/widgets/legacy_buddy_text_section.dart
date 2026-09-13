import 'package:flutter/material.dart';

import 'package:submersion/features/buddies/domain/services/legacy_name_parser.dart';
import 'package:submersion/features/buddies/presentation/legacy_buddy_conversion_actions.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Buddies card's legacy text (#1831): plain tiles for a dive's
/// `buddy` and `dive_master` text and the action that links them to buddy
/// records. Shown only while the dive has no linked buddies.
class LegacyBuddyTextSection extends StatelessWidget {
  const LegacyBuddyTextSection({super.key, required this.dive});

  final Dive dive;

  /// Whether [dive] has legacy text that parses to at least one name. A
  /// text holding only a placeholder such as `None` does not count.
  static bool hasContent(Dive dive) =>
      LegacyNameParser.parse(dive.buddy).isNotEmpty ||
      LegacyNameParser.parse(dive.diveMaster).isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final showBuddy = LegacyNameParser.parse(dive.buddy).isNotEmpty;
    final showDiveMaster = LegacyNameParser.parse(dive.diveMaster).isNotEmpty;
    if (!showBuddy && !showDiveMaster) return const SizedBox.shrink();

    // There is no record behind the text yet, so the tile opens nothing.
    Widget tile(String text, {String? subtitle}) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: colorScheme.primaryContainer,
        child: Icon(
          Icons.person_outline,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(text),
      subtitle: subtitle == null ? null : Text(subtitle),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showBuddy) tile(dive.buddy!.trim()),
        if (showDiveMaster)
          tile(
            dive.diveMaster!.trim(),
            subtitle: l10n.diveRole_builtin_diveMaster,
          ),
        TextButton.icon(
          onPressed: () => linkLegacyBuddiesForDive(context, dive),
          icon: const Icon(Icons.link),
          label: Text(l10n.buddies_linkText_action),
        ),
      ],
    );
  }
}
