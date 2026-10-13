import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/shared_library/crypto/suggestion_signatures.dart';
import 'package:submersion/core/services/shared_library/shared_library_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/shared_library_test_keys.dart';
import '../../../helpers/test_database.dart';
import 'shared_library_service_test.dart' show device, seedLibrary;

/// A file nobody can read, which any member's storage key may write, is
/// skipped: it never stops the sync of everyone else (issue #2567).
void main() {
  tearDown(() async {
    try {
      await tearDownTestDatabase();
    } catch (_) {}
  });

  Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));

  Future<(SharedLibraryService, SharedLibraryTransport)> library() async {
    final cloud = FakeCloudStorageProvider();
    await seedLibrary(cloud);
    final svc = await device(cloud, 'a');
    final first = await svc.sync('L', diverId: 'd-a');
    expect(first.status, SharedLibrarySyncStatus.success);
    return (svc, SharedLibraryTransport(cloud, prefix: 'site-sync'));
  }

  for (final (what, path, content) in [
    ('a member card that only looks sealed', 'members/member-x.json', 'SBE1x'),
    (
      'a member card with a number for a name',
      'members/member-x.json',
      '{"displayName": 1}',
    ),
    ('a site document that only looks sealed', 'sites/site-x.json', 'SBE1x'),
    (
      'a suggestion that only looks sealed',
      'suggestions/suggestion-x.json',
      'SBE1x',
    ),
    (
      'a suggestion no signature can be computed over',
      'suggestions/suggestion-x.json',
      '{"memberId": "a", "note": 1e999}',
    ),
  ]) {
    test('$what does not stop the sync', () async {
      final (svc, t) = await library();
      await t.writeRaw(path, bytes(content));
      final result = await svc.sync('L', diverId: 'd-a');
      expect(result.status, SharedLibrarySyncStatus.success, reason: what);
    });
  }

  test('a suggestion copied under another name is not taken in', () async {
    final (svc, t) = await library();
    final signed = await signSuggestion(
      {
        'id': 'orig',
        'siteId': 's1',
        'memberId': 'b',
        'memberName': 'b',
        'note': 'deeper than charted',
        'fields': {'maxDepth': 40},
        'createdAt': '2026-10-01T00:00:00.000Z',
      },
      await testMemberKey('b'),
      libraryId: 'L',
    );
    await t.writeRaw(
      'suggestions/suggestion-copy.json',
      bytes(jsonEncode(signed)),
    );
    await svc.sync('L', diverId: 'd-a');
    Future<List<String>> incoming() async => [
      for (final s in await SharedLibraryStore().suggestions(
        'L',
        direction: SharedSiteSuggestion.incoming,
      ))
        s.fileId,
    ];
    expect(await incoming(), isEmpty);
    // Under its own name it is taken in.
    await t.writeRaw(
      'suggestions/suggestion-orig.json',
      bytes(jsonEncode(signed)),
    );
    await svc.sync('L', diverId: 'd-a');
    expect(await incoming(), ['orig']);
  });

  test('a roles file nobody can read leaves the trusted roles', () async {
    final (svc, t) = await library();
    final before = (await SharedLibraryStore().getLibrary('L'))!.roles;
    await t.writeRaw('roles.json', bytes('{"version": "9"}'));
    final result = await svc.sync('L', diverId: 'd-a');
    // The sync goes on, reading only, as for any roles it refused.
    expect(result.status, SharedLibrarySyncStatus.readOnly);
    final after = (await SharedLibraryStore().getLibrary('L'))!;
    expect(after.roles, before);
    expect(after.rolesRejected, isTrue);
  });

  test('an unreadable member card still lists its member', () async {
    final (svc, t) = await library();
    await t.writeRaw('members/member-x.json', bytes('SBE1x'));
    await svc.sync('L', diverId: 'd-a');
    final members = await SharedLibraryStore().getMembers('L');
    expect(members.map((m) => m.memberId), contains('x'));
  });

  test('a key of the wrong length is no valid signer', () async {
    expect(
      await LibrarySigner.verify(
        publicKey: 'AAAA',
        message: [1, 2, 3],
        signature: 'AAAA',
      ),
      isFalse,
    );
  });
}
