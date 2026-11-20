import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_operation_gate.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/clock_sync_providers.dart';
import 'package:submersion/features/dive_computer/presentation/editing/dive_computer_settings_sitting.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/domain/entities/dive_computer_connection.dart';
import 'package:submersion/features/dive_computer/domain/services/download_connection_selection.dart';
import 'package:submersion/features/dive_computer/domain/services/known_computer_reacquisition.dart';
import 'package:submersion/features/dive_computer/presentation/providers/dive_computer_connection_providers.dart';
import 'package:submersion/features/dive_computer/presentation/utils/connection_presentation.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_actions_card.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_auto_download_card.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_clock_sync_card.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_connections_card.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_info_card.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_merge_actions.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_stats_card.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Every control the app has for one registered dive computer: favourite,
/// merge, download and re-parse, device info, connections, statistics, and
/// clock sync. Shown on the computer's Equipment page (issue #3676), which
/// carries its name, notes, service and delete.
///
/// On the computer's gear item page (issue #4527, phase 3), the
/// favourite, the auto-download opt-out and the clock sync choice are held
/// in the item's sitting and changed only in its open card ([editing]);
/// merge and re-parse all are whole-record operations, needing the unlock
/// and nothing unsaved. Downloads work locked: they are a deliberate mode.
class DiveComputerControls extends ConsumerWidget {
  const DiveComputerControls({
    super.key,
    required this.computerId,
    this.editing,
  });

  final String computerId;

  /// The gear item's sitting, where these are its open card's editor.
  final EditSession<EquipmentItem>? editing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final computerAsync = ref.watch(diveComputerByIdProvider(computerId));
    return computerAsync.when(
      data: (computer) => computer == null
          ? const SizedBox.shrink()
          : _Controls(computer: computer, editing: editing),
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(context.l10n.diveComputer_error_generic(error.toString())),
      ),
    );
  }
}

class _Controls extends ConsumerWidget {
  const _Controls({required this.computer, this.editing});

  final DiveComputer computer;
  final EditSession<EquipmentItem>? editing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = RecordEditScope.maybeOf<EquipmentItem>(context);
    final session = editing ?? controller?.session;
    if (session == null) return _build(context, ref, controller, null);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => _build(context, ref, controller, session),
    );
  }

  Widget _build(
    BuildContext context,
    WidgetRef ref,
    RecordEditController<EquipmentItem>? controller,
    EditSession<EquipmentItem>? session,
  ) {
    // On the gear item page, the settings as the sitting holds
    // them, changed only in the open card.
    DiveComputerSettingsControl? control;
    if (controller != null) {
      final stored = storedDiveComputerSettings(
        computer,
        ref.watch(clockSyncSettingsNotifierProvider).overrideFor(computer.id),
      );
      final editing = this.editing;
      control = DiveComputerSettingsControl(
        shown:
            (session == null ? null : heldDiveComputerSettings(session)) ??
            stored,
        hold: editing == null
            ? null
            : (next) => holdDiveComputerSettings(
                editing,
                computer: computer,
                stored: stored,
                next: next,
                diverId: ref.read(validatedCurrentDiverIdProvider).value,
              ),
      );
    }
    final operations = controller == null
        ? null
        : (
            reason: recordOperationReason(
              context.l10n,
              recordOperationBlockOf(controller),
            ),
            run: recordOperationRunnerOf(
              controller,
              record: 'dive computer ${computer.id}',
            ),
          );
    final connections =
        ref.watch(diveComputerConnectionsProvider(computer.id)).valueOrNull ??
        const <DiveComputerConnection>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(computer: computer, control: control, operations: operations),
        const SizedBox(height: 8),
        DiveComputerDuplicateBanner(computer: computer, operations: operations),
        // Download first (issue #4622): it is what the page is opened for.
        DiveComputerActionsCard(computer: computer, operations: operations),
        const SizedBox(height: 16),
        DiveComputerInfoCard(
          computer: computer,
          icon: computerConnectionIcon(computer, connections),
        ),
        const SizedBox(height: 16),
        DiveComputerConnectionsCard(computer: computer),
        const SizedBox(height: 16),
        DiveComputerStatsCard(computer: computer),
        const SizedBox(height: 16),
        DiveComputerClockSyncCard(computer: computer, control: control),
        // Only where the passive scan could find it, judged as the download
        // page sees the computer here (its connections name BLE or Classic,
        // which the legacy type does not): on a USB, Classic or
        // file-imported record the switch would do nothing.
        if (canFindByScan(computerForDownload(computer, connections))) ...[
          const SizedBox(height: 16),
          DiveComputerAutoDownloadCard(computer: computer, control: control),
        ],
      ],
    );
  }
}

/// The section title, with the favourite star and the merge action that
/// were on the computer page's app bar.
class _Header extends ConsumerWidget {
  const _Header({required this.computer, this.control, this.operations});

  final DiveComputer computer;
  final DiveComputerSettingsControl? control;
  final DiveComputerOperations? operations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Row(
      children: [
        // The open card has a header of its own, so the title steps aside.
        Expanded(
          child: control?.hold != null
              ? const SizedBox.shrink()
              : Text(
                  l10n.diveComputer_title,
                  style: theme.textTheme.titleLarge,
                ),
        ),
        // The card's pencil, on its gear item page.
        RecordCardPencil(cardTitle: l10n.diveComputer_title),
        if (control?.shown.favourite ?? computer.isFavorite)
          IconButton(
            key: const ValueKey('dive_computer_favourite'),
            icon: Icon(Icons.star, color: theme.colorScheme.primary),
            // A favourite made in the sitting can be taken back there.
            onPressed: switch (control) {
              DiveComputerSettingsControl(:final shown, :final hold?)
                  when !computer.isFavorite =>
                () => hold((
                  favourite: false,
                  autoDownloadDisabled: shown.autoDownloadDisabled,
                  clockSync: shown.clockSync,
                )),
              _ => () {},
            },
            tooltip: l10n.diveComputer_status_favorite,
          )
        else
          IconButton(
            key: const ValueKey('dive_computer_favourite'),
            icon: const Icon(Icons.star_outline),
            onPressed: switch (control) {
              null =>
                () => ref
                    .read(diveComputerNotifierProvider.notifier)
                    .setFavorite(computer.id),
              DiveComputerSettingsControl(:final shown, :final hold?) =>
                () => hold((
                  favourite: true,
                  autoDownloadDisabled: shown.autoDownloadDisabled,
                  clockSync: shown.clockSync,
                )),
              _ => null,
            },
            tooltip: l10n.diveComputer_action_setFavorite,
          ),
        RecordOperationButton(
          reason: operations?.reason,
          onPressed: () => runDiveComputerOperation(
            operations,
            () => showDiveComputerMergePicker(context, ref, computer),
            'open merge picker',
          ),
          builder: (onPressed) => IconButton(
            key: const ValueKey('dive_computer_merge'),
            icon: const Icon(Icons.merge_type),
            tooltip: l10n.diveComputer_detail_mergeMenu,
            onPressed: onPressed,
          ),
        ),
      ],
    );
  }
}
