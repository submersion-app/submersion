// Issue #2927: the front roll (forward roll off a RIB tube) is a standard boat
// entry. UDDF stores the entry and exit method by EntryMethod.name, so a file
// carrying `frontRoll` must import as that method rather than dropping it.
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';

import '../../../../helpers/test_database.dart';

const _uddf = '''
<?xml version="1.0" encoding="UTF-8"?>
<uddf version="3.2.0">
  <profiledata>
    <repetitiongroup>
      <dive id="d1">
        <informationbeforedive>
          <datetime>2025-03-19T08:19:54</datetime>
          <entrytype>frontRoll</entrytype>
        </informationbeforedive>
        <informationafterdive>
          <exittype>frontRoll</exittype>
        </informationafterdive>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>
''';

void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  test('a frontRoll entry and exit type import as the front roll', () async {
    final result = await UddfFullImportService().importAllDataFromUddf(_uddf);
    final dive = result.dives.single;

    expect(dive['entryMethod'], EntryMethod.frontRoll);
    expect(dive['exitMethod'], EntryMethod.frontRoll);
  });
}
