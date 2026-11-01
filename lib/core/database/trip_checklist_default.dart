import 'dart:convert';

import 'package:crypto/crypto.dart';

/// The name of the checklist a trip's rows move into when they predate
/// multiple checklists (issue #3356). Not localized: the migration runs
/// before any UI context exists, and the diver can rename it like any other
/// checklist.
const String kDefaultTripChecklistName = 'Checklist';

/// A stable id for a trip's default checklist, derived from the trip id
/// alone (one default checklist per trip). The migration and the sync apply
/// path both reach it, so a rerun after an interrupted migration, an
/// independent run on another device and a row from a peer that has not
/// updated yet all converge on the same row instead of creating duplicates.
/// A stable identity, not a cryptographic guarantee.
String defaultTripChecklistId(String tripId) {
  final digest = sha1.convert(utf8.encode(tripId)).toString().substring(0, 12);
  return 'checklist-$digest';
}
