import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/cloud_identifier_source.dart';

void main() {
  test('asks in chunks and drops ids with no cloud id', () async {
    final calls = <List<String>>[];
    final source = PhotoManagerCloudIdentifierSource.withFetch(
      supported: true,
      chunkSize: 2,
      fetch: (ids) async {
        calls.add(ids);
        return {
          for (final id in ids)
            id: switch (id) {
              'a' => 'C-a',
              'b' => null,
              'c' => '',
              _ => 'C-$id',
            },
        };
      },
    );

    final ids = await source.cloudIdentifiers(['a', 'b', 'c', 'd', 'e']);

    expect(calls, [
      ['a', 'b'],
      ['c', 'd'],
      ['e'],
    ]);
    expect(ids, {'a': 'C-a', 'd': 'C-d', 'e': 'C-e'});
  });

  test('off Apple platforms it answers nothing and asks nothing', () async {
    var asked = false;
    final source = PhotoManagerCloudIdentifierSource.withFetch(
      supported: false,
      fetch: (ids) async {
        asked = true;
        return {};
      },
    );

    expect(await source.cloudIdentifiers(['a']), isEmpty);
    expect(asked, isFalse);
  });

  test('an empty request asks nothing', () async {
    var asked = false;
    final source = PhotoManagerCloudIdentifierSource.withFetch(
      supported: true,
      fetch: (ids) async {
        asked = true;
        return {};
      },
    );

    expect(await source.cloudIdentifiers(const []), isEmpty);
    expect(asked, isFalse);
  });

  test('says whether this platform can answer at all', () {
    Future<Map<String, String?>> fetch(List<String> ids) async => {};
    expect(
      PhotoManagerCloudIdentifierSource.withFetch(
        supported: true,
        fetch: fetch,
      ).isSupported,
      isTrue,
    );
    expect(
      PhotoManagerCloudIdentifierSource.withFetch(
        supported: false,
        fetch: fetch,
      ).isSupported,
      isFalse,
    );
  });
}
