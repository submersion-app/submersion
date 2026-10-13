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
  ).signed(libraryId: 'L', signedBy: 'o', key: owner);

  test('signed roles round trip through JSON', () async {
    final roles = await v1();
    final again = SharedLibraryRoles.fromJson(roles.toJson());
    expect(again, roles);
    expect(await isSelfConsistent(again, libraryId: 'L'), isTrue);
  });

  test('an owner can move the roles forward', () async {
    final trusted = await v1();
    final next = await trusted
        .copyWith(
          version: 2,
          editors: {'e'},
          approvedKeys: {...trusted.approvedKeys, 'e': editor.publicKey},
        )
        .signed(libraryId: 'L', signedBy: 'o', key: owner);
    expect(
      await judgeRoles(trusted: trusted, incoming: next, libraryId: 'L'),
      RolesVerdict.trusted,
    );
  });

  test('a rollback to an older signed version is refused', () async {
    final trusted = await (await v1())
        .copyWith(version: 5)
        .signed(libraryId: 'L', signedBy: 'o', key: owner);
    expect(
      await judgeRoles(trusted: trusted, incoming: await v1(), libraryId: 'L'),
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
        .signed(libraryId: 'L', signedBy: 'x', key: stranger);
    expect(
      await judgeRoles(trusted: trusted, incoming: forged, libraryId: 'L'),
      RolesVerdict.rejected,
    );
  });

  test('a tampered file fails its signature', () async {
    final trusted = await v1();
    final next = await trusted
        .copyWith(version: 2)
        .signed(libraryId: 'L', signedBy: 'o', key: owner);
    final tampered = next.copyWith(editors: {'x'});
    expect(
      await judgeRoles(trusted: trusted, incoming: tampered, libraryId: 'L'),
      RolesVerdict.rejected,
    );
  });

  test('a signature cannot be moved to another signer', () async {
    final trusted = await v1();
    final next = await trusted
        .copyWith(version: 2)
        .signed(libraryId: 'L', signedBy: 'o', key: owner);
    final moved = next.copyWith(signedBy: SharedLibraryRoles.recoverySigner);
    expect(
      await judgeRoles(trusted: trusted, incoming: moved, libraryId: 'L'),
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
        .signed(
          libraryId: 'L',
          signedBy: SharedLibraryRoles.recoverySigner,
          key: recovery.key,
        );
    expect(
      await judgeRoles(trusted: trusted, incoming: next, libraryId: 'L'),
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
    ).signed(libraryId: 'L', signedBy: 'n', key: stranger);
    expect(
      await judgeRoles(trusted: trusted, incoming: reset, libraryId: 'L'),
      RolesVerdict.resetPending,
    );
  });

  test('roles an owner signed for another library never count here', () async {
    final trusted = await v1();
    final elsewhere = await trusted
        .copyWith(version: 9, owners: {'o', 'x'})
        .signed(libraryId: 'A', signedBy: 'o', key: owner);
    expect(
      await judgeRoles(trusted: trusted, incoming: elsewhere, libraryId: 'L'),
      RolesVerdict.rejected,
    );
    expect(await isSelfConsistent(elsewhere, libraryId: 'L'), isFalse);
    expect(await isSelfConsistent(elsewhere, libraryId: 'A'), isTrue);
  });

  test('a reset is only one owner who signed it themselves', () async {
    final trusted = await v1();
    // Lists a real owner first, so a member would be shown their name and
    // key, while someone else signed it.
    final twoOwners = await SharedLibraryRoles(
      version: 2,
      owners: const {'a-real', 'n'},
      approvedKeys: {'a-real': owner.publicKey, 'n': stranger.publicKey},
      reset: true,
    ).signed(libraryId: 'L', signedBy: 'n', key: stranger);
    expect(
      await judgeRoles(trusted: trusted, incoming: twoOwners, libraryId: 'L'),
      RolesVerdict.rejected,
    );
    // Signed with a retired key rather than the one it approves.
    final retired = await SharedLibraryRoles(
      version: 2,
      owners: const {'a-real'},
      editors: const {'n'},
      approvedKeys: {'a-real': owner.publicKey},
      retired: {
        'n': [(key: stranger.publicKey, untilMs: 0)],
      },
      reset: true,
    ).signed(libraryId: 'L', signedBy: 'n', key: stranger);
    expect(
      await judgeRoles(trusted: trusted, incoming: retired, libraryId: 'L'),
      RolesVerdict.rejected,
    );
  });

  test('a joining device trusts only self-consistent roles', () async {
    expect(await isSelfConsistent(await v1(), libraryId: 'L'), isTrue);
    final bogus = await (await v1())
        .copyWith(owners: {'x'})
        .signed(libraryId: 'L', signedBy: 'o', key: owner);
    expect(await isSelfConsistent(bogus, libraryId: 'L'), isFalse);
    expect(
      await isSelfConsistent(const SharedLibraryRoles(), libraryId: 'L'),
      isFalse,
    );
  });
}
