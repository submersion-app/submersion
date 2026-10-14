import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  group('SharedLibraryRoles', () {
    test('owner beats editor, unknown is reader, ids kept verbatim', () {
      final roles = SharedLibraryRoles.fromJson({
        'owners': ['a', 'ghost'],
        'editors': ['a', 'b'],
      });
      expect(roles.roleOf('a'), SharedLibraryRole.owner);
      expect(roles.roleOf('b'), SharedLibraryRole.editor);
      expect(roles.roleOf('c'), SharedLibraryRole.reader);
      expect(roles.toJson()['owners'], containsAll(['a', 'ghost']));
    });

    test('missing lists parse as empty', () {
      expect(
        SharedLibraryRoles.fromJson({}).roleOf('x'),
        SharedLibraryRole.reader,
      );
    });

    test('withRole moves a member between lists', () {
      const roles = SharedLibraryRoles(owners: {'a'}, editors: {'b'});
      final demoted = roles.withRole('a', SharedLibraryRole.editor);
      expect(demoted.owners, isEmpty);
      expect(demoted.editors, {'a', 'b'});
      final reader = demoted.withRole('b', SharedLibraryRole.reader);
      expect(reader.editors, {'a'});
    });
  });

  test('effectiveRole caps at reader when credentials were refused', () {
    expect(
      effectiveRole(listed: SharedLibraryRole.owner, readOnlyDetected: true),
      SharedLibraryRole.reader,
    );
    expect(
      effectiveRole(listed: SharedLibraryRole.editor, readOnlyDetected: false),
      SharedLibraryRole.editor,
    );
  });

  test('DiveSite.copyWith carries sharedLibraryId and can clear it', () {
    const site = DiveSite(id: 's', name: 'n');
    final lib = site.copyWith(sharedLibraryId: 'L');
    expect(lib.isLibrarySite, isTrue);
    expect(lib.copyWith(clearSharedLibraryId: true).sharedLibraryId, isNull);
    expect(lib.copyWith(id: 'other').id, 'other');
  });

  test('SharedLibraryLayout names files under their folders', () {
    expect(SharedLibraryLayout.siteFile('x'), 'sites/x.json');
    expect(SharedLibraryLayout.memberFile('m'), 'members/m.json');
  });

  test('two claims of one field with other values are two clocks', () {
    final a = FieldClock.claim('m', 'Blue');
    final b = FieldClock.claim('m', 'Blue Hole');
    expect(a.hlc, isNot(b.hlc));
    expect(FieldClock.claim('m', 'Blue').hlc, a.hlc);
    // Any real edit wins over a claim, and a claim marks no edit.
    expect(a.hlc.compareTo(const Hlc(1, 0, 'm')), lessThan(0));
    expect(a.marksEdit, isFalse);
    expect(newestClockOf([a, b]), isNull);
  });
}
