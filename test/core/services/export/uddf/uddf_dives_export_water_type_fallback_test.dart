import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Issue #793: the dives-only UDDF export (`UddfExportService`, distinct
/// from `UddfExportBuilders.buildDiveElement` used by the full backup
/// export) must also fall back to the site's water type and entry method
/// when the dive has none of its own.
void main() {
  const site = DiveSite(
    id: 'site-1',
    name: 'Blue Hole',
    waterType: WaterType.fresh,
    entryMethod: EntryMethod.shore,
  );

  Future<XmlDocument> export(Dive dive) async => XmlDocument.parse(
    await UddfExportService().generateDivesUddfContent([dive]),
  );

  test('falls back to the site\'s water type and entry method', () async {
    final dive = Dive(id: 'd1', dateTime: DateTime(2026, 3, 1, 9), site: site);

    final doc = await export(dive);

    expect(
      doc.findAllElements('watertype').single.innerText,
      WaterType.fresh.name,
    );
    expect(
      doc.findAllElements('entrytype').single.innerText,
      EntryMethod.shore.name,
    );
  });

  test('a dive\'s own values are authoritative over the site\'s', () async {
    final dive = Dive(
      id: 'd1',
      dateTime: DateTime(2026, 3, 1, 9),
      waterType: WaterType.brackish,
      entryMethod: EntryMethod.boat,
      site: site,
    );

    final doc = await export(dive);

    expect(
      doc.findAllElements('watertype').single.innerText,
      WaterType.brackish.name,
    );
    expect(
      doc.findAllElements('entrytype').single.innerText,
      EntryMethod.boat.name,
    );
  });
}
