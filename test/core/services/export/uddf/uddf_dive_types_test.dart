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

/// A third-party file: an unrecognised type and a built-in one, and no
/// `<submersion><divetypes>` block declaring either.
const _uddfCustomType = '''<uddf version="3.2.1">
  <profiledata>
    <repetitiongroup id="g">
      <dive id="d">
        <informationbeforedive>
          <datetime>2025-03-19T08:19:54</datetime>
          <divetype>Cenote</divetype>
          <divetype>night</divetype>
        </informationbeforedive>
      </dive>
    </repetitiongroup>
  </profiledata>
</uddf>''';

/// The same unrecognised type, but declared by the file itself.
const _uddfDeclaredType = '''<uddf version="3.2.1">
  <profiledata>
    <repetitiongroup id="g">
      <dive id="d">
        <informationbeforedive>
          <datetime>2025-03-19T08:19:54</datetime>
          <divetype>Cenote</divetype>
        </informationbeforedive>
      </dive>
    </repetitiongroup>
  </profiledata>
  <applicationdata>
    <submersion>
      <divetypes>
        <divetype id="cenote">
          <name>Cenote dives</name>
        </divetype>
      </divetypes>
    </submersion>
  </applicationdata>
</uddf>''';

/// Submersion's own export writes `dive.diveTypeIds` into `<divetype>`, so
/// the element text is a stored id, and a custom id carries underscores.
const _uddfOwnExport = '''<uddf version="3.2.1">
  <profiledata>
    <repetitiongroup id="g">
      <dive id="d">
        <informationbeforedive>
          <datetime>2025-03-19T08:19:54</datetime>
          <divetype>search_recovery_1a2b3c4d</divetype>
        </informationbeforedive>
      </dive>
    </repetitiongroup>
  </profiledata>
  <applicationdata>
    <submersion>
      <divetypes>
        <divetype id="search_recovery_1a2b3c4d">
          <name>Search &amp; Recovery</name>
        </divetype>
      </divetypes>
    </submersion>
  </applicationdata>
</uddf>''';

void main() {
  test('UDDF import collects multiple <divetype> elements', () async {
    final service = UddfFullImportService();
    final result = await service.importAllDataFromUddf(_uddfMultiType);
    final ids = result.dives.first['diveTypeIds'] as List;

    expect(ids.length, 2, reason: 'both <divetype> elements are collected');
    expect(ids, containsAll(['shore', 'wreck']));
  });

  // Issue #2203: a type the mapper does not recognise is preserved as its
  // slug, so the file must also yield a custom dive type for it. Otherwise
  // the junction row points at no dive_types row and the type is missing
  // from the picker and from filters.
  test('an unrecognised <divetype> yields a custom dive type', () async {
    final service = UddfFullImportService();
    final result = await service.importAllDataFromUddf(_uddfCustomType);

    expect(result.dives.first['diveTypeIds'], containsAll(['cenote', 'night']));
    expect(result.customDiveTypes, hasLength(1));
    final type = result.customDiveTypes.single;
    expect(type['id'], 'cenote');
    // Named as the file spelled it, not as the slug reads.
    expect(type['name'], 'Cenote');
    expect(type['isBuiltIn'], isFalse);
  });

  test('a built-in <divetype> yields no custom dive type', () async {
    final service = UddfFullImportService();
    final result = await service.importAllDataFromUddf(_uddfMultiType);

    expect(result.customDiveTypes, isEmpty);
  });

  test('a type the file already declares is not duplicated', () async {
    final service = UddfFullImportService();
    final result = await service.importAllDataFromUddf(_uddfDeclaredType);

    expect(result.customDiveTypes, hasLength(1));
    // The file's own declaration wins: the harvest must not overwrite the
    // diver's name for the type with the element text.
    expect(result.customDiveTypes.single['name'], 'Cenote dives');
  });

  // DiveTypeEntity.generateSlug strips underscores, so running a stored id
  // through the free-text mapper would turn 'search_recovery_1a2b3c4d' into
  // 'searchrecovery1a2b3c4d': the dive would stop pointing at the type the
  // file declares, and a duplicate custom type would be created beside it.
  test('a declared custom type id survives its own export', () async {
    final service = UddfFullImportService();
    final result = await service.importAllDataFromUddf(_uddfOwnExport);

    expect(result.dives.first['diveTypeIds'], ['search_recovery_1a2b3c4d']);
    expect(result.customDiveTypes, hasLength(1));
    expect(result.customDiveTypes.single['id'], 'search_recovery_1a2b3c4d');
    expect(result.customDiveTypes.single['name'], 'Search & Recovery');
  });
}
