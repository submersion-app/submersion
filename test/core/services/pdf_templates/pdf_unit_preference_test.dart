import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_shared_components.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_builder.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_detailed.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_naui.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_padi.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_simple.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/pdf_text.dart';

/// Every template printed hardcoded metric suffixes off the metric-base Dive
/// fields, ignoring the diver's unit settings entirely. These tests pin the
/// conversion for each template so a future edit cannot quietly reintroduce a
/// literal 'm' or '°C'.
void main() {
  final dive = Dive(
    id: 'd1',
    diveNumber: 1,
    dateTime: DateTime(2026, 3, 28, 14, 30),
    runtime: const Duration(minutes: 50),
    maxDepth: 30.0,
    avgDepth: 18.0,
    waterTemp: 20.0,
    tanks: const [DiveTank(id: 't1', startPressure: 200, endPressure: 50)],
  );

  final dates = PdfDateFormatter(
    dateFormat: DateFormatPreference.ddmmyyyy,
    timeFormat: TimeFormat.twentyFourHour,
  );

  const metricSettings = AppSettings();
  const imperialSettings = AppSettings(
    depthUnit: DepthUnit.feet,
    temperatureUnit: TemperatureUnit.fahrenheit,
    pressureUnit: PressureUnit.psi,
    volumeUnit: VolumeUnit.cubicFeet,
    weightUnit: WeightUnit.pounds,
    altitudeUnit: AltitudeUnit.feet,
  );

  const metric = UnitFormatter(metricSettings);
  const imperial = UnitFormatter(imperialSettings);

  final builders = <String, PdfTemplateBuilder Function()>{
    'Simple': PdfTemplateSimple.new,
    'Detailed': PdfTemplateDetailed.new,
    'PADI': PdfTemplatePadi.new,
    'NAUI': PdfTemplateNaui.new,
  };

  Future<String> render(
    PdfTemplateBuilder builder,
    UnitFormatter units,
  ) async => pdfVisibleText(
    await builder.buildPdf(
      dives: [dive],
      pageSize: PdfPageSize.a4,
      dates: dates,
      units: units,
    ),
  );

  builders.forEach((name, make) {
    group('$name template units', () {
      test('renders feet and fahrenheit for an imperial diver', () async {
        final text = await render(make(), imperial);
        expect(text, contains('98.4ft'), reason: '30 m is 98.4 ft');
        expect(text, contains('68°F'), reason: '20 C is 68 F');
        expect(text, isNot(contains('30.0m')));
        expect(text, isNot(contains('20°C')));
      });

      test('renders meters and celsius for a metric diver', () async {
        final text = await render(make(), metric);
        expect(text, contains('30.0m'));
        expect(text, contains('20°C'));
        expect(text, isNot(contains('98.4ft')));
      });
    });
  });

  test(
    'Detailed renders cylinder pressure in psi for an imperial diver',
    () async {
      final text = await render(PdfTemplateDetailed(), imperial);
      expect(text, contains('2901'), reason: '200 bar is 2901 psi');
      expect(text, contains('psi'));
    },
  );

  test(
    'Detailed renders cylinder pressure in bar for a metric diver',
    () async {
      final text = await render(PdfTemplateDetailed(), metric);
      expect(text, contains('200'));
      expect(text, contains('bar'));
    },
  );

  group('a half-filled pressure pair stays readable', () {
    // The range prints what the diver recorded rather than suppressing
    // itself, so one endpoint can be the '--' placeholder. Concatenating
    // that against a '-' separator produced '200---', three dashes with no
    // space, which reads as a mangled number rather than a missing value.
    final halfFilled = dive.copyWith(
      tanks: const [DiveTank(id: 't1', startPressure: 200)],
    );

    Future<String> renderHalfFilled(PdfTemplateBuilder builder) async =>
        pdfVisibleText(
          await builder.buildPdf(
            dives: [halfFilled],
            pageSize: PdfPageSize.a4,
            dates: dates,
            units: metric,
          ),
        );

    test('PADI separates the endpoints', () async {
      final text = await renderHalfFilled(PdfTemplatePadi());
      expect(text, isNot(contains('---')));
      expect(text, contains('200'));
    });

    test('Detailed separates the endpoints', () async {
      final text = await renderHalfFilled(PdfTemplateDetailed());
      expect(text, isNot(contains('---')));
      expect(text, contains('200'));
    });

    test('keeps the unit that the missing endpoint used to take with it', () {
      // formatPressure(null) returns a bare '--', so appending it dropped
      // the unit from the whole field: the range read '200---' with no bar
      // or psi anywhere on it.
      for (final builder in [PdfTemplatePadi(), PdfTemplateDetailed()]) {
        expect(renderHalfFilled(builder), completion(contains('bar')));
      }
    });

    test('prints the placeholder for a cylinder with no pressure at all', () {
      expect(
        pdfPressureRange(metric, null, null),
        '--',
        reason: 'a bare unit with nothing in front of it is not a value',
      );
    });
  });
}
