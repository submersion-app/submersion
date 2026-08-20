import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_fonts.dart';
import 'package:submersion/core/services/pdf_templates/pdf_front_matter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_profile_chart.dart';
import 'package:submersion/core/services/pdf_templates/pdf_profile_series.dart';
import 'package:submersion/core/services/pdf_templates/pdf_shared_components.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_builder.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';

/// Detailed PDF template: one dive per page with the full field set.
///
/// Carries the depth profile chart plus every group #1017 asks for. Each
/// group omits itself when the dive records nothing for it, so a manually
/// logged dive prints a short page rather than a wall of empty labels.
class PdfTemplateDetailed extends PdfTemplateBuilder {
  @override
  PdfTemplate get templateType => PdfTemplate.detailed;

  @override
  Future<List<int>> buildPdf({
    required List<Dive> dives,
    required PdfPageSize pageSize,
    required PdfDateFormatter dates,
    required UnitFormatter units,
    String title = 'Dive Logbook',
    Map<String, List<Signature>>? diveSignatures,
    List<Certification>? certifications,
    Diver? diver,
    Map<String, PdfProfileSeries>? profiles,
    Uint8List? diverPhoto,
    bool includeVerificationAreas = false,
  }) async {
    final pdf = pw.Document(theme: PdfFonts.instance.theme);
    final pageFormat = getPageFormat(pageSize);

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (context) => PdfSharedComponents.buildCoverPage(
          title: title,
          diveCount: dives.length,
          pageFormat: pageFormat,
          dates: dates,
          firstDiveDate: dives.isNotEmpty ? dives.last.dateTime : null,
          lastDiveDate: dives.isNotEmpty ? dives.first.dateTime : null,
          diver: diver,
        ),
      ),
    );

    if (diver != null) {
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => PdfFrontMatter.buildDiverPage(
            diver: diver,
            dates: dates,
            diveCount: dives.length,
            certifications: certifications ?? const [],
            photoBytes: diverPhoto,
          ),
        ),
      );
    }

    if (dives.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (context) => PdfSharedComponents.buildSummaryPage(
            dives: dives,
            dates: dates,
            units: units,
          ),
        ),
      );
    }

    if (certifications != null && certifications.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => PdfSharedComponents.buildCertificationCardsBody(
            certifications: certifications,
            dates: dates,
            diver: diver,
          ),
        ),
      );
    }

    // One dive per page. A MultiPage rather than a Page so an unusually long
    // note or a long cylinder list spills onto a continuation sheet instead of
    // being clipped, which is the failure this template is fixing.
    for (final dive in dives) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => _buildDivePage(
            dive,
            dates: dates,
            units: units,
            profile: profiles?[dive.id],
            signatures: diveSignatures?[dive.id],
            includeVerificationAreas: includeVerificationAreas,
          ),
        ),
      );
    }

    return await pdf.save();
  }

  List<pw.Widget> _buildDivePage(
    Dive dive, {
    required PdfDateFormatter dates,
    required UnitFormatter units,
    PdfProfileSeries? profile,
    List<Signature>? signatures,
    required bool includeVerificationAreas,
  }) {
    final chart = profile == null
        ? null
        : PdfProfileChart.build(series: profile, units: units);

    return [
      _buildHeader(dive, dates: dates),
      pw.SizedBox(height: 12),
      pw.Divider(color: PdfColors.grey400),
      pw.SizedBox(height: 12),

      if (chart != null) ...[chart, pw.SizedBox(height: 16)],

      ..._section('Profile', _profileFields(dive, dates: dates, units: units)),
      ..._cylinderSection(dive, units: units),
      ..._section('Conditions', _conditionFields(dive, units: units)),
      ..._section('Team', _teamFields(dive)),
      ..._section('Equipment', _equipmentFields(dive, units: units)),
      ..._section('Technical', _technicalFields(dive)),
      ..._marineLifeSection(dive),
      ..._notesSection(dive),
      ..._signatureSection(signatures, dates: dates),
      if (includeVerificationAreas) ..._verificationSection(),
    ];
  }

  pw.Widget _buildHeader(Dive dive, {required PdfDateFormatter dates}) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '#${dive.diveNumber ?? '-'} - '
                '${dive.site?.name ?? 'Unknown Site'}',
                style: const pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              if (dive.site?.region != null || dive.site?.country != null)
                pw.Text(
                  [
                    dive.site?.region,
                    dive.site?.country,
                  ].whereType<String>().join(', '),
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              dates.dateTime(dive.dateTime),
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
            ),
            if (dive.rating != null && dive.rating! > 0) ...[
              pw.SizedBox(height: 4),
              PdfSharedComponents.buildRating(dive.rating),
            ],
          ],
        ),
      ],
    );
  }

  /// A titled group of label/value pairs, or nothing when [fields] is empty.
  List<pw.Widget> _section(String title, List<_Field> fields) {
    if (fields.isEmpty) return const [];

    return [
      _sectionTitle(title),
      pw.SizedBox(height: 6),
      pw.Wrap(
        spacing: 24,
        runSpacing: 8,
        children: fields
            .map(
              (f) => pw.SizedBox(
                width: 110,
                child: PdfSharedComponents.buildInfoChip(f.label, f.value),
              ),
            )
            .toList(),
      ),
      pw.SizedBox(height: 14),
    ];
  }

  pw.Widget _sectionTitle(String title) => pw.Text(
    title.toUpperCase(),
    style: const pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.grey700,
      letterSpacing: 1,
    ),
  );

  List<_Field> _profileFields(
    Dive dive, {
    required PdfDateFormatter dates,
    required UnitFormatter units,
  }) {
    return [
      if (dive.maxDepth != null)
        _Field('Max Depth', units.formatDepth(dive.maxDepth)),
      if (dive.avgDepth != null)
        _Field('Avg Depth', units.formatDepth(dive.avgDepth)),
      if (dive.effectiveRuntime != null)
        _Field('Runtime', '${dive.effectiveRuntime!.inMinutes} min'),
      if (dive.bottomTime != null)
        _Field('Bottom Time', '${dive.bottomTime!.inMinutes} min'),
      if (dive.entryTime != null) _Field('In', dates.time(dive.entryTime!)),
      if (dive.exitTime != null) _Field('Out', dates.time(dive.exitTime!)),
      if (dive.surfaceInterval != null)
        _Field('Surface Interval', _duration(dive.surfaceInterval!)),
    ];
  }

  /// Every cylinder, not just the first: a technical dive carries stage and
  /// deco bottles whose pressures matter as much as the back gas.
  List<pw.Widget> _cylinderSection(Dive dive, {required UnitFormatter units}) {
    if (dive.tanks.isEmpty) return const [];

    return [
      _sectionTitle('Cylinders'),
      pw.SizedBox(height: 6),
      ...dive.tanks.map((tank) => _buildCylinderRow(tank, units: units)),
      pw.SizedBox(height: 14),
    ];
  }

  pw.Widget _buildCylinderRow(DiveTank tank, {required UnitFormatter units}) {
    final descriptors = <String>[
      tank.gasMix.name,
      if (tank.volume != null)
        units.formatTankVolume(tank.volume, tank.workingPressure),
      if (tank.material != null) tank.material!.displayName,
      if (tank.role != TankRole.backGas) tank.role.displayName,
    ];

    final pressures = <String>[
      if (tank.startPressure != null && tank.endPressure != null)
        '${units.formatPressureValue(tank.startPressure)} - '
            '${units.formatPressure(tank.endPressure)}',
      if (tank.pressureUsed != null)
        '${units.formatPressure(tank.pressureUsed)} used',
    ];

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(
              tank.name ?? tank.presetName ?? 'Cylinder ${tank.order + 1}',
              style: const pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              descriptors.join('  '),
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
          pw.Text(
            pressures.join('  '),
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  List<_Field> _conditionFields(Dive dive, {required UnitFormatter units}) {
    return [
      if (dive.waterTemp != null)
        _Field('Water Temp', units.formatTemperature(dive.waterTemp)),
      if (dive.airTemp != null)
        _Field('Air Temp', units.formatTemperature(dive.airTemp)),
      if (dive.visibilityMeters != null)
        _Field('Visibility', units.formatDistance(dive.visibilityMeters!))
      else if (dive.visibility != null)
        _Field('Visibility', dive.visibility!.displayName),
      if (dive.currentStrength != null)
        _Field('Current', dive.currentStrength!.displayName),
      if (dive.currentDirection != null)
        _Field('Current Dir', dive.currentDirection!.displayName),
      if (dive.waterType != null)
        _Field('Water Type', dive.waterType!.displayName),
      if (dive.entryMethod != null)
        _Field('Entry', dive.entryMethod!.displayName),
      if (dive.exitMethod != null) _Field('Exit', dive.exitMethod!.displayName),
      if (dive.weatherDescription != null)
        _Field('Weather', dive.weatherDescription!),
      if (dive.altitude != null)
        _Field('Altitude', units.formatAltitude(dive.altitude)),
    ];
  }

  List<_Field> _teamFields(Dive dive) {
    return [
      for (final buddy in dive.buddies)
        _Field(buddy.role.name, buddy.buddy.name),
      if (dive.buddies.isEmpty && dive.buddy != null)
        _Field('Buddy', dive.buddy!),
      if (dive.diveMaster != null) _Field('Dive Master', dive.diveMaster!),
      if (dive.diveCenter != null) _Field('Dive Center', dive.diveCenter!.name),
      if (dive.trip != null) _Field('Trip', dive.trip!.name),
    ];
  }

  List<_Field> _equipmentFields(Dive dive, {required UnitFormatter units}) {
    return [
      if (dive.weightAmount != null)
        _Field('Weight', units.formatWeight(dive.weightAmount)),
      if (dive.weightType != null)
        _Field('Weight Type', dive.weightType!.displayName),
      for (final item in dive.equipment)
        _Field(item.type.displayName, item.name),
    ];
  }

  List<_Field> _technicalFields(Dive dive) {
    return [
      if (dive.diveComputerModel != null)
        _Field('Computer', dive.diveComputerModel!),
      if (dive.diveMode != DiveMode.oc)
        _Field('Dive Mode', dive.diveMode.displayName),
      if (dive.decoAlgorithm != null) _Field('Algorithm', dive.decoAlgorithm!),
      if (dive.gradientFactorLow != null && dive.gradientFactorHigh != null)
        _Field(
          'Gradient Factors',
          '${dive.gradientFactorLow}/${dive.gradientFactorHigh}',
        ),
      if (dive.setpointHigh != null)
        // Deliberately not unit-converted: a CCR setpoint is a partial
        // pressure of oxygen, quoted in bar (or ata) whatever the diver's
        // cylinder-pressure preference. The CCR settings panel does the same.
        _Field('Setpoint', '${dive.setpointHigh} bar'),
      if (dive.diveTypeNames.isNotEmpty)
        _Field('Dive Type', dive.diveTypeNames.join(', ')),
    ];
  }

  List<pw.Widget> _marineLifeSection(Dive dive) {
    if (dive.sightings.isEmpty) return const [];

    return [
      _sectionTitle('Marine Life'),
      pw.SizedBox(height: 6),
      pw.Text(
        dive.sightings.map((s) => s.speciesName).join(', '),
        style: const pw.TextStyle(fontSize: 10),
      ),
      pw.SizedBox(height: 14),
    ];
  }

  /// Full text. The truncation here is the reported bug.
  List<pw.Widget> _notesSection(Dive dive) {
    if (dive.notes.isEmpty) return const [];

    return [
      _sectionTitle('Notes'),
      pw.SizedBox(height: 6),
      pw.Text(
        dive.notes,
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
      ),
      pw.SizedBox(height: 14),
    ];
  }

  List<pw.Widget> _signatureSection(
    List<Signature>? signatures, {
    required PdfDateFormatter dates,
  }) {
    if (signatures == null || signatures.isEmpty) return const [];

    return [
      _sectionTitle('Verified By'),
      pw.SizedBox(height: 6),
      pw.Wrap(
        spacing: 8,
        runSpacing: 8,
        children: signatures
            .map(
              (sig) =>
                  PdfSharedComponents.buildSignatureBlock(sig, dates: dates),
            )
            .toList(),
      ),
      pw.SizedBox(height: 14),
    ];
  }

  List<pw.Widget> _verificationSection() {
    return [
      _sectionTitle('Verification'),
      pw.SizedBox(height: 6),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          PdfSharedComponents.buildLargeSignatureBlock(
            label: 'Instructor Signature',
          ),
          pw.SizedBox(width: 24),
          PdfSharedComponents.buildLargeSignatureBlock(
            label: 'Buddy Signature',
          ),
          pw.SizedBox(width: 24),
          PdfSharedComponents.buildStampArea(),
        ],
      ),
    ];
  }

  String _duration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
  }
}

/// One label/value pair inside a section.
class _Field {
  final String label;
  final String value;

  const _Field(this.label, this.value);
}
