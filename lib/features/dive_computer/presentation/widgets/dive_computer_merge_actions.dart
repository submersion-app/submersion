import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/domain/services/dive_computer_merge_rules.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_merge_sheet.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Points at another saved record that reports this computer's serial
/// number (#645). Shrinks to nothing while loading or when there is none,
/// so the page never reserves space for a banner it may not show.
class DiveComputerDuplicateBanner extends ConsumerWidget {
  const DiveComputerDuplicateBanner({super.key, required this.computer});

  final DiveComputer computer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duplicates =
        ref.watch(possibleDuplicateComputersProvider(computer.id)).value ??
        const <DiveComputer>[];
    if (duplicates.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    // One duplicate is named; several are counted. Joining names into the
    // singular message reads as "A, B reports the same serial number".
    final message = duplicates.length == 1
        ? context.l10n.diveComputer_detail_duplicateBanner(
            duplicates.first.displayName,
          )
        : context.l10n.diveComputer_detail_duplicateBannerMultiple(
            duplicates.length,
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        key: const ValueKey('duplicate_banner'),
        color: colorScheme.tertiaryContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.copy_all, color: colorScheme.onTertiaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(color: colorScheme.onTertiaryContainer),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  key: const ValueKey('duplicate_banner_merge'),
                  onPressed: () =>
                      mergeDiveComputerWith(context, ref, computer, duplicates),
                  icon: const Icon(Icons.merge_type),
                  label: Text(
                    context.l10n.diveComputer_detail_duplicateBannerAction,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lists the diver's other computers so one can be merged with [computer].
/// Records that share its serial number are listed first.
Future<void> showDiveComputerMergePicker(
  BuildContext context,
  WidgetRef ref,
  DiveComputer computer,
) async {
  final all = await ref.read(allDiveComputersProvider.future);
  if (!context.mounted) return;

  final duplicates = duplicateCandidatesFor(computer, all);
  final duplicateIds = duplicates.map((d) => d.id).toSet();
  final others = [
    ...duplicates,
    for (final other in all)
      if (other.id != computer.id && !duplicateIds.contains(other.id)) other,
  ];

  final chosen = await showModalBottomSheet<DiveComputer>(
    context: context,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                sheetContext.l10n.diveComputer_detail_mergePickerTitle,
                style: theme.textTheme.titleLarge,
              ),
            ),
            if (others.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Text(
                  sheetContext.l10n.diveComputer_detail_mergePickerEmpty,
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final other in others)
                      ListTile(
                        key: ValueKey('merge_pick_${other.id}'),
                        leading: const Icon(Icons.watch),
                        title: Text(other.displayName),
                        subtitle: Text(
                          duplicateIds.contains(other.id)
                              ? sheetContext
                                    .l10n
                                    .diveComputer_detail_mergePickerSameSerial
                              : other.fullName,
                        ),
                        trailing: duplicateIds.contains(other.id)
                            ? Icon(
                                Icons.copy_all,
                                color: theme.colorScheme.tertiary,
                              )
                            : null,
                        onTap: () => Navigator.of(sheetContext).pop(other),
                      ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
  if (chosen == null || !context.mounted) return;
  await mergeDiveComputerWith(context, ref, computer, [chosen]);
}

/// Opens the merge sheet for [computer] and [others]. When a record behind
/// another Equipment item survives, the page moves to that item: this one's
/// device no longer exists (issue #3676).
Future<void> mergeDiveComputerWith(
  BuildContext context,
  WidgetRef ref,
  DiveComputer computer,
  List<DiveComputer> others,
) async {
  final computers = [computer, ...others];
  final messenger = ScaffoldMessenger.of(context);
  final result = await DiveComputerMergeSheet.show(context, computers);
  if (result == null || !context.mounted) return;

  final survivor = computers.firstWhere((c) => c.id == result.survivorId);
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        context.l10n.diveComputer_merge_snackbar(
          result.mergedComputerIds.length,
          survivor.displayName,
        ),
      ),
    ),
  );
  final survivorItem = survivor.equipmentId;
  if (survivorItem != null && survivorItem != computer.equipmentId) {
    context.pushReplacement('/equipment/$survivorItem');
  }
}
