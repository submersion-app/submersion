import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';

const _uddfMultiType = '''<uddf version="3.2.1">
  <profiledata>
    <repetitiongroup id="g">
      <dive id="d">
        <informationbeforedive>
          <datetime>2025-03-19T08:19:54</datetime>
          <divetype>shore</divetype>
          <divetype>wreck</divetype>
        </informationbeforedive>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>''';

void main() {
  test('UDDF import collects multiple <divetype> elements', () async {
    final service = UddfFullImportService();
    final result = await service.importAllDataFromUddf(_uddfMultiType);
    final ids = result.dives.first['diveTypeIds'] as List;

    expect(ids.length, 2, reason: 'both <divetype> elements are collected');
    expect(ids, containsAll(['shore', 'wreck']));
  });
}
