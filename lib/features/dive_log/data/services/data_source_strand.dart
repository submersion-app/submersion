import 'package:submersion/core/database/computer_serial_identity.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/imported_computer_identity.dart';

/// The strand a `dive_data_sources` row belongs to for display purposes.
///
/// A dive can hold more provenance rows than it has sources to show. Combine
/// carries every segment's row onto the merged dive because each one holds the
/// only surviving copy of its half's rawData/rawFingerprint/sourceUuid, which
/// reparse and the import duplicate checker read directly (issue #1451). Those
/// rows collapse on read instead: rows sharing a strand key are one chip, and
/// the first of them wins.
///
/// The key is total, so every row has one:
///
/// - `computerId` when the row has one. It wins over the slot: a carried row
///   still belongs to its computer's strand, and collapsing on it keeps a
///   merged dive's rows in one chip with any later same-computer source.
/// - else `mergeSourceSlot`, the row's position among its own segment's
///   strands, stamped by [DiveMergeService.apply]. This is what collapses the
///   halves of a file or cloud import, which carry no computer.
/// - else the row's own id, which is unique, so such a row is always its own
///   strand and never collapses against anything.
///
/// Namespaced per kind so a computer id can never be mistaken for a slot.
///
/// This is one row's own key. A dive's rows are keyed together by
/// [dataSourceStrandKeysById], which also collapses two computer-less rows
/// of one recording; every read that groups a dive's rows goes through it.
String dataSourceStrandKey({
  required String rowId,
  required String? computerId,
  required int? mergeSourceSlot,
}) => switch ((computerId, mergeSourceSlot)) {
  (final String id, _) => 'computer:$id',
  (null, final int slot) => 'mergeSlot:$slot',
  (null, null) => 'row:$rowId',
};

/// The order a dive's source rows are shown in: primary first, then oldest,
/// then by id, so rows a Combine copied with one createdAt still come back
/// the same way every time. `DiveRepository` reads rows in this order in
/// SQL; this is the same order for rows already in memory.
int compareDataSourcesInShownOrder(
  DiveDataSourcesData a,
  DiveDataSourcesData b,
) {
  if (a.isPrimary != b.isPrimary) return a.isPrimary ? -1 : 1;
  final byCreated = a.createdAt.compareTo(b.createdAt);
  return byCreated != 0 ? byCreated : a.id.compareTo(b.id);
}

/// The strand key of each of one dive's [rows], by row id.
///
/// [rows] come in shown order ([compareDataSourcesInShownOrder]), because
/// the first row of a strand is the one that speaks for it.
///
/// Each row starts from its own [dataSourceStrandKey]. A row that key leaves
/// on its own (no computer, no merge slot) then joins the first strand of
/// such rows whose every row recorded the same dive, per
/// [sameRecordingWithoutComputer]. That is one download stored twice by two
/// import paths with no registered computer to tie them, as
/// 'Shearwater Perdix 2' with no serial and 'Perdix 2' with the serial the
/// computer shows (issue #3654). A row with a computer or a slot keeps the
/// rule above, and no row is ever moved onto one.
Map<String, String> dataSourceStrandKeysById(
  Iterable<DiveDataSourcesData> rows,
) {
  final keys = <String, String>{};
  // The rows with no computer and no slot, by strand, in the order each
  // strand was first seen.
  final looseByStrand = <String, List<DiveDataSourcesData>>{};
  for (final row in rows) {
    final own = dataSourceStrandKey(
      rowId: row.id,
      computerId: row.computerId,
      mergeSourceSlot: row.mergeSourceSlot,
    );
    if (row.computerId != null || row.mergeSourceSlot != null) {
      keys[row.id] = own;
      continue;
    }
    // Every row already on the strand must agree, not just the first: a
    // serial-less row matches either of two serials that do not match each
    // other.
    final strand =
        looseByStrand.entries
            .where(
              (e) => e.value.every((r) => sameRecordingWithoutComputer(r, row)),
            )
            .firstOrNull
            ?.key ??
        own;
    keys[row.id] = strand;
    (looseByStrand[strand] ??= []).add(row);
  }
  return keys;
}

/// How far apart two parses of one recording may put its maximum depth:
/// one importer keeps libdivecomputer's full value, another a rounded or
/// unit-converted one.
const double _sameRecordingDepthToleranceMeters = 0.1;

/// Whether [a] and [b], two source rows of one dive, are the same recording
/// of the same computer.
///
/// Every part must agree, because a miss only costs a second chip while a
/// false match hides a computer the diver really wore (two units of one
/// model are common):
///
/// - the model, compared normalized and allowing a vendor prefix on one
///   side, so 'Shearwater Perdix 2' and 'Perdix 2' agree;
/// - the serial, unless one side has none (the Shearwater hex and decimal
///   forms are one serial, per [computerSerialsMatch]);
/// - the start to the second and the runtime to the second, which two
///   computers never share, and the maximum depth within rounding.
///
/// Two rows one import wrote from one file never match: the file listed
/// them as separate computers, and the importer starts each at the dive's
/// own start, so their shared start is no evidence of one recording.
bool sameRecordingWithoutComputer(
  DiveDataSourcesData a,
  DiveDataSourcesData b,
) {
  if (_sameImport(a, b)) return false;
  if (!_sameModel(a.computerModel, b.computerModel)) return false;
  if (!_compatibleSerials(a, b)) return false;
  final aStart = a.entryTime;
  final bStart = b.entryTime;
  if (aStart == null || bStart == null) return false;
  if (aStart.millisecondsSinceEpoch ~/ 1000 !=
      bStart.millisecondsSinceEpoch ~/ 1000) {
    return false;
  }
  if (a.duration == null || a.duration != b.duration) return false;
  final aDepth = a.maxDepth;
  final bDepth = b.maxDepth;
  if (aDepth == null || bDepth == null) return false;
  return (aDepth - bDepth).abs() <= _sameRecordingDepthToleranceMeters;
}

bool _sameImport(DiveDataSourcesData a, DiveDataSourcesData b) =>
    a.sourceFileName != null &&
    a.sourceFileName == b.sourceFileName &&
    a.importedAt == b.importedAt;

bool _sameModel(String? a, String? b) {
  final left = normalizeComputerIdentityPart(a);
  final right = normalizeComputerIdentityPart(b);
  if (left.isEmpty || right.isEmpty) return false;
  if (left == right) return true;
  final (longer, shorter) = left.length > right.length
      ? (left, right)
      : (right, left);
  return longer.endsWith(' $shorter');
}

bool _compatibleSerials(DiveDataSourcesData a, DiveDataSourcesData b) {
  if (normalizeComputerIdentityPart(a.computerSerial).isEmpty ||
      normalizeComputerIdentityPart(b.computerSerial).isEmpty) {
    return true;
  }
  return computerSerialsMatch(
    a.computerSerial,
    b.computerSerial,
    shearwater: shearwaterPair(
      modelA: a.computerModel,
      modelB: b.computerModel,
    ),
  );
}
