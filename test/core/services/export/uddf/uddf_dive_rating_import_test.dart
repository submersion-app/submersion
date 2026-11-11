import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';

/// UDDF's `<ratingvalue>` runs from 1 to 10. Diving Log writes it that way,
/// with 0 for an unrated dive, so its dives arrived with up to ten stars and
/// some with a rating of 0 (issue #4415). Submersion's own files have always
/// written the 1 to 5 star count, and keep reading as written.
String _uddf({String? generator, required List<String> ratings}) {
  final dives = StringBuffer();
  for (var i = 0; i < ratings.length; i++) {
    dives.write('''
      <dive id="d-$i">
        <informationbeforedive>
          <datetime>2018-02-${(i + 10).toString()}T10:00:00</datetime>
        </informationbeforedive>
        <informationafterdive>
          <greatestdepth>20.0</greatestdepth>
          <diveduration>1800</diveduration>
          <rating><ratingvalue>${ratings[i]}</ratingvalue></rating>
        </informationafterdive>
      </dive>''');
  }
  final header = generator == null
      ? ''
      : '<generator><name>$generator</name></generator>';
  return '''<?xml version="1.0" encoding="UTF-8" ?>
<uddf version="3.2.1">
  $header
  <profiledata>
    <repetitiongroup id="rg-1">$dives
    </repetitiongroup>
  </profiledata>
</uddf>''';
}

Future<List<Object?>> _ratings(String uddf) async {
  final result = await UddfFullImportService().importAllDataFromUddf(uddf);
  final byTime = [...result.dives]
    ..sort(
      (a, b) =>
          (a['dateTime'] as DateTime).compareTo(b['dateTime'] as DateTime),
    );
  return [for (final dive in byTime) dive['rating']];
}

void main() {
  test('a Diving Log file is read on the 1 to 10 scale', () async {
    expect(
      await _ratings(
        _uddf(generator: 'Diving Log', ratings: ['6', '8', '10', '1', '3']),
      ),
      [3, 4, 5, 1, 2],
    );
  });

  test('a file with no generator is read on the 1 to 10 scale', () async {
    expect(await _ratings(_uddf(ratings: ['10', '4'])), [5, 2]);
  });

  test('a rating of 0 is an unrated dive', () async {
    expect(await _ratings(_uddf(generator: 'Diving Log', ratings: ['0'])), [
      null,
    ]);
  });

  test('a Submersion file keeps its 1 to 5 star count', () async {
    expect(
      await _ratings(_uddf(generator: 'Submersion', ratings: ['1', '3', '5'])),
      [1, 3, 5],
    );
  });

  test(
    'a Submersion backup holding an earlier out-of-scale import is repaired',
    () async {
      // A backup taken after a Diving Log import stored 6 and 0, as the v358
      // rung would find them.
      expect(
        await _ratings(_uddf(generator: 'Submersion', ratings: ['6', '0'])),
        [3, null],
      );
    },
  );
}
