import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/domain/value_objects/photo_tag_edits.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/features/media/presentation/providers/media_gear_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// Opens the gear sheet for [item] (issue #5046), the same modal shape as
/// the tag sheet. The sheet changes nothing itself: the gear chosen is held
/// in [sitting] until it is saved.
Future<void> showMediaGearSheet(
  BuildContext context,
  MediaItem item, {
  required EditSession<PhotoRecord> sitting,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  // Room for the keyboard under the search field (#4406).
  builder: (sheetContext) => Padding(
    padding: EdgeInsets.only(
      bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
    ),
    child: DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => MediaGearSheet(
        item: item,
        scrollController: controller,
        sitting: sitting,
      ),
    ),
  ),
);

/// Link gear to a photo or video: the gear used on its dive first, then the
/// rest of the diver's gear by type. Held in the photo's sitting until the
/// viewer's Save; once the sitting has ended the sheet only reads.
class MediaGearSheet extends ConsumerStatefulWidget {
  const MediaGearSheet({
    super.key,
    required this.item,
    this.scrollController,
    required this.sitting,
  });

  final MediaItem item;
  final ScrollController? scrollController;

  /// The photo's sitting, which holds the gear chosen.
  final EditSession<PhotoRecord> sitting;

  @override
  ConsumerState<MediaGearSheet> createState() => _MediaGearSheetState();
}

class _MediaGearSheetState extends ConsumerState<MediaGearSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final sitting = widget.sitting;
    if (sitting.isDisposed) return _sheet(context);
    return ListenableBuilder(
      listenable: sitting,
      builder: (context, _) => _sheet(context),
    );
  }

  Widget _sheet(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final sitting = widget.sitting;
    final ended = sitting.isDisposed;
    final chosen = ended
        ? (ref.watch(gearIdsForMediaProvider(widget.item.id)).value ??
                  const <String>[])
              .toSet()
        : sitting.working.gearIds.toSet();
    final all =
        ref.watch(allEquipmentProvider).value ?? const <EquipmentItem>[];
    final diveId = widget.item.diveId;
    final onDiveIds = diveId == null
        ? const <String>{}
        : ref.watch(gearOnDiveProvider(diveId)).value ?? const <String>{};
    final query = _query.trim().toLowerCase();
    bool matches(EquipmentItem g) =>
        query.isEmpty ||
        [
          g.name,
          g.brand,
          g.model,
        ].any((s) => s != null && s.toLowerCase().contains(query));
    final shown = [
      for (final g in all)
        if (matches(g)) g,
    ];
    final onDive = sortedByText([
      for (final g in shown)
        if (onDiveIds.contains(g.id)) g,
    ], (g) => g.name);
    final rest = [
      for (final g in shown)
        if (!onDiveIds.contains(g.id)) g,
    ];
    final byType = <EquipmentType, List<EquipmentItem>>{};
    for (final g in rest) {
      byType.putIfAbsent(g.type, () => []).add(g);
    }

    Widget row(EquipmentItem g) => CheckboxListTile(
      key: ValueKey('media_gear_row_${g.id}'),
      value: chosen.contains(g.id),
      onChanged: ended ? null : (_) => _toggle(g.id),
      secondary: Icon(equipmentItemIcon(g)),
      title: Text(g.name, overflow: TextOverflow.ellipsis),
      subtitle: _subtitle(g),
      controlAffinity: ListTileControlAffinity.trailing,
    );

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            l10n.media_gearSheet_title,
            style: theme.textTheme.titleLarge,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l10n.media_gearSheet_search,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        if (all.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.media_gearSheet_empty),
          ),
        if (onDive.isNotEmpty) ...[
          header(l10n.media_gearSheet_onThisDive),
          for (final g in onDive) row(g),
        ],
        if (rest.isNotEmpty) ...[
          header(l10n.media_gearSheet_yourGear),
          for (final type in byType.keys.sortedByLocalizedName(l10n)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                type.localizedName(l10n),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final g in sortedByText(byType[type]!, (g) => g.name)) row(g),
          ],
        ],
      ],
    );
  }

  Widget? _subtitle(EquipmentItem g) {
    final parts = [
      g.brand,
      g.model,
    ].whereType<String>().where((s) => s.trim().isNotEmpty);
    return parts.isEmpty ? null : Text(parts.join(' '));
  }

  /// Holds [id] linked or unlinked in the sitting.
  void _toggle(String id) {
    final sitting = widget.sitting;
    if (sitting.isDisposed || sitting.isFrozen) return;
    final current = sitting.working.gearIds;
    final next = current.contains(id)
        ? [
            for (final g in current)
              if (g != id) g,
          ]
        : [...current, id];
    sitting.set(
      photoGearField,
      MediaGearEdits.between(sitting.stored.gearIds, next),
    );
  }
}
