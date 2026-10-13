import 'dart:convert';

import 'package:submersion/core/services/shared_library/crypto/canonical_json.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';

/// What an author signs for a suggestion in [libraryId] (issue #2567):
/// everything in the wire form but the signature, bound to the library, so
/// a suggestion copied into another library proves nothing there (one key
/// signs for its profile in every library).
List<int> _message(Map<String, dynamic> unsigned, String libraryId) =>
    utf8.encode('ssl-suggestion:v1\n$libraryId\n${canonicalJson(unsigned)}');

/// A suggestion's wire form signed by its author for [libraryId]: the
/// signature covers everything but itself, author and note included.
Future<Map<String, dynamic>> signSuggestion(
  Map<String, dynamic> json,
  LibrarySigningKey key, {
  required String libraryId,
}) async {
  final unsigned = {...json}..remove('signature');
  return {
    ...unsigned,
    'signature': await LibrarySigner.sign(key, _message(unsigned, libraryId)),
  };
}

/// Whether [json] carries a signature by [publicKey] over the rest of it,
/// made for [libraryId].
Future<bool> verifySuggestion(
  Map<String, dynamic> json,
  String? publicKey, {
  required String libraryId,
}) async {
  if (publicKey == null) return false;
  final signature = json['signature'];
  final unsigned = {...json}..remove('signature');
  return LibrarySigner.verify(
    publicKey: publicKey,
    message: _message(unsigned, libraryId),
    signature: signature is String ? signature : null,
  );
}
