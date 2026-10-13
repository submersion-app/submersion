import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:submersion/core/services/shared_library/crypto/library_cipher.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';

/// A fixed signing key per test member id, so a member keeps the same key
/// across the fresh databases a test opens for each "device".
Future<LibrarySigningKey> testMemberKey(String memberId) =>
    LibrarySigner.fromSeed(
      sha256.convert(utf8.encode('test-member:$memberId')).bytes,
    );

/// `roles.json` as an owner of a shared site library writes it: [owners]
/// and [editors], every listed member's key approved (plus [members]),
/// signed by the first owner in sorted order, for the library [libraryId].
Future<SharedLibraryRoles> signedTestRoles({
  required Set<String> owners,
  Set<String> editors = const {},
  Set<String> members = const {},
  int version = 1,
  String libraryId = 'L',
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
  ).signed(
    libraryId: libraryId,
    signedBy: signer,
    key: await testMemberKey(signer),
  );
}

/// The passphrase of every encrypted test library.
const testPassphrase = 'correct horse battery staple';

/// Makes the folder [t] reaches an encrypted library: manifest, keyslots
/// (unlocked by [testPassphrase] or [recoveryCode]), and sealed roles and
/// name. Returns the cipher, set on [t].
Future<LibraryCipher> sealTestLibrary(
  SharedLibraryTransport t, {
  String id = 'L',
  String name = 'Reef Survey',
  required SharedLibraryRoles roles,
  String recoveryCode = 'alpha-bravo-charlie',
}) async {
  final cipher = await LibraryCipher.generate();
  t
    ..cipher = cipher
    ..encrypting = true;
  await t.writeManifest({
    'id': id,
    'formatVersion': SharedLibraryLayout.formatVersion,
    'encrypted': true,
    'keyId': cipher.keyId,
  });
  await t.writeKeyslots(
    await cipher.keyslots(
      passphrase: testPassphrase,
      recoveryCode: recoveryCode,
      kdf: const KdfParams(m: 1024, t: 1),
    ),
  );
  await t.writeRoles(roles);
  await t.writeInfo({'name': name});
  return cipher;
}
