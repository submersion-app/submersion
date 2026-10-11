import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';

/// Builds a MacDive-style UDDF holding one dive per entry of [operators], in
/// order. A null operator writes no `<diveoperator>`; a non-null [centerLink]
/// adds a `<link>` to a center declared in the file.
String _uddf(
  List<String?> operators, {
  String? declaredCenter,
  String? centerLink,
  String? siteCountry,
}) {
  final dives = StringBuffer();
  for (var i = 0; i < operators.length; i++) {
    final op = operators[i];
    dives.write('''
    <dive id="d-$i">
      <informationbeforedive>
        ${siteCountry != null ? '<link ref="site-1" />' : ''}
        ${centerLink != null ? '<link ref="$centerLink" />' : ''}
        <datetime>2024-06-${'${i + 1}'.padLeft(2, '0')}T09:00:00</datetime>
      </informationbeforedive>
      <informationafterdive>
        <greatestdepth>18</greatestdepth>
        <diveduration>2400</diveduration>
        ${op != null ? '<diveoperator>$op</diveoperator>' : ''}
      </informationafterdive>
      <samples><waypoint><divetime>0</divetime><depth>0</depth></waypoint></samples>
    </dive>''');
  }
  final site = siteCountry == null
      ? ''
      : '''
  <divesite>
    <site id="site-1">
      <name>Reef</name>
      <geography><address><country>$siteCountry</country></address></geography>
    </site>
  </divesite>''';
  final centers = declaredCenter == null
      ? ''
      : '''
  <applicationdata><submersion><divecenters>
    <center id="center_declared"><name>$declaredCenter</name></center>
  </divecenters></submersion></applicationdata>''';
  return '''<?xml version="1.0" encoding="UTF-8" ?>
<uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
  <generator><name>MacDive</name></generator>
$site
$centers
  <profiledata><repetitiongroup id="rg-1">
$dives
  </repetitiongroup></profiledata>
</uddf>''';
}

void main() {
  final service = UddfFullImportService();

  group('UDDF dive operator becomes a dive center (#3211)', () {
    test('an operator creates a dive center and links the dive', () async {
      final r = await service.importAllDataFromUddf(
        _uddf(['Nautilus Liveaboards']),
      );

      expect(r.diveCenters, hasLength(1));
      final center = r.diveCenters.single;
      expect(center['name'], 'Nautilus Liveaboards');
      final dive = r.dives.single;
      expect(dive['diveCenterRef'], center['uddfId']);
      expect(center['uddfId'], isNotNull);
      expect(
        dive['diveOperator'],
        'Nautilus Liveaboards',
        reason: 'the free-text operator is still kept',
      );
    });

    test('dives sharing an operator share one dive center', () async {
      final r = await service.importAllDataFromUddf(
        _uddf(['Blue Dive', 'Blue Dive', 'blue dive ', 'Reef Divers']),
      );

      expect(
        r.diveCenters.map((c) => c['name']),
        unorderedEquals(['Blue Dive', 'Reef Divers']),
      );
      final refs = r.dives.map((d) => d['diveCenterRef']).toList();
      expect(refs[0], refs[1]);
      expect(refs[0], refs[2], reason: 'case and padding do not split it');
      expect(refs[3], isNot(refs[0]));
    });

    test('the center takes the country of the site it was used at', () async {
      final r = await service.importAllDataFromUddf(
        _uddf(['Blue Dive'], siteCountry: 'Mexico'),
      );

      expect(r.diveCenters.single['country'], 'Mexico');
    });

    test('a dive without an operator gets no center', () async {
      final r = await service.importAllDataFromUddf(_uddf([null, '   ']));

      expect(r.diveCenters, isEmpty);
      expect(r.dives.map((d) => d['diveCenterRef']), everyElement(isNull));
    });

    test('a dive that already links a center keeps that link', () async {
      final r = await service.importAllDataFromUddf(
        _uddf(
          ['Somebody Else'],
          declaredCenter: 'Declared Center',
          centerLink: 'center_declared',
        ),
      );

      expect(r.diveCenters, hasLength(1));
      expect(r.dives.single['diveCenterRef'], 'center_declared');
    });

    test('a link to an undeclared center falls back to the operator', () async {
      final r = await service.importAllDataFromUddf(
        _uddf(['Blue Dive'], centerLink: 'center_missing'),
      );

      expect(r.diveCenters.single['name'], 'Blue Dive');
      expect(r.dives.single['diveCenterRef'], r.diveCenters.single['uddfId']);
    });

    test('a new center never reuses the id of a declared one', () async {
      // The file declares a center whose id looks like a synthesized one but
      // whose name differs, so the operator still needs a center of its own.
      // Two centers sharing an id would leave the importer's id mapping
      // pointing at only one of them.
      const uddf = '''<?xml version="1.0" encoding="UTF-8" ?>
<uddf xmlns="http://www.streit.cc/uddf/3.2/" version="3.2.1">
  <generator><name>MacDive</name></generator>
  <applicationdata><submersion><divecenters>
    <center id="diveoperator:blue dive"><name>Other Shop</name></center>
  </divecenters></submersion></applicationdata>
  <profiledata><repetitiongroup id="rg-1">
    <dive id="d-0">
      <informationbeforedive><datetime>2024-06-01T09:00:00</datetime></informationbeforedive>
      <informationafterdive>
        <greatestdepth>18</greatestdepth><diveduration>2400</diveduration>
      </informationafterdive>
      <samples><waypoint><divetime>0</divetime><depth>0</depth></waypoint></samples>
    </dive>
    <dive id="d-1">
      <informationbeforedive><datetime>2024-06-02T09:00:00</datetime></informationbeforedive>
      <informationafterdive>
        <greatestdepth>18</greatestdepth><diveduration>2400</diveduration>
        <diveoperator>Blue Dive</diveoperator>
      </informationafterdive>
      <samples><waypoint><divetime>0</divetime><depth>0</depth></waypoint></samples>
    </dive>
  </repetitiongroup></profiledata>
</uddf>''';
      final r = await service.importAllDataFromUddf(uddf);

      final ids = r.diveCenters.map((c) => c['uddfId']).toList();
      expect(ids, hasLength(2));
      expect(ids.toSet(), hasLength(2), reason: 'ids must stay unique');
      final blue = r.diveCenters.singleWhere((c) => c['name'] == 'Blue Dive');
      expect(r.dives[1]['diveCenterRef'], blue['uddfId']);
    });

    test('an operator named like a declared center links to it', () async {
      final r = await service.importAllDataFromUddf(
        _uddf(['Declared Center'], declaredCenter: 'Declared Center'),
      );

      expect(r.diveCenters, hasLength(1), reason: 'no duplicate center');
      expect(r.dives.single['diveCenterRef'], 'center_declared');
    });
  });
}
