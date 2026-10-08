/// The id the merge keys a record by: `id` for most entities, the natural
/// key for the handful that have none. Must agree with the id
/// `SyncDataSerializer.recordIdsFor` emits and
/// `SyncDataSerializer.deleteRecord` accepts, or the entity's rows silently
/// fail to merge -- which is what a missing `divePlanEquipment` case did
/// (issue #1728).
/// A structural test pins every composite-key table to a case here.
String? syncRecordId(String entityType, Map<String, dynamic> record) {
  switch (entityType) {
    case 'settings':
      return record['key'] as String?;
    case 'diveSafetyReviews':
      // PK is dive_id (one marker row per dive), not id.
      return record['diveId'] as String?;
    case 'diveEquipment':
      return record['id'] as String? ??
          _compositeId(record['diveId'], record['equipmentId']);
    case 'equipmentSetItems':
      return record['id'] as String? ??
          _compositeId(record['setId'], record['equipmentId']);
    case 'divePlanEquipment':
      // Composite (planId, equipmentId), same shape as diveEquipment. The
      // serializer has always keyed it that way in fetchRecord,
      // deleteRecord and allRecordIds; without this case the merge fell
      // through to record['id'], which these rows do not have, so every
      // incoming dive-plan gear row was counted as malformed and never
      // applied.
      return record['id'] as String? ??
          _compositeId(record['planId'], record['equipmentId']);
    default:
      return record['id'] as String?;
  }
}

String? _compositeId(Object? left, Object? right) {
  if (left == null || right == null) return null;
  return '$left|$right';
}

/// Overlays an incoming [remote] row onto the receiver's current [local] row
/// so a column the remote payload OMITS keeps its local value, while every
/// key the remote actually sends -- including an explicit `null` that clears
/// a field (#474) -- wins. A peer on an older build omits every column its
/// schema lacks; without this the receiver would write NULL, or the column's
/// default, over the value it held (#2553). Same-version peers export full
/// rows, so the overlay is a no-op for them. With no [local] row the remote
/// row is new here and applies as sent.
///
/// One exception: a service clock's `anchorSetAt` (v213) says when the
/// diver set its baseline, and a null keeps the pre-v213 rule for it. A
/// pre-v213 peer that CHANGES the baseline sends no set time, and
/// refilling ours would stamp the peer's baseline with a time that belongs
/// to a different date. So a schedule payload that omits the set time but
/// moves the baseline lands with none; one that leaves the baseline alone
/// keeps ours.
///
/// The import applies a further rule after this overlay: for the few
/// columns where null means "never held a value" (the diver's pSCR ratio and
/// viewport choice, v262), an explicit null is dropped as if omitted, so a
/// peer with none keeps ours (`_withoutUnsetNulls` in SyncDataSerializer).
Map<String, dynamic> overlayOntoLocal(
  String entityType,
  Map<String, dynamic> remote,
  Map<String, dynamic>? local,
) {
  if (local == null) return remote;
  final merged = {...local, ...remote};
  if (entityType == 'serviceSchedules' &&
      !remote.containsKey('anchorSetAt') &&
      remote.containsKey('anchorDate') &&
      remote['anchorDate'] != local['anchorDate']) {
    merged['anchorSetAt'] = null;
  }
  return merged;
}
