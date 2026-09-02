import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

/// Lets the user pick between the dives an ambiguous timestamp match
/// offered, closest entry first. Resolves to the dive id, or null.
Future<String?> showAmbiguousDiveSheet(
  BuildContext context,
  List<String> candidateDiveIds,
) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final id in candidateDiveIds)
            AmbiguousDiveTile(
              diveId: id,
              onTap: () => Navigator.of(sheetContext).pop(id),
            ),
        ],
      ),
    ),
  );
}

/// Candidate row in the ambiguous chooser: dive number, name/site, date.
class AmbiguousDiveTile extends ConsumerWidget {
  const AmbiguousDiveTile({
    super.key,
    required this.diveId,
    required this.onTap,
  });

  final String diveId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dive = ref.watch(diveProvider(diveId)).value;
    final locale = Localizations.localeOf(context).toString();
    final parts = dive == null
        ? const <String>[]
        : [
            if (dive.diveNumber != null) '#${dive.diveNumber}',
            if (dive.name != null && dive.name!.isNotEmpty)
              dive.name!
            else if (dive.site?.name != null)
              dive.site!.name,
          ];
    // A dive with no number, name, or site would otherwise render a blank
    // title; the id is at least a stable handle.
    final label = parts.isEmpty ? diveId : parts.join(' ');
    return ListTile(
      title: Text(label),
      subtitle: dive == null
          ? null
          : Text(DateFormat.yMMMd(locale).format(dive.dateTime)),
      onTap: onTap,
    );
  }
}
