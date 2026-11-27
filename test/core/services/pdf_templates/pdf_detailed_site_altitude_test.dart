import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_detailed.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Issue #5040: the printed logbook gives a dive's altitude as every other
/// reader does, its own else its site's.
void main() {
  final template = PdfTemplateDetailed();
  const units = UnitFormatter(AppSettings());

  String? altitudeOf(Dive dive) {
    for (final field in template.conditionFieldsForTest(dive, units: units)) {
      if (field.label == 'Altitude') return field.value;
    }
    return null;
  }

  final atLake = Dive(
    id: 'd1',
    dateTime: DateTime(2026, 3, 28, 10),
    notes: '',
    site: const DiveSite(id: 'lake', name: 'Lake', altitude: 450),
  );

  test("a dive with no altitude prints its site's", () {
    expect(altitudeOf(atLake), units.formatAltitude(450));
  });

  test("the dive's own altitude wins over its site's", () {
    expect(
      altitudeOf(atLake.copyWith(altitude: 1200)),
      units.formatAltitude(1200),
    );
  });

  test('no altitude on the dive or its site prints none', () {
    expect(altitudeOf(atLake.copyWith(clearSite: true)), isNull);
  });
}
