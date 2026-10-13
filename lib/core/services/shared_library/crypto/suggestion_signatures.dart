import 'dart:convert';

import 'package:submersion/core/services/shared_library/crypto/canonical_json.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';

/// A suggestion's wire form signed by its author (issue #2567): the
/// signature covers everything but itself, author and note included.
Future<Map<String, dynamic>> signSuggestion(
  Map<String, dynamic> json,
  LibrarySigningKey key,
) async {
  final unsigned = {...json}..remove('signature');
  return {
    ...unsigned,
    'signature': await LibrarySigner.sign(
      key,
      utf8.encode(canonicalJson(unsigned)),
    ),
  };
}

/// Whether [json] carries a signature by [publicKey] over the rest of it.
Future<bool> verifySuggestion(
  Map<String, dynamic> json,
  String? publicKey,
) async {
  if (publicKey == null) return false;
  final signature = json['signature'];
  final unsigned = {...json}..remove('signature');
  return LibrarySigner.verify(
    publicKey: publicKey,
    message: utf8.encode(canonicalJson(unsigned)),
    signature: signature is String ? signature : null,
  );
}
