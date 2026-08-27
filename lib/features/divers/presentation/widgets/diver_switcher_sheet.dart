import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Shows the modal bottom sheet for switching the active diver profile.
///
/// Reusable from the diver profile hub UI and from the global Cmd+Shift+D
/// keyboard shortcut. Tapping a non-active diver switches the active profile
/// and pops the sheet.
Future<void> showDiverSwitcherSheet(BuildContext context) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = context.l10n;

  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (sheetContext) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                l10n.settings_profile_switchDiver_title,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
            ),
            const Divider(),
            Flexible(
              child: Consumer(
                builder: (consumerContext, ref, _) {
                  final diversAsync = ref.watch(diverListNotifierProvider);
                  final currentDiverId = ref.watch(currentDiverIdProvider);

                  return diversAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(
                      child: Text(l10n.settings_profile_error_loadingDiver),
                    ),
                    data: (divers) => ListView.builder(
                      shrinkWrap: true,
                      itemCount: divers.length,
                      itemBuilder: (listContext, index) {
                        final diver = divers[index];
                        final isActive = diver.id == currentDiverId;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(
                              sheetContext,
                            ).colorScheme.primaryContainer,
                            foregroundColor: Theme.of(
                              sheetContext,
                            ).colorScheme.onPrimaryContainer,
                            child: Text(diver.initials),
                          ),
                          title: Text(diver.name),
                          trailing: isActive
                              ? Icon(
                                  Icons.check,
                                  color: Theme.of(
                                    sheetContext,
                                  ).colorScheme.primary,
                                )
                              : null,
                          onTap: () {
                            if (isActive) return;
                            ref
                                .read(currentDiverIdProvider.notifier)
                                .setCurrentDiver(diver.id);
                            Navigator.of(sheetContext).pop();
                            messenger?.showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.settings_profile_switchedTo(diver.name),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
