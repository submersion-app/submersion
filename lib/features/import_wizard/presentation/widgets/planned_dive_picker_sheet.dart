import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Lets the diver pick which planned dive a download fills (issue #2002).
/// Returns the dive id, an empty string for "import as new", or null when
/// dismissed.
///
/// [unavailableIds] are plans another download in the same batch already
/// fills. One plan can take only one download, so they are left out, except
/// for [selectedId]: that is this row's own target.
Future<String?> showPlannedDivePicker(
  BuildContext context, {
  required List<Dive> plannedDives,
  String? selectedId,
  Set<String> unavailableIds = const {},
}) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final units = UnitFormatter(ref.watch(settingsProvider));
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
              for (final dive in plannedDives)
                if (dive.id == selectedId || !unavailableIds.contains(dive.id))
                  ListTile(
                    key: Key('planned_dive_picker_${dive.id}'),
                    leading: const Icon(Icons.event_available_outlined),
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
/// neither a name nor a site.
String plannedDiveLabel(Dive dive, UnitFormatter units, AppLocalizations l10n) {
  final when = units.formatDateTime(
    dive.entryTime ?? dive.dateTime,
    l10n: l10n,
  );
  final name = dive.name?.trim();
  final site = dive.site?.name.trim();
  final label = (name != null && name.isNotEmpty) ? name : site;
  return label == null || label.isEmpty ? when : '$label, $when';
}
