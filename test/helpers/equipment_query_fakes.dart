import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_query_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_tag_providers.dart';

import 'mock_providers.dart' show Override;

/// A stand-in for the equipment list's compiled id set, for widget tests
/// with no database (#2365). It narrows the gear the test already stubs the
/// way those tests always did: the stub the status axis once picked (the
/// service-due list, the active list, or the list for one status), then
/// category, curated attributes, owner and tags. What the real query selects
/// is pinned against rows by equipment_filter_query_semantics_test.
Override fakeEquipmentQueryIds() =>
    queryFilteredEquipmentIdsProvider.overrideWith((ref, key) async {
      final f = key.filter;
      final List<EquipmentItem> base = f.serviceDue != null
          ? await ref.watch(serviceDueEquipmentProvider(f.serviceDue!).future)
          : f.status == null
          ? await ref.watch(activeEquipmentProvider.future)
          : await ref.watch(equipmentByStatusProvider(f.status!).future);
      final tags = ref.watch(tagsByEquipmentProvider).value ?? const {};
      final diverId = key.diverId;
      bool ownerMatches(EquipmentItem e) => switch (diverId == null
          ? EquipmentOwnerFilter.all
          : f.owner) {
        EquipmentOwnerFilter.all => true,
        EquipmentOwnerFilter.mine => e.diverId == null || e.diverId == diverId,
        EquipmentOwnerFilter.sharedWithMe =>
          e.diverId != null && e.diverId != diverId,
      };
      return {
        for (final e in base)
          if ((f.type == null || e.type == f.type) &&
              f.attrConditions.every((c) => c.matches(e)) &&
              ownerMatches(e) &&
              (f.tagIds.isEmpty ||
                  (tags[e.id] ?? const []).any((t) => f.tagIds.contains(t.id))))
            e.id,
      };
    });
