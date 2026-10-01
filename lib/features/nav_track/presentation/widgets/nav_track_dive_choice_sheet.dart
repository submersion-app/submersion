import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Shows [NavTrackDiveChoiceSheet] for [dives] and resolves to the dive the
/// diver tapped, or null when the sheet was dismissed without a choice.
///
/// The one "pick a dive for this route" sheet: the routes-area detail
/// page's "Choose dive" and the import review page's "Choose another
/// dive..." both open it with `NavTrackMatcher.nearestByStart`'s list, so
/// the two never offer different dives for the same recording.
Future<Dive?> showNavTrackDiveChoiceSheet(
  BuildContext context, {
  required List<Dive> dives,
  String? selectedDiveId,
}) {
  return showModalBottomSheet<Dive>(
    context: context,
    builder: (sheetContext) => NavTrackDiveChoiceSheet(
      dives: dives,
      selectedDiveId: selectedDiveId,
      onDiveSelected: (dive) => Navigator.of(sheetContext).pop(dive),
    ),
  );
}

/// A list of [dives], in the order given, each shown by number and entry
/// date/time in the diver's own formats; [selectedDiveId] is marked.
class NavTrackDiveChoiceSheet extends ConsumerWidget {
  const NavTrackDiveChoiceSheet({
    super.key,
    required this.dives,
    required this.onDiveSelected,
    this.selectedDiveId,
  });

  final List<Dive> dives;
  final String? selectedDiveId;
  final ValueChanged<Dive> onDiveSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    return ListView(
      shrinkWrap: true,
      children: [
        for (final dive in dives)
          ListTile(
            key: ValueKey('nav-track-dive-choice-${dive.id}'),
            selected: dive.id == selectedDiveId,
            title: Text(
              l10n.navTrack_common_diveNumber(
                (dive.diveNumber ?? dive.id).toString(),
              ),
            ),
            subtitle: Text(
              units.formatDateTime(dive.effectiveEntryTime, l10n: l10n),
            ),
            trailing: dive.id == selectedDiveId
                ? const Icon(Icons.check)
                : null,
            onTap: () => onDiveSelected(dive),
          ),
      ],
    );
  }
}
