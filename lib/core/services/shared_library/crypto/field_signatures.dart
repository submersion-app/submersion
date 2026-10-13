import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:submersion/core/services/shared_library/crypto/canonical_json.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/shared_library/site_document.dart';

/// What a member signs for one field of a site document (issue #2567):
/// the library, the site, the field, its clock and a hash of its value, so
/// a signature cannot be moved to another library, site, field or value.
List<int> fieldSignatureMessage({
  required String libraryId,
  required String siteId,
  required String field,
  required String hlc,
  required String memberId,
  required Object? value,
}) => utf8.encode(
  [
    'ssl-field:v1',
    libraryId,
    siteId,
    field,
    hlc,
    memberId,
    sha256Hex(utf8.encode(canonicalJson(value))),
  ].join('\n'),
);

Object? _valueOf(SiteDocument d, String field) =>
    field == SiteDocument.deletedField ? d.deleted : d.fields[field];

/// [doc] with every clock of [memberId] that has no signature signed by
/// [key]. Other members' clocks travel with their own signatures.
Future<SiteDocument> signOwnFields(
  SiteDocument doc, {
  required String libraryId,
  required String memberId,
  required LibrarySigningKey key,
}) async {
  final clocks = {...doc.clocks};
  for (final e in doc.clocks.entries) {
    final clock = e.value;
    if (clock.memberId != memberId || clock.sig != null) continue;
    final sig = await LibrarySigner.sign(
      key,
      fieldSignatureMessage(
        libraryId: libraryId,
        siteId: doc.id,
        field: e.key,
        hlc: clock.hlc.toString(),
        memberId: clock.memberId,
        value: _valueOf(doc, e.key),
      ),
    );
    clocks[e.key] = clock.copyWith(sig: sig);
  }
  return doc.copyWith(clocks: clocks);
}

Future<bool> _signedBy(
  String? key,
  SiteDocument doc,
  String field,
  String libraryId,
) async {
  final clock = doc.clocks[field]!;
  return key != null &&
      await LibrarySigner.verify(
        publicKey: key,
        message: fieldSignatureMessage(
          libraryId: libraryId,
          siteId: doc.id,
          field: field,
          hlc: clock.hlc.toString(),
          memberId: clock.memberId,
          value: _valueOf(doc, field),
        ),
        signature: clock.sig,
      );
}

/// [remote] without the fields it would win over [local] but cannot prove
/// with a key in [approvedKeys]. A field signed by a member still waiting
/// for approval ([pendingKeys]) is held: [local]'s value and clock stand in
/// for it, so it is neither applied nor seen as missing (the next upload
/// carries it forward with [carryHeld]). Any other unproven field (no
/// signature, a wrong one, an unknown signer) counts as absent, so
/// [local]'s value wins and its next upload writes it back. Fields no newer
/// than [local] are not checked: they change nothing here.
Future<SiteDocument> dropUnverified(
  SiteDocument remote, {
  required SiteDocument local,
  required String libraryId,
  required Map<String, String> approvedKeys,
  Map<String, String> pendingKeys = const {},
}) async {
  final fields = {...remote.fields};
  final clocks = {...remote.clocks};
  var deleted = remote.deleted;
  for (final e in remote.clocks.entries) {
    final mine = local.clocks[e.key];
    final newer = mine == null || e.value.hlc.compareTo(mine.hlc) > 0;
    if (!newer) continue;
    final member = e.value.memberId;
    if (await _signedBy(approvedKeys[member], remote, e.key, libraryId)) {
      continue;
    }
    final held = await _signedBy(pendingKeys[member], remote, e.key, libraryId);
    final isDeleted = e.key == SiteDocument.deletedField;
    if (held && mine != null) {
      clocks[e.key] = mine;
      if (isDeleted) {
        deleted = local.deleted;
      } else {
        fields[e.key] = local.fields[e.key];
      }
      continue;
    }
    clocks.remove(e.key);
    if (isDeleted) {
      deleted = local.deleted;
    } else {
      fields.remove(e.key);
    }
  }
  // A value with no clock at all proves nothing either.
  fields.removeWhere((name, _) => !clocks.containsKey(name));
  if (!clocks.containsKey(SiteDocument.deletedField)) deleted = local.deleted;
  return SiteDocument(
    id: remote.id,
    deleted: deleted,
    fields: fields,
    clocks: clocks,
    extra: remote.extra,
  );
}

/// [dropUnverified] for each `(remote, local)` pair, the pairs spread over
/// several isolates when there are enough to pay for them: a first pull of
/// a large library checks every field once (issue #2567).
Future<List<SiteDocument>> dropUnverifiedAll(
  List<(SiteDocument, SiteDocument)> pairs, {
  required String libraryId,
  required Map<String, String> approvedKeys,
  Map<String, String> pendingKeys = const {},
}) async {
  Future<List<SiteDocument>> run(List<(SiteDocument, SiteDocument)> part) =>
      Future.wait([
        for (final (remote, local) in part)
          dropUnverified(
            remote,
            local: local,
            libraryId: libraryId,
            approvedKeys: approvedKeys,
            pendingKeys: pendingKeys,
          ),
      ]);
  if (pairs.length < _parallelFrom) return run(pairs);
  final workers = Platform.numberOfProcessors.clamp(2, 8);
  final size = (pairs.length / workers).ceil();
  final parts = [
    for (var i = 0; i < pairs.length; i += size)
      pairs.sublist(i, min(i + size, pairs.length)),
  ];
  final results = await Future.wait([
    for (final part in parts) Isolate.run(() => run(part)),
  ]);
  return [for (final r in results) ...r];
}

/// Below this many documents one isolate is quicker than spawning more.
const _parallelFrom = 16;

/// [doc] (about to be uploaded) with [remote]'s fields that are newer and
/// signed by a member waiting for approval ([pendingKeys]) carried over,
/// so an upload never erases an edit an owner has yet to approve.
Future<SiteDocument> carryHeld(
  SiteDocument doc,
  SiteDocument remote, {
  required String libraryId,
  required Map<String, String> pendingKeys,
}) async {
  if (pendingKeys.isEmpty) return doc;
  final fields = {...doc.fields};
  final clocks = {...doc.clocks};
  var deleted = doc.deleted;
  for (final e in remote.clocks.entries) {
    final mine = doc.clocks[e.key];
    if (mine != null && e.value.hlc.compareTo(mine.hlc) <= 0) continue;
    if (!await _signedBy(
      pendingKeys[e.value.memberId],
      remote,
      e.key,
      libraryId,
    )) {
      continue;
    }
    clocks[e.key] = e.value;
    if (e.key == SiteDocument.deletedField) {
      deleted = remote.deleted;
    } else {
      fields[e.key] = remote.fields[e.key];
    }
  }
  return doc.copyWith(fields: fields, clocks: clocks, deleted: deleted);
}
