import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_detailed.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_naui.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_padi.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_professional.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_simple.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  final dives = [
    Dive(
      id: 'dive-1',
      diveNumber: 1,
      dateTime: DateTime(2026, 3, 28, 10, 0),
      bottomTime: const Duration(minutes: 45),
      runtime: const Duration(minutes: 50),
      maxDepth: 25.0,
      avgDepth: 18.0,
      waterTemp: 22.0,
      tanks: const [],
      profile: const [],
      equipment: const [],
      notes: 'Great dive!',
      photoIds: const [],
      sightings: const [],
      weights: const [],
      tags: const [],
    ),
    Dive(
      id: 'dive-2',
      diveNumber: 2,
      dateTime: DateTime(2026, 3, 29, 10, 0),
      bottomTime: const Duration(minutes: 30),
      maxDepth: 18.0,
      waterTemp: 24.0,
      tanks: const [],
      profile: const [],
      equipment: const [],
      notes: '',
      photoIds: const [],
      sightings: const [],
      weights: const [],
      tags: const [],
    ),
  ];

  group('PDF templates with bottomTime', () {
    test('PdfTemplateSimple generates PDF with bottomTime', () async {
      final template = PdfTemplateSimple();
      final bytes = await template.buildPdf(
        dives: dives,
        pageSize: PdfPageSize.a4,
      );
      expect(bytes, isNotEmpty);
    });

    test('PdfTemplateDetailed generates PDF with bottomTime', () async {
      final template = PdfTemplateDetailed();
      final bytes = await template.buildPdf(
        dives: dives,
        pageSize: PdfPageSize.a4,
      );
      expect(bytes, isNotEmpty);
    });

    test('PdfTemplateProfessional generates PDF with bottomTime', () async {
      final template = PdfTemplateProfessional();
      final bytes = await template.buildPdf(
        dives: dives,
        pageSize: PdfPageSize.a4,
      );
      expect(bytes, isNotEmpty);
    });

    test('PdfTemplatePadi generates PDF with bottomTime', () async {
      final template = PdfTemplatePadi();
      final bytes = await template.buildPdf(
        dives: dives,
        pageSize: PdfPageSize.a4,
      );
      expect(bytes, isNotEmpty);
    });

    test('PdfTemplateNaui generates PDF with bottomTime', () async {
      final template = PdfTemplateNaui();
      final bytes = await template.buildPdf(
        dives: dives,
        pageSize: PdfPageSize.a4,
      );
      expect(bytes, isNotEmpty);
    });
  });
}
