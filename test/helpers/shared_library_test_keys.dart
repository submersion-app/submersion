import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';

/// A fixed signing key per test member id, so a member keeps the same key
/// across the fresh databases a test opens for each "device".
Future<LibrarySigningKey> testMemberKey(String memberId) =>
    LibrarySigner.fromSeed(
      sha256.convert(utf8.encode('test-member:$memberId')).bytes,
    );

/// `roles.json` as an owner of a shared site library writes it: [owners]
/// and [editors], every listed member's key approved (plus [members]),
/// signed by the first owner in sorted order.
Future<SharedLibraryRoles> signedTestRoles({
  required Set<String> owners,
  Set<String> editors = const {},
  Set<String> members = const {},
  int version = 1,
}) async {
  final everyone = {...owners, ...editors, ...members};
  final signer = (owners.toList()..sort()).first;
  return SharedLibraryRoles(
    version: version,
    owners: owners,
    editors: editors,
    approvedKeys: {
      for (final m in everyone) m: (await testMemberKey(m)).publicKey,
    },
  ).signed(signedBy: signer, key: await testMemberKey(signer));
}
