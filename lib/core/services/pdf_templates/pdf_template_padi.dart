import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_localization.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/core/services/pdf_templates/pdf_profile_series.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_fonts.dart';
import 'package:submersion/core/services/pdf_templates/pdf_shared_components.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_builder.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/dive_participant_names.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';
import 'package:submersion/features/dive_log/presentation/formatters/visibility_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';

/// PADI-style PDF template mimicking PADI logbook format.
///
/// Uses PADI's blue color scheme and layout structure familiar to
/// PADI-certified divers. Displays 4 dives per page with sections
/// for dive data, conditions, equipment, and comments.
class PdfTemplatePadi extends PdfTemplateBuilder {
  // PADI brand color
  static const _padiBlue = PdfColor.fromInt(0xFF003087);
  static const _padiLightBlue = PdfColor.fromInt(0xFFE6EDF5);

  @override
  PdfTemplate get templateType => PdfTemplate.padiStyle;

  @override
  Future<List<int>> buildPdf({
    required List<Dive> dives,
    required PdfPageSize pageSize,
    required PdfDateFormatter dates,
    required UnitFormatter units,
    String? title,
    Map<String, List<Signature>>? diveSignatures,
    List<Certification>? certifications,
    Diver? diver,
    // Accepted for the shared builder contract; this template does not chart
    // profiles, show a portrait, or offer verification areas.
    Map<String, PdfProfileSeries>? profiles,
    Uint8List? diverPhoto,
    bool includeVerificationAreas = false,
    EquipmentArrangement gearArrangement = EquipmentArrangement.defaults,
    Map<String, DiveTypeEntity> diveTypesById = const {},
    Map<String, String> equipmentSetNamesById = const {},
    PdfLocalization? localization,
  }) async {
    final loc = localization ?? PdfLocalization.english();
    final l10n = loc.l10n;
    final documentTitle = title ?? l10n.settings_export_pdfDocumentTitle;
    final pdf = pw.Document(theme: await PdfFonts.instance.themeFor(loc));
    final pageFormat = getPageFormat(pageSize);

    // Cover page
    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        textDirection: loc.textDirection,
        build: (context) => _buildCoverPage(
          title: documentTitle,
          diveCount: dives.length,
          dates: dates,
          l10n: l10n,
          diver: diver,
          firstDiveDate: dives.isNotEmpty ? dives.last.dateTime : null,
          lastDiveDate: dives.isNotEmpty ? dives.first.dateTime : null,
        ),
      ),
    );

    // Certification cards page - highlight PADI certs
    if (certifications != null && certifications.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(32),
          textDirection: loc.textDirection,
          build: (context) => PdfSharedComponents.buildCertificationCardsBody(
            certifications: certifications,
            dates: dates,
            l10n: l10n,
            diver: diver,
            highlightAgency: 'padi',
            accentColor: _padiBlue,
          ),
        ),
      );
    }

    // Dive log pages (4 dives per page)
    const divesPerPage = 4;
    for (var i = 0; i < dives.length; i += divesPerPage) {
      final pageDives = dives.skip(i).take(divesPerPage).toList();

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(24),
          textDirection: loc.textDirection,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Page header
              _buildPageHeader(diver: diver, l10n: l10n),
              pw.SizedBox(height: 8),
              // Dive entries
              ...pageDives.expand(
                (dive) => [
                  _buildPadiDiveEntry(
                    dive,
                    dates: dates,
                    units: units,
                    l10n: l10n,
                    signatures: diveSignatures?[dive.id],
                  ),
                  pw.SizedBox(height: 8),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return await pdf.save();
  }

  pw.Widget _buildCoverPage({
    required String title,
    required int diveCount,
    required PdfDateFormatter dates,
    required AppLocalizations l10n,
    Diver? diver,
    DateTime? firstDiveDate,
    DateTime? lastDiveDate,
  }) {
    return pw.Center(
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          // PADI-style header bar
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 40),
            color: _padiBlue,
            child: pw.Center(
              child: pw.Text(
                l10n.pdf_diveLogBanner,
                style: const pw.TextStyle(
                  fontSize: 36,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  letterSpacing: 4,
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 40),
          if (diver != null) ...[
            pw.Text(
              diver.name,
              style: const pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: _padiBlue,
              ),
            ),
            pw.SizedBox(height: 16),
          ],
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _padiBlue, width: 2),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  '$diveCount',
                  style: const pw.TextStyle(
                    fontSize: 48,
                    fontWeight: pw.FontWeight.bold,
                    color: _padiBlue,
                  ),
                ),
                pw.Text(
                  l10n.pdf_loggedDives,
                  style: const pw.TextStyle(
                    fontSize: 16,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
          if (firstDiveDate != null && lastDiveDate != null) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              '${dates.date(firstDiveDate)} - ${dates.date(lastDiveDate)}',
              style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey600),
            ),
          ],
          pw.Spacer(),
          pw.Text(
            l10n.pdf_generated(dates.dateTime(DateTime.now())),
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
          ),
          pw.SizedBox(height: 20),
        ],
      ),
    );
  }

  pw.Widget _buildPageHeader({Diver? diver, required AppLocalizations l10n}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: _padiBlue,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            l10n.pdf_diveLogBanner,
            style: const pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          if (diver != null)
            pw.Text(
              diver.name,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
            ),
        ],
      ),
    );
  }

  pw.Widget _buildPadiDiveEntry(
    Dive dive, {
    required PdfDateFormatter dates,
    required UnitFormatter units,
    required AppLocalizations l10n,
    List<Signature>? signatures,
  }) {
    final tank = dive.tanks.isNotEmpty ? dive.tanks.first : null;
    final isTrainingDive =
        dive.diveTypeIds.any((t) => t.toLowerCase().contains('training')) ||
        dive.courseId != null;

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _padiBlue),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header row with dive number and date
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: _padiLightBlue,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    pw.Text(
                      l10n.pdf_diveNumber('${dive.diveNumber ?? '-'}'),
                      style: const pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: _padiBlue,
                      ),
                    ),
                    if (isTrainingDive) ...[
                      pw.SizedBox(width: 8),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: pw.BoxDecoration(
                          color: _padiBlue,
                          borderRadius: pw.BorderRadius.circular(3),
                        ),
                        child: pw.Text(
                          l10n.pdf_trainingBadge,
                          style: const pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                pw.Text(
                  dates.dateTime(dive.dateTime),
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
          ),
          // Content in PADI layout
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Site name
                pw.Text(
                  dive.site?.name ?? l10n.pdf_unknownSite,
                  style: const pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (dive.site?.country != null || dive.site?.region != null)
                  pw.Text(
                    [
                      dive.site?.region,
                      dive.site?.country,
                    ].where((s) => s != null).join(', '),
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                pw.SizedBox(height: 6),
                // Dive data row
                pw.Row(
                  children: [
                    _buildPadiField(
                      l10n.pdf_columnDepth,
                      units.formatDepth(dive.maxDepth),
                    ),
                    _buildPadiField(
                      l10n.pdf_columnTime,
                      l10n.pdf_minutesCompact(pdfDiveDurationMinutes(dive)),
                    ),
                    _buildPadiField(
                      l10n.pdf_columnTemp,
                      units.formatTemperature(dive.waterTemp),
                    ),
                    if (tank != null)
                      _buildPadiField(l10n.pdf_gas, tank.gasMix.name),
                  ],
                ),
                pw.SizedBox(height: 4),
                // Conditions row
                pw.Row(
                  children: [
                    // Measured distance from v144; pre-v144 dives fall back to
                    // their bucket label. Bare metres matches how this
                    // template renders depth.
                    _buildPadiField(
                      l10n.pdf_visibilityShort,
                      dive.visibilityMeters != null
                          ? units.formatDistance(dive.visibilityMeters!)
                          : dive.visibility != null
                          ? visibilityName(dive.visibility!, l10n)
                          : '-',
                    ),
                    if (tank != null) ...[
                      _buildPadiField(
                        l10n.pdf_air,
                        pdfPressureRange(
                          units,
                          tank.startPressure,
                          tank.endPressure,
                        ),
                      ),
                    ],
                    if (dive.effectiveWaterType != null)
                      _buildPadiField(
                        l10n.pdf_water,
                        dive.effectiveWaterType!.localizedName(l10n),
                      ),
                  ],
                ),
                // Notes (compact)
                if (dive.notes.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    dive.notes,
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                    maxLines: 2,
                  ),
                ],
                // Buddy/Instructor sign-off row
                pw.SizedBox(height: 6),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                  child: pw.Row(
                    children: [
                      _buildSignOffField(
                        l10n,
                        l10n.pdf_buddy,
                        dive.resolvedBuddyNames,
                        signatures
                            ?.where((s) => s.isBuddySignature)
                            .firstOrNull,
                      ),
                      pw.SizedBox(width: 16),
                      _buildSignOffField(
                        l10n,
                        l10n.pdf_verifiedBy,
                        dive.resolvedDiveMasterNames,
                        signatures
                            ?.where((s) => !s.isBuddySignature)
                            .firstOrNull,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPadiField(String label, String value) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: _padiBlue,
            ),
          ),
          pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  pw.Widget _buildSignOffField(
    AppLocalizations l10n,
    String label,
    String? name,
    Signature? signature,
  ) {
    return pw.Expanded(
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            // The joiner ends in a space when the value is empty, which is
            // the gap the signature line needs.
            l10n.pdf_labelValue(label, ''),
            style: const pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey600,
            ),
          ),
          pw.Expanded(
            child: pw.Container(
              height: 20,
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
                ),
              ),
              child: pw.Row(
                children: [
                  if (signature?.hasImage == true)
                    pw.SizedBox(
                      height: 18,
                      width: 40,
                      child: pw.Image(
                        pw.MemoryImage(signature!.imageData!),
                        fit: pw.BoxFit.contain,
                      ),
                    )
                  else if (name != null && name.isNotEmpty)
                    pw.Text(name, style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
