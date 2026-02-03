import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_builder.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_detailed.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_naui.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_padi.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_professional.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_simple.dart';

/// Factory for creating PDF template builders.
///
/// Use [getBuilder] to get the appropriate template builder for a given
/// template type. The factory caches builder instances for reuse.
class PdfTemplateFactory {
  static final PdfTemplateFactory _instance = PdfTemplateFactory._internal();

  factory PdfTemplateFactory() => _instance;

  PdfTemplateFactory._internal();

  /// Cache of template builders.
  final Map<PdfTemplate, PdfTemplateBuilder> _builders = {};

  /// Get a template builder for the specified template type.
  ///
  /// Builders are cached and reused for efficiency.
  PdfTemplateBuilder getBuilder(PdfTemplate template) {
    return _builders.putIfAbsent(template, () => _createBuilder(template));
  }

  /// Create a new builder instance for the specified template type.
  PdfTemplateBuilder _createBuilder(PdfTemplate template) {
    switch (template) {
      case PdfTemplate.simple:
        return PdfTemplateSimple();
      case PdfTemplate.detailed:
        return PdfTemplateDetailed();
      case PdfTemplate.professional:
        return PdfTemplateProfessional();
      case PdfTemplate.padiStyle:
        return PdfTemplatePadi();
      case PdfTemplate.nauiStyle:
        return PdfTemplateNaui();
    }
  }

  /// Get all available template builders.
  ///
  /// Useful for populating template selection UI.
  List<PdfTemplateBuilder> getAllBuilders() {
    return PdfTemplate.values.map((t) => getBuilder(t)).toList();
  }
}
