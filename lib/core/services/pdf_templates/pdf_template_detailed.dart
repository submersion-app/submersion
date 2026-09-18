import 'package:flutter/foundation.dart' show visibleForTesting;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/domain/services/equipment_arranger.dart';
import 'package:submersion/features/equipment/domain/services/gear_tree.dart';
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
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
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
    EquipmentArrangement gearArrangement = EquipmentArrangement.defaults,
    Map<String, DiveTypeEntity> diveTypesById = const {},
    Map<String, String> equipmentSetNamesById = const {},
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
        pw.MultiPage(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => PdfFrontMatter.buildDiverPageBody(
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
            profile: _seriesFor(dive, profiles),
            signatures: diveSignatures?[dive.id],
            includeVerificationAreas: includeVerificationAreas,
            gearArrangement: gearArrangement,
            diveTypesById: diveTypesById,
            equipmentSetNamesById: equipmentSetNamesById,
          ),
        ),
      );
    }

    return await pdf.save();
  }

  /// The chart series for [dive], falling back to samples already on the
  /// entity.
  ///
  /// The logbook path loads profiles in batch because `getAllDives` skips
  /// them, but `getDivesByIds` and `getDiveById` hydrate `Dive.profile`
  /// already. Without this fallback every bulk or single-dive Detailed export
  /// would silently omit the chart.
  PdfProfileSeries? _seriesFor(
    Dive dive,
    Map<String, PdfProfileSeries>? profiles,
  ) {
    final supplied = profiles?[dive.id];
    if (supplied != null && supplied.isNotEmpty) return supplied;
    if (dive.profile.isEmpty) return null;
    return PdfProfileSeries.downsampled(dive.profile);
  }

  List<pw.Widget> _buildDivePage(
    Dive dive, {
    required PdfDateFormatter dates,
    required UnitFormatter units,
    PdfProfileSeries? profile,
    List<Signature>? signatures,
    required bool includeVerificationAreas,
    required EquipmentArrangement gearArrangement,
    required Map<String, DiveTypeEntity> diveTypesById,
    required Map<String, String> equipmentSetNamesById,
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
      ..._section('Weather', _weatherFields(dive, units: units)),
      ..._section('Team', _teamFields(dive)),
      ..._section(
        'Equipment',
        _equipmentFields(
          dive,
          units: units,
          arrangement: gearArrangement,
          setNamesById: equipmentSetNamesById,
        ),
      ),
      ..._section(
        'Technical',
        _technicalFields(dive, diveTypesById: diveTypesById),
      ),
      ..._marineLifeSection(dive),
      ..._notesSection(dive),
      ..._customFieldsSection(dive),
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
      ..._gasConsumptionFields(dive, units),
    ];
  }

  /// The diver's gas-consumption lanes, following
  /// `AppSettings.gasConsumptionDisplay` as the dive detail page does.
  ///
  /// SAC and RMV are two quantities rather than one value in two units
  /// (discussions #354, #803): [Dive.sac] is a bar/min pressure drop on the
  /// reference cylinder, [Dive.rmvFor] is L/min summed over every cylinder
  /// that carries pressures and a volume. So RMV is read from the entity, not
  /// scaled from SAC by a cylinder volume -- bar/min from a 12 L back gas and
  /// a 7 L stage cannot be averaged.
  ///
  /// A lane the dive cannot supply is omitted. The one exception mirrors the
  /// detail page: an RMV-only diver whose cylinders have no volumes still
  /// gets the SAC row, because a page that silently drops gas consumption is
  /// worse than one showing the other lane (issue #386). The page has no
  /// place for the tappable volume hint the app shows there.
  List<_Field> _gasConsumptionFields(Dive dive, UnitFormatter units) {
    final display = units.settings.gasConsumptionDisplay;
    final sac = dive.sac;
    final rmv = display.showsRmv ? dive.rmvFor(units.settings.gasModel) : null;
    final sacFallback = display.showsRmv && !display.showsSac && rmv == null;

    return [
      if ((display.showsSac || sacFallback) && sac != null)
        _Field('SAC', units.formatSac(sac)),
      if (rmv != null) _Field('RMV', units.formatRmv(rmv)),
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

    // A half-filled pressure pair is still worth printing: a logbook records
    // what the diver has, so a missing endpoint becomes a placeholder rather
    // than suppressing the whole range.
    final pressures = <String>[
      if (tank.startPressure != null || tank.endPressure != null)
        pdfPressureRange(units, tank.startPressure, tank.endPressure),
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
      if (dive.effectiveWaterType != null)
        _Field('Water Type', dive.effectiveWaterType!.displayName),
      if (dive.effectiveEntryMethod != null)
        _Field('Entry', dive.effectiveEntryMethod!.displayName),
      if (dive.exitMethod != null) _Field('Exit', dive.exitMethod!.displayName),
      if (dive.altitude != null)
        _Field('Altitude', units.formatAltitude(dive.altitude)),
    ];
  }

  /// Once the `dive_buddies` junction holds anyone it is authoritative, and the
  /// legacy [Dive.buddy] / [Dive.diveMaster] text is stale (#1864). This is the
  /// same rule as the dive list's Buddy and Dive Master columns.
  List<_Field> _teamFields(Dive dive) {
    return [
      for (final buddy in dive.buddies)
        _Field(buddy.role.name, buddy.buddy.name),
      if (dive.buddies.isEmpty && dive.buddy != null)
        _Field('Buddy', dive.buddy!),
      if (dive.buddies.isEmpty && dive.diveMaster != null)
        _Field('Dive Master', dive.diveMaster!),
      if (dive.diveCenter != null) _Field('Dive Center', dive.diveCenter!.name),
      if (dive.trip != null) _Field('Trip', dive.trip!.name),
    ];
  }

  /// The Equipment section's rows as (label, value) pairs.
  ///
  /// Records rather than the private `_Field`, so exposing this for tests does
  /// not leak a private type through a public API.
  @visibleForTesting
  List<({String label, String value})> equipmentFieldsForTest(
    Dive dive, {
    required UnitFormatter units,
    required EquipmentArrangement arrangement,
    Map<String, String> setNamesById = const {},
  }) => _equipmentFields(
    dive,
    units: units,
    arrangement: arrangement,
    setNamesById: setNamesById,
  ).map((f) => (label: f.label, value: f.value)).toList();

  List<_Field> _equipmentFields(
    Dive dive, {
    required UnitFormatter units,
    required EquipmentArrangement arrangement,
    required Map<String, String> setNamesById,
  }) {
    // The printed logbook is a document a human reads, so it follows the
    // diver's display arrangement (#1486, #1576). The machine-readable
    // exports (UDDF, CSV, Excel) deliberately do not; they take the
    // repository's deterministic baseline instead, so their output does not
    // churn with a display preference.
    //
    // displayName rather than a localized label: this template has no
    // AppLocalizations in scope, which is exactly why arrangeEquipment takes
    // the label resolver as a parameter.
    //
    // An assembly keeps its parts under it, indented, in template order
    // (#1487). Set gear and hand-added gear print as one arranged list, so a
    // tank swapped in by hand does not trail the set's gear (#2031); the
    // sets are named on their own row instead. A set with no name on file
    // (deleted since, the lookup failed, or a name the editor trimmed to
    // empty) is left out of that row rather than printed as an id or a
    // blank the reader cannot use.
    final roots = GearTree.build(dive.gear);
    final rootsById = {for (final n in roots) n.link.item.id: n};
    final setNames = [
      for (final id in GearTree.setIds(dive.gear))
        if (setNamesById[id]?.trim() case final name? when name.isNotEmpty)
          name,
    ];
    List<_Field> rows(GearNode node, int depth) => [
      _Field(
        '${'  ' * depth}${node.link.item.type.displayName}',
        node.link.item.name,
      ),
      for (final child in node.children) ...rows(child, depth + 1),
    ];
    return [
      // The current editor writes Dive.weights; weightAmount is the legacy
      // scalar kept for older dives.
      if (dive.weights.isNotEmpty)
        _Field('Weight', units.formatWeight(dive.totalWeight))
      else if (dive.weightAmount != null)
        _Field('Weight', units.formatWeight(dive.weightAmount)),
      if (dive.weightType != null)
        _Field('Weight Type', dive.weightType!.displayName),
      if (setNames.isNotEmpty)
        _Field(setNames.length == 1 ? 'Set' : 'Sets', setNames.join(', ')),
      for (final group in arrangeEquipment(
        [for (final n in roots) n.link.item],
        arrangement,
        typeLabel: (type) => type.displayName,
      ))
        for (final item in group.items) ...rows(rootsById[item.id]!, 0),
    ];
  }

  List<_Field> _technicalFields(
    Dive dive, {
    required Map<String, DiveTypeEntity> diveTypesById,
  }) {
    final diveTypeNames = dive.diveTypeNamesFrom(diveTypesById);
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
      if (diveTypeNames.isNotEmpty)
        _Field('Dive Type', diveTypeNames.join(', ')),
    ];
  }

  /// Recorded weather, which #1017 asks for beyond the free-text summary.
  List<_Field> _weatherFields(Dive dive, {required UnitFormatter units}) {
    return [
      if (dive.weatherDescription != null)
        _Field('Conditions', dive.weatherDescription!),
      if (dive.windSpeed != null)
        _Field('Wind', units.formatWindSpeed(dive.windSpeed)),
      if (dive.windDirection != null)
        _Field('Wind Dir', dive.windDirection!.displayName),
      if (dive.cloudCover != null)
        _Field('Cloud', dive.cloudCover!.displayName),
      if (dive.precipitation != null)
        _Field('Precipitation', dive.precipitation!.displayName),
      if (dive.humidity != null)
        _Field('Humidity', '${dive.humidity!.toStringAsFixed(0)}%'),
      // Swell is a height in meters, so it follows the depth unit the way the
      // dive editor renders it.
      if (dive.swellHeight != null)
        _Field('Swell', units.formatDepth(dive.swellHeight)),
    ];
  }

  /// User-defined key/value entries. The legacy builder rendered these, so
  /// dropping them would lose data that has no other section to hold it.
  List<pw.Widget> _customFieldsSection(Dive dive) {
    if (dive.customFields.isEmpty) return const [];

    const keyStyle = pw.TextStyle(fontSize: 10, color: PdfColors.grey600);
    const valueStyle = pw.TextStyle(fontSize: 10);

    return [
      _sectionTitle('Additional Fields'),
      pw.SizedBox(height: 6),
      for (final field in dive.customFields)
        if (_fitsInRow([field.key, field.value]))
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 120,
                  child: pw.Text(field.key, style: keyStyle),
                ),
                pw.Expanded(child: pw.Text(field.value, style: valueStyle)),
              ],
            ),
          )
        else
          ..._stackedEntry(
            label: field.key,
            labelStyle: keyStyle,
            value: field.value,
            valueStyle: valueStyle,
            bottom: 2,
          ),
      pw.SizedBox(height: 14),
    ];
  }

  /// Upper bounds for free text laid out in a two-column pw.Row.
  ///
  /// A Row can never span pages, so a value taller than a page body throws
  /// "Widget won't fit into the page" and fails the whole export. These sit
  /// far below one page on every supported size, even in the narrowest
  /// column, so a wrong "too long" verdict only costs the stacked layout.
  static const _rowMaxChars = 400;
  static const _rowMaxLines = 12;

  static bool _fitsInRow(List<String> texts) {
    var chars = 0;
    var lines = 0;
    for (final text in texts) {
      chars += text.length;
      lines += '\n'.allMatches(text).length + 1;
    }
    return chars <= _rowMaxChars && lines <= _rowMaxLines;
  }

  /// The fallback for text too long for a Row: the label on its own line, the
  /// value indented beneath it. Both are spanning pw.Text widgets, so
  /// MultiPage can carry either onto the next sheet.
  List<pw.Widget> _stackedEntry({
    required String label,
    required pw.TextStyle labelStyle,
    required String value,
    required pw.TextStyle valueStyle,
    required double bottom,
  }) {
    return [
      // With no value beneath it, the label carries the entry's bottom
      // spacing itself, or it would run into the next entry.
      pw.Padding(
        padding: pw.EdgeInsets.only(bottom: value.isEmpty ? bottom : 0),
        child: pw.Text(
          label,
          style: labelStyle,
          overflow: pw.TextOverflow.span,
        ),
      ),
      if (value.isNotEmpty)
        pw.Padding(
          padding: pw.EdgeInsets.only(left: 12, top: 1, bottom: bottom),
          child: pw.Text(
            value,
            style: valueStyle,
            overflow: pw.TextOverflow.span,
          ),
        ),
    ];
  }

  /// Full text. The truncation here is the reported bug.
  /// Recorded marine life, which #1017 lists among the detailed groups.
  ///
  /// A list rather than the `_section` chips: a sighting carries free-text
  /// notes that would not survive a fixed-width chip.
  List<pw.Widget> _marineLifeSection(Dive dive) {
    if (dive.sightings.isEmpty) return const [];

    return [
      _sectionTitle('Marine Life'),
      pw.SizedBox(height: 6),
      ...dive.sightings.expand(_sightingLines),
      pw.SizedBox(height: 14),
    ];
  }

  List<pw.Widget> _sightingLines(MarineSighting sighting) {
    // A count on a lone animal reads as noise, so only a real tally is shown.
    final species = sighting.count > 1
        ? '${sighting.speciesName} x${sighting.count}'
        : sighting.speciesName;
    const speciesStyle = pw.TextStyle(fontSize: 10, color: PdfColors.grey800);
    const notesStyle = pw.TextStyle(fontSize: 9, color: PdfColors.grey600);

    if (!_fitsInRow([species, sighting.notes])) {
      return _stackedEntry(
        label: species,
        labelStyle: speciesStyle,
        value: sighting.notes,
        valueStyle: notesStyle,
        bottom: 3,
      );
    }

    return [
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(flex: 2, child: pw.Text(species, style: speciesStyle)),
            pw.Expanded(
              flex: 3,
              child: pw.Text(sighting.notes, style: notesStyle),
            ),
          ],
        ),
      ),
    ];
  }

  List<pw.Widget> _notesSection(Dive dive) {
    if (dive.notes.isEmpty) return const [];

    return [
      _sectionTitle('Notes'),
      pw.SizedBox(height: 6),
      // TextOverflow.span is what lets MultiPage break the notes across
      // sheets. Without it a pw.Text cannot span, so a note taller than one
      // page body throws "Widget won't fit into the page" and fails the
      // whole export (#2056).
      pw.Text(
        dive.notes,
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
        overflow: pw.TextOverflow.span,
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
