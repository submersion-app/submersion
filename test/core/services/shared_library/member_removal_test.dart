import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/member_removal.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';

import '../../../helpers/shared_library_test_keys.dart';

/// Removing a member from a shared site library (issue #3481).
void main() {
  final removedAt = DateTime.utc(2026, 10, 18, 9);

  Future<SharedLibraryRoles> roles() async => SharedLibraryRoles(
    owners: const {'ann'},
    editors: const {'ed'},
    approvedKeys: {
      'ann': (await testMemberKey('ann')).publicKey,
      'ed': (await testMemberKey('ed')).publicKey,
    },
  );

  Future<MemberRemoval> removal({
    String by = 'ann',
    String library = 'L',
  }) async => MemberRemoval.signed(
    libraryId: library,
    memberId: 'bo',
    displayName: 'Bo',
    publicKey: (await testMemberKey('bo')).publicKey,
    removedAt: removedAt,
    removedBy: by,
    key: await testMemberKey(by),
  );

  group('the removal record', () {
    test('a record signed by an owner verifies', () async {
      expect(await (await removal()).verify('L', await roles()), isTrue);
    });

    test('a record signed by an editor does not verify', () async {
      expect(
        await (await removal(by: 'ed')).verify('L', await roles()),
        isFalse,
      );
    });

    test('a tampered field or another library does not verify', () async {
      final r = await removal();
      final tampered = MemberRemoval.fromJson({
        ...r.toJson(),
        'displayName': 'Someone else',
      })!;
      expect(await tampered.verify('L', await roles()), isFalse);
      expect(await r.verify('M', await roles()), isFalse);
    });

    test('round-trips through json', () async {
      final r = await removal();
      expect(MemberRemoval.fromJson(r.toJson()), r);
      expect(MemberRemoval.fromJson(const {'memberId': 1}), isNull);
      expect(MemberRemoval.fromJson('not a map'), isNull);
      // A time no DateTime can hold, or no number at all, is no record.
      for (final at in [9e15, -9e15, double.nan, double.infinity]) {
        expect(
          MemberRemoval.fromJson({...r.toJson(), 'removedAt': at}),
          isNull,
        );
      }
    });

    test('validRemovals keeps only the verified records', () async {
      final good = await removal();
      final forged = await removal(by: 'ed');
      expect(await validRemovals([good, forged], 'L', await roles()), [good]);
    });
  });

  group('the roles change', () {
    test(
      'removing an editor retires the key at the cut-off and drops the approval',
      () async {
        final key = (await testMemberKey('bo')).publicKey;
        final before = SharedLibraryRoles(
          owners: const {'ann'},
          editors: const {'bo'},
          approvedKeys: {'ann': 'a', 'bo': key},
        );
        final after = before.removing('bo', at: removedAt);
        expect(after.roleOf('bo'), SharedLibraryRole.reader);
        expect(after.approvedKeys, isNot(contains('bo')));
        expect(after.approvedKeys['ann'], 'a');
        expect(after.retired['bo'], [
          (key: key, untilMs: removedAt.millisecondsSinceEpoch),
        ]);
      },
    );

    test('removing an owner retires their key too', () {
      const before = SharedLibraryRoles(
        owners: {'ann', 'cy'},
        approvedKeys: {'ann': 'a', 'cy': 'c'},
      );
      final after = before.removing('cy', at: removedAt);
      expect(after.owners, {'ann'});
      expect(after.retired['cy']!.single.key, 'c');
    });

    test('removing a reader retires nothing', () {
      const before = SharedLibraryRoles(
        owners: {'ann'},
        approvedKeys: {'ann': 'a', 'rd': 'r'},
      );
      final after = before.removing('rd', at: removedAt);
      expect(after.retired, isNot(contains('rd')));
      expect(after.approvedKeys, isNot(contains('rd')));
    });
  });
}
