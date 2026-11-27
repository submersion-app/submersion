import 'package:flutter/material.dart';

import 'package:submersion/features/dive_sites/presentation/editing/site_classification_sitting.dart'
    show mergedIds;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_card_ids.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_tags_field.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/field_text_binding.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_load_failed.dart';

/// The item's tags held in its page's sitting (issue #4527, phase 3, plan
/// 6): chosen on the header block, written at Save. Only the difference is
/// written, onto the tags as stored then, so a tag another device added
/// meanwhile stays. A tag the diver creates while choosing exists at once
/// and outlives a cancelled sitting, as on a dive.
final gearItemTagsList = SittingList<EquipmentItem, Tag>(
  key: 'equipment.tags',
  cardId: GearItemCardId.header.name,
  read: (item) => EquipmentTagRepository().getTagsForEquipment(item.id),
  write: (item, loaded, current) async {
    final repository = EquipmentTagRepository();
    final now = [
      for (final t in await repository.getTagsForEquipment(item.id)) t.id,
    ];
    final merged = mergedIds(
      stored: now,
      loaded: [for (final t in loaded) t.id],
      current: [for (final t in current) t.id],
    );
    // Nothing to write when a sync made the same change meanwhile.
    if (sameIdSets(merged, now, (id) => id)) return false;
    await repository.replaceTags(item.id, merged, notify: false);
    return true;
  },
  same: (a, b) => sameIdSets(a, b, (t) => t.id),
);

/// The header block's editor: the item's name, its type (fixed while a dive
/// computer or transmitter names the item, issue #3676), its tags, and for
/// wishlist gear Mark purchased.
class GearItemHeaderEditor extends ConsumerStatefulWidget {
  const GearItemHeaderEditor({super.key, required this.session});

  final EditSession<EquipmentItem> session;

  @override
  ConsumerState<GearItemHeaderEditor> createState() =>
      _GearItemHeaderEditorState();
}

class _GearItemHeaderEditorState extends ConsumerState<GearItemHeaderEditor> {
  EditSession<EquipmentItem> get _session => widget.session;

  late final _name = FieldTextBinding<EquipmentItem, String>.plain(
    session: _session,
    field: gearNameField,
    format: (v) => v,
  );

  @override
  void initState() {
    super.initState();
    // Read now, unless the page already has: the tags field has nothing to
    // show until they are.
    if (gearItemTagsList.loaded(_session) == null) {
      gearItemTagsList.load(_session);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Picks [type], and keeps the parent only where the new type can be
  /// fitted to it (a computer holds a battery, never an O2 cell).
  void _pickType(EquipmentType type) {
    final candidates = ref.read(activeEquipmentProvider).valueOrNull;
    final parent = gearParentAfterType(
      type,
      _session.valueOf(gearParentField),
      candidates,
    );
    _session
      ..set(gearTypeField, type)
      ..set(gearParentField, parent);
  }

  /// Wishlist gear bought: Active, and dated today unless a purchase date
  /// is set, as the read page's action does (#2025). Nothing is asked:
  /// Cancel takes it back.
  void _markPurchased() {
    _session.set(gearStatusField, EquipmentStatus.active);
    if (_session.valueOf(gearPurchaseDateField) == null) {
      final now = DateTime.now();
      _session.set(
        gearPurchaseDateField,
        DateTime(now.year, now.month, now.day),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final id = _session.stored.id;
    // Kept loaded for [_pickType]: with only this card open, nothing else
    // reads the active gear, and a type change would keep a host it cannot
    // be fitted to.
    final candidates = ref.watch(activeEquipmentProvider);
    // Locked until the lookup answers, so the field is never briefly
    // editable on a device's item. An item not yet created has no device
    // (issue #4527, plan 11), as the form never locked one.
    final typeLocked =
        !_session.isNew &&
        (ref.watch(equipmentHasDeviceProvider(id)).value ?? true);
    return ListenableBuilder(
      listenable: Listenable.merge([
        _session,
        gearItemTagsList.changes(_session),
      ]),
      builder: (context, _) {
        final working = _session.working;
        final name = _session.valueOf(gearNameField);
        // A host is checked against the active gear: until that is read, a
        // new type could keep a host it cannot be fitted to, and the save
        // would write it, so a fitted item's type waits for it. Read as
        // [_pickType] reads it, so a reload the gear's own dependencies
        // start (the active diver changing) waits too.
        final hostUnchecked =
            _session.valueOf(gearParentField) != null &&
            candidates.valueOrNull == null;
        final tags = gearItemTagsList.current(_session);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('gear-edit-name'),
              controller: _name.controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.equipment_edit_nameLabel,
                prefixIcon: const Icon(Icons.label),
                hintText: l10n.equipment_edit_nameHint,
                errorText: gearNameValid(name)
                    ? null
                    : l10n.equipment_edit_nameValidation,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<EquipmentType>(
              key: const ValueKey('gear-edit-type'),
              initialValue: working.type,
              decoration: InputDecoration(
                labelText: l10n.equipment_edit_typeLabel,
                prefixIcon: const Icon(Icons.category),
                helperText: typeLocked
                    ? l10n.equipment_edit_typeLockedHelper
                    : null,
                helperMaxLines: 2,
              ),
              items: [
                for (final type in EquipmentType.values.sortedByLocalizedName(
                  l10n,
                ))
                  DropdownMenuItem(
                    value: type,
                    child: Text(type.localizedName(l10n)),
                  ),
              ],
              onChanged: typeLocked || hostUnchecked
                  ? null
                  : (value) {
                      if (value != null) _pickType(value);
                    },
            ),
            const SizedBox(height: 16),
            EquipmentTagsField(
              // Inert until the stored tags are read: a set built without
              // them would drop them.
              enabled: tags != null && !gearItemTagsList.failed(_session),
              selectedTags: tags ?? const [],
              onTagsChanged: (next) => gearItemTagsList.set(_session, next),
            ),
            // A read that failed says so, and can be tried again.
            if (gearItemTagsList.failed(_session))
              SittingLoadFailed(onRetry: () => gearItemTagsList.load(_session)),
            if (working.isWanted) ...[
              const SizedBox(height: 16),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.icon(
                  key: const ValueKey('gear-edit-mark-purchased'),
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: Text(l10n.equipment_detail_markPurchased),
                  onPressed: _markPurchased,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
