import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/shared_gear_overlap_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_equipment_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_gear_geofence.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_set_use.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_gear_tree_view.dart';
import 'package:submersion/features/dive_log/presentation/widgets/geofence_suggestion_banner.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_set_picker_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/remove_set_dialog.dart';
import 'package:submersion/features/dive_log/presentation/widgets/save_gear_as_set_dialog.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/services/gear_expander.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_arrange_sheet.dart';
import 'package:submersion/features/gear_passports/presentation/utils/scan_owned_item.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_caption.dart';
import 'package:submersion/shared/widgets/forms/form_empty_row.dart';
import 'package:submersion/shared/widgets/forms/form_overline.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

/// The Equipment card's editor (issue #4527): use a set, add from the
/// picker, scan a tag, arrange, the gear tree with its removals, save the
/// gear as a set, clear it all, and the set the dive's location suggests.
///
/// Saving a set, and a cylinder tag's fill imported by a scan, are records
/// of their own: they are made at once and outlive a cancelled sitting.
/// Sort writes the diver's own arrangement, a display setting.
class DiveEquipmentCardEditor extends ConsumerStatefulWidget {
  const DiveEquipmentCardEditor({super.key, required this.session});

  final EditSession<Dive> session;

  @override
  ConsumerState<DiveEquipmentCardEditor> createState() =>
      _DiveEquipmentCardEditorState();
}

class _DiveEquipmentCardEditorState
    extends ConsumerState<DiveEquipmentCardEditor> {
  EditSession<Dive> get _session => widget.session;

  /// Reads for work that goes on after this card closes: gear picked, then
  /// Done tapped while its parts are read, is still the diver's choice.
  ProviderRead get _read =>
      ProviderScope.containerOf(context, listen: false).read;

  Future<void> _add(List<EquipmentItem> items, {String? viaSetId}) =>
      addGearToSitting(_read, _session, items, viaSetId: viaSetId);

  Future<void> _useSet(EquipmentSet set, List<EquipmentItem> items) =>
      useSetInSitting(
        _session,
        set,
        items,
        read: _read,
        questions: SetUseQuestions.dialogs(
          context,
          ref.read(unitFormatterProvider),
        ),
        auto: false,
      );

  void _showPicker() {
    final selected = {
      for (final link in _session.valueOf(diveGearField)) link.item.id,
    };
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        // A Consumer, so the shared gear note (issue #2853) loads while the
        // sheet is open.
        builder: (sheetContext, scrollController) => Consumer(
          builder: (sheetContext, sheetRef, _) => EquipmentPickerSheet(
            scrollController: scrollController,
            selectedEquipmentIds: selected,
            hideSpare: true,
            hideAssemblyParts: true,
            // A dive logged after the fact may have used gear since retired
            // or sold (#3210).
            offerLeftKit: true,
            overlapNote: _overlapNote(sheetRef),
            // Multi-select, so a full kit goes on in one pass (#2175).
            onEquipmentConfirmed: (items) {
              Navigator.of(sheetContext).pop();
              _add(items);
            },
          ),
        ),
      ),
    );
  }

  void _showSetPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (sheetContext, scrollController) => EquipmentSetPickerSheet(
          scrollController: scrollController,
          onSetSelected: (set, items) {
            Navigator.of(sheetContext).pop();
            _useSet(set, items);
          },
        ),
      ),
    );
  }

  /// Adds the item a scanned tag names, through the same path as the picker
  /// so its parts come along (issue #2652).
  Future<void> _scan() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final item = await scanOwnedItem(context, ref);
    if (item == null || !mounted) return;
    if (_session.valueOf(diveGearField).any((g) => g.item.id == item.id)) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.gearPassport_scan_alreadyOnDive(item.name)),
        ),
      );
      return;
    }
    await _add([item]);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.gearPassport_scan_added(item.name))),
    );
  }

  Future<void> _removeSet(String setId) async {
    final choice = await showRemoveSetDialog(context);
    if (choice == null || !mounted) return;
    removeSetFromSitting(
      _session,
      setId,
      keepGear: choice == RemoveSetChoice.keepGear,
    );
  }

  /// "Also on Anna's dive, 10:02" for gear on another profile's dive at the
  /// same time (issue #2853), worked out from the sitting's times.
  String? Function(String equipmentId) _overlapNote(WidgetRef ref) {
    final dive = _session.working;
    final entry = dive.effectiveEntryTime;
    final span = dive.runtime ?? dive.bottomTime;
    final notes =
        ref
            .watch(
              sharedGearOverlapProvider((
                diveId: dive.id,
                diverId: dive.diverId,
                entry: entry,
                exit: dive.exitTime ?? (span == null ? null : entry.add(span)),
              )),
            )
            .value ??
        const <String, SharedGearNote>{};
    final units = ref.read(unitFormatterProvider);
    final l10n = context.l10n;
    return (equipmentId) {
      final note = notes[equipmentId];
      if (note == null) return null;
      return l10n.diveLog_gear_alsoOnDive(
        note.diverName,
        units.formatTime(note.entry),
      );
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        final dive = _session.working;
        final links = _session.valueOf(diveGearField);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            FormOverline(
              label: l10n.diveLog_edit_section_equipment,
              actions: [
                FormOverlineAction(
                  label: l10n.diveLog_edit_useSet,
                  icon: Icons.folder_special,
                  onPressed: _showSetPicker,
                ),
                FormOverlineAction(
                  label: l10n.diveLog_edit_add,
                  icon: Icons.add,
                  onPressed: _showPicker,
                ),
                FormOverlineAction(
                  label: l10n.gearPassport_scan_action,
                  icon: Icons.qr_code_scanner,
                  onPressed: _scan,
                ),
                FormOverlineAction(
                  label: l10n.equipment_list_sortTooltip,
                  icon: Icons.sort,
                  onPressed: () => showEquipmentArrangeSheet(context),
                ),
              ],
            ),
            // A Tank item here counts toward its dives and service but
            // feeds no gas data; the cylinders do that (issue #2599).
            if (dive.diveMode != DiveMode.gauge)
              FormCaption(l10n.diveLog_edit_equipmentCaption),
            DiveGeofenceSuggestion(session: _session, onUse: _useSet),
            if (links.isEmpty)
              FormEmptyRow(label: l10n.diveLog_edit_noEquipmentSelected)
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DiveGearTreeView(
                      links: links,
                      overlapNote: _overlapNote(ref),
                      ownerReferenceDiverId:
                          dive.diverId ??
                          ref.watch(validatedCurrentDiverIdProvider).value,
                      // The diver is choosing gear right now, so today's
                      // service state is what they need to see.
                      showServiceStatus: true,
                      onRemoveSet: _removeSet,
                      onRemoveSubtree: (id) => keepGearRows(
                        _session,
                        GearExpander.removeSubtree(
                          sittingGearRows(_session),
                          id,
                        ),
                      ),
                      onRemovePart: (id) => keepGearRows(
                        _session,
                        GearExpander.removePart(sittingGearRows(_session), id),
                      ),
                      // Re-adding the assembly writes only what its template
                      // gained since the dive was logged (#1988).
                      onUpdateAssembly: (link) =>
                          _add([link.item], viaSetId: link.viaSetId),
                    ),
                    const SizedBox(height: 8),
                    // Wraps on a narrow phone rather than overflowing.
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: () => showSaveGearAsSetDialog(
                            context,
                            topLevelIds: [
                              for (final link in links)
                                if (link.isTopLevel) link.item.id,
                            ],
                          ),
                          icon: const Icon(Icons.save_alt, size: 18),
                          label: Text(l10n.diveLog_edit_saveAsSet),
                        ),
                        TextButton(
                          onPressed: () => clearGear(_session),
                          child: Text(l10n.diveLog_edit_clearAllEquipment),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The set the dive's location suggests during a sitting (issue #4527),
/// as the dive form's banner: Apply uses it, Dismiss puts it away for the
/// sitting. Draws nothing while there is none.
///
/// It arrives after a lookup, with the header open most of the time, so it
/// waits while any card but Equipment is open: coming in, it would push an
/// open editor below it down the page.
class DiveGeofenceSuggestion extends StatelessWidget {
  const DiveGeofenceSuggestion({
    super.key,
    required this.session,
    required this.onUse,
  });

  final EditSession<Dive> session;
  final Future<void> Function(EquipmentSet set, List<EquipmentItem> items)
  onUse;

  @override
  Widget build(BuildContext context) {
    final open = RecordEditScope.maybeOf<Dive>(context)?.openCardIds ?? {};
    final othersOpen = open.any((id) => id != diveEquipmentCardId);
    return ValueListenableBuilder<EquipmentSet?>(
      valueListenable: geofenceSuggestionListenable(session),
      builder: (context, set, _) {
        if (set == null || othersOpen) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
          child: GeofenceSuggestionBanner(
            setName: set.name,
            locationLabel: session.working.site?.name,
            onApply: () {
              geofenceSuggestionUsed(session);
              onUse(set, set.items ?? const []);
            },
            onDismiss: () => dismissGeofenceSuggestion(session),
          ),
        );
      },
    );
  }
}
