import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/pdf/pdf_export_service.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_builder.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/sighting_abundance.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/pdf_roboto.dart';
import '../../../../helpers/test_database.dart';

/// Records the dives a template is asked to print, and prints nothing.
class _RecordingBuilder implements PdfTemplateBuilder {
  List<Dive>? dives;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #buildPdf) {
      dives = invocation.namedArguments[#dives] as List<Dive>;
      return Future<List<int>>.value(const <int>[]);
    }
    return super.noSuchMethod(invocation);
  }
}

/// Issue #4337 follow-up: the dive list carries no sightings, so the
/// detailed logbook printed no marine life until the export read them.
void main() {
  final dates = PdfDateFormatter(
    dateFormat: DateFormatPreference.ddmmyyyy,
    timeFormat: TimeFormat.twentyFourHour,
  );
  const units = UnitFormatter(AppSettings());

  setUpAll(loadPdfRoboto);
  tearDownAll(unloadPdfRoboto);

  setUp(() async {
    await setUpTestDatabase();
    await DiveRepository().createDive(
      Dive(id: 'd1', diveNumber: 1, dateTime: DateTime.utc(2026, 3, 1, 9)),
    );
    final species = SpeciesRepository();
    final turtle = await species.createSpecies(
      commonName: 'Test Turtle',
      category: SpeciesCategory.turtle,
    );
    await species.addSighting(
      diveId: 'd1',
      speciesId: turtle.id,
      abundance: SightingAbundance.few,
    );
  });

  tearDown(tearDownTestDatabase);

  Future<List<Dive>> printed(PdfTemplate template) async {
    final builder = _RecordingBuilder();
    final service = PdfExportService(templateFor: (_) => builder);
    final listed = await DiveRepository().getAllDives();
    expect(listed.single.sightings, isEmpty, reason: 'the list has none');
    await service.generateDivePdfBytes(
      listed,
      dates: dates,
      units: units,
      options: PdfExportOptions(template: template),
      gearArrangement: EquipmentArrangement.defaults,
    );
    return builder.dives!;
  }

  test('the detailed logbook receives each dive its sightings', () async {
    final sighting = (await printed(PdfTemplate.detailed)).single.sightings;

    expect(sighting.single.speciesName, 'Test Turtle');
    expect(sighting.single.abundance, SightingAbundance.few);
  });

  test('a template that prints no marine life skips the read', () async {
    expect((await printed(PdfTemplate.simple)).single.sightings, isEmpty);
  });
}
