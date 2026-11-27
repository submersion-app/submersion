import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Opens a new record on its own page from an opener that has no place of
/// its own to show it (a list's Add on a phone, its empty state, a map's
/// Add; issue #4527, phase 3, plan 11): pushes [newLocation] and, once the
/// page comes back with the new record, opens [recordLocation] of its id,
/// locked, as a new site does. Nothing back (the diver cancelled) stays
/// where it was.
///
/// [idOf] reads the id from what the page popped: the id itself by
/// default, for a type whose page pops the record
/// (`RecordCreating.newRecordResult`) the record's.
Future<void> openNewRecord(
  BuildContext context, {
  required String newLocation,
  required String Function(String id) recordLocation,
  Object? extra,
  String? Function(Object? popped) idOf = poppedId,
}) async {
  final popped = await context.push<Object?>(newLocation, extra: extra);
  final id = idOf(popped);
  if (id == null || id.isEmpty || !context.mounted) return;
  await context.push(recordLocation(id));
}

/// [popped] when it is an id.
String? poppedId(Object? popped) => popped is String ? popped : null;
