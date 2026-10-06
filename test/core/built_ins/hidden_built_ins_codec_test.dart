import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/built_ins/hidden_built_ins_codec.dart';

void main() {
  group('encodeHiddenBuiltIns', () {
    test('nothing hidden encodes to null', () {
      expect(encodeHiddenBuiltIns(const {}), isNull);
      expect(encodeHiddenBuiltIns(const {'diveTypes': <String>{}}), isNull);
    });

    test('sorts keys and ids so equal contents encode equal', () {
      final a = encodeHiddenBuiltIns({
        'siteTypes': {'wall', 'lake'},
        'diveRoles': {'solo'},
      });
      final b = encodeHiddenBuiltIns({
        'diveRoles': {'solo'},
        'siteTypes': {'lake', 'wall'},
      });
      expect(a, b);
      expect(a, '{"diveRoles":["solo"],"siteTypes":["lake","wall"]}');
    });

    test('omits empty catalogs', () {
      expect(
        encodeHiddenBuiltIns({
          'diveRoles': <String>{},
          'diveTypes': {'night'},
        }),
        '{"diveTypes":["night"]}',
      );
    });
  });

  group('decodeHiddenBuiltIns', () {
    test('null and empty read as nothing hidden', () {
      expect(decodeHiddenBuiltIns(null), isEmpty);
      expect(decodeHiddenBuiltIns(''), isEmpty);
    });

    test('malformed or wrongly typed input reads as nothing hidden', () {
      expect(decodeHiddenBuiltIns('{not json'), isEmpty);
      expect(decodeHiddenBuiltIns('["a"]'), isEmpty);
      expect(decodeHiddenBuiltIns('42'), isEmpty);
    });

    test('skips entries that are not a list of strings', () {
      expect(
        decodeHiddenBuiltIns(
          '{"diveTypes":"night","siteTypes":[1,"lake",""],"diveRoles":[]}',
        ),
        {
          'siteTypes': {'lake'},
        },
      );
    });

    test('keeps unknown catalog keys through a round trip', () {
      const raw = '{"diveTypes":["night"],"futureKind":["x"]}';
      expect(encodeHiddenBuiltIns(decodeHiddenBuiltIns(raw)), raw);
    });
  });
}
