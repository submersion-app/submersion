import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/unfilled_dive_chip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Lets the diver pick which planned dive a download fills (issue #2002).
/// Returns the dive id, an empty string for "import as new", or null when
/// dismissed.
///
/// [unavailableIds] are plans another download in the same batch already
/// fills. One plan can take only one download, so they are left out, except
/// for [selectedId]: that is this row's own target. [leadingIds] come first,
/// in their own order: the drafts a download fits (issue #637), so a diver
/// choosing between them finds them at the top.
Future<String?> showPlannedDivePicker(
  BuildContext context, {
  required List<Dive> plannedDives,
  String? selectedId,
  Set<String> unavailableIds = const {},
  List<String> leadingIds = const [],
}) {
  final ordered = [
    for (final id in leadingIds) ...plannedDives.where((d) => d.id == id),
    for (final dive in plannedDives)
      if (!leadingIds.contains(dive.id)) dive,
  ];
  return showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final units = ref.watch(unitFormatterProvider);
        final l10n = context.l10n;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.universalImport_fillPlanned_pickerTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              for (final dive in ordered)
                if (dive.id == selectedId || !unavailableIds.contains(dive.id))
                  ListTile(
                    key: Key('planned_dive_picker_${dive.id}'),
                    leading: Icon(
                      unfilledDiveIcon(
                        unfilledDiveStateOf(
                              isPlanned: dive.isPlanned,
                              isDraft: dive.isDraft,
                            ) ??
                            UnfilledDiveState.planned,
                      ),
                    ),
                    title: Text(plannedDiveLabel(dive, units, l10n)),
                    trailing: dive.id == selectedId
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.pop(sheetContext, dive.id),
                  ),
              const Divider(),
              ListTile(
                key: const Key('planned_dive_picker_import_as_new'),
                leading: const Icon(Icons.add),
                title: Text(l10n.universalImport_fillPlanned_importAsNew),
                onTap: () => Navigator.pop(sheetContext, ''),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// "Blue Hole, 1 Jun 2026 at 09:00", or the date alone when the dive has
/// neither a name nor a site. A draft (issue #637) reads by its taps, "Draft
/// from 1 Jun 2026 at 10:02 to 10:54", so two drafts of a day differ.
String plannedDiveLabel(Dive dive, UnitFormatter units, AppLocalizations l10n) {
  var when = units.formatDateTime(dive.entryTime ?? dive.dateTime, l10n: l10n);
  if (dive.isDraft) {
    final exit = dive.exitTime;
    when = exit == null
        ? l10n.universalImport_fillDraft_windowOpen(when)
        : l10n.universalImport_fillDraft_window(when, units.formatTime(exit));
  }
  final name = dive.name?.trim();
  final site = dive.site?.name.trim();
  final label = (name != null && name.isNotEmpty) ? name : site;
  return label == null || label.isEmpty ? when : '$label, $when';
}
