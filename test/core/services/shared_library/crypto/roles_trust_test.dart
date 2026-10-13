import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/crypto/library_recovery.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/shared_library/crypto/roles_trust.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';

void main() {
  late LibrarySigningKey owner, editor, stranger;
  late LibraryRecoveryKey recovery;

  setUpAll(() async {
    owner = await LibrarySigner.generate();
    editor = await LibrarySigner.generate();
    stranger = await LibrarySigner.generate();
    recovery = await LibraryRecovery.create(
      kdf: const KdfParams(m: 1024, t: 1),
    );
  });

  Future<SharedLibraryRoles> v1() => SharedLibraryRoles(
    version: 1,
    owners: const {'o'},
    approvedKeys: {'o': owner.publicKey},
    recovery: RolesRecovery.fromJson(recovery.toRolesJson()),
  ).signed(signedBy: 'o', key: owner);

  test('signed roles round trip through JSON', () async {
    final roles = await v1();
    final again = SharedLibraryRoles.fromJson(roles.toJson());
    expect(again, roles);
    expect(await isSelfConsistent(again), isTrue);
  });

  test('an owner can move the roles forward', () async {
    final trusted = await v1();
    final next = await trusted
        .copyWith(
          version: 2,
          editors: {'e'},
          approvedKeys: {...trusted.approvedKeys, 'e': editor.publicKey},
        )
        .signed(signedBy: 'o', key: owner);
    expect(
      await judgeRoles(trusted: trusted, incoming: next),
      RolesVerdict.trusted,
    );
  });

  test('a rollback to an older signed version is refused', () async {
    final trusted = await (await v1())
        .copyWith(version: 5)
        .signed(signedBy: 'o', key: owner);
    expect(
      await judgeRoles(trusted: trusted, incoming: await v1()),
      RolesVerdict.rejected,
    );
  });

  test('someone who is not an owner cannot sign roles', () async {
    final trusted = await v1();
    final forged = await trusted
        .copyWith(
          version: 2,
          owners: {'o', 'x'},
          approvedKeys: {...trusted.approvedKeys, 'x': stranger.publicKey},
        )
        .signed(signedBy: 'x', key: stranger);
    expect(
      await judgeRoles(trusted: trusted, incoming: forged),
      RolesVerdict.rejected,
    );
  });

  test('a tampered file fails its signature', () async {
    final trusted = await v1();
    final next = await trusted
        .copyWith(version: 2)
        .signed(signedBy: 'o', key: owner);
    final tampered = next.copyWith(editors: {'x'});
    expect(
      await judgeRoles(trusted: trusted, incoming: tampered),
      RolesVerdict.rejected,
    );
  });

  test('a signature cannot be moved to another signer', () async {
    final trusted = await v1();
    final next = await trusted
        .copyWith(version: 2)
        .signed(signedBy: 'o', key: owner);
    final moved = next.copyWith(signedBy: SharedLibraryRoles.recoverySigner);
    expect(
      await judgeRoles(trusted: trusted, incoming: moved),
      RolesVerdict.rejected,
    );
  });

  test('the recovery key signs like an owner', () async {
    final trusted = await v1();
    final next = await trusted
        .copyWith(
          version: 2,
          owners: {'n'},
          approvedKeys: {'n': stranger.publicKey},
        )
        .signed(signedBy: SharedLibraryRoles.recoverySigner, key: recovery.key);
    expect(
      await judgeRoles(trusted: trusted, incoming: next),
      RolesVerdict.trusted,
    );
  });

  test('a reset asks the member', () async {
    final trusted = await v1();
    final reset = await SharedLibraryRoles(
      version: 2,
      owners: const {'n'},
      approvedKeys: {'n': stranger.publicKey},
      reset: true,
    ).signed(signedBy: 'n', key: stranger);
    expect(
      await judgeRoles(trusted: trusted, incoming: reset),
      RolesVerdict.resetPending,
    );
  });

  test('a joining device trusts only self-consistent roles', () async {
    expect(await isSelfConsistent(await v1()), isTrue);
    final bogus = await (await v1())
        .copyWith(owners: {'x'})
        .signed(signedBy: 'o', key: owner);
    expect(await isSelfConsistent(bogus), isFalse);
    expect(await isSelfConsistent(const SharedLibraryRoles()), isFalse);
  });
}
