import 'package:flutter/foundation.dart' show visibleForTesting;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:submersion/features/dive_types/presentation/dive_type_display.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/domain/services/equipment_arranger.dart';
import 'package:submersion/features/equipment/domain/services/gear_tree.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_localization.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
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
import 'package:submersion/features/dive_log/presentation/formatters/visibility_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';
import 'package:submersion/features/dive_roles/presentation/dive_role_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/weight_planner/presentation/widgets/weight_enum_display.dart';

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
    String? title,
    Map<String, List<Signature>>? diveSignatures,
    List<Certification>? certifications,
    Diver? diver,
    Map<String, PdfProfileSeries>? profiles,
    Uint8List? diverPhoto,
    bool includeVerificationAreas = false,
    EquipmentArrangement gearArrangement = EquipmentArrangement.defaults,
    Map<String, DiveTypeEntity> diveTypesById = const {},
    Map<String, String> equipmentSetNamesById = const {},
    DateTime? generatedAt,
    PdfLocalization? localization,
  }) async {
    final stamp = generatedAt ?? DateTime.now();
    final loc = localization ?? PdfLocalization.english();
    final l10n = loc.l10n;
    final documentTitle = title ?? l10n.settings_export_pdfDocumentTitle;
    final pdf = pw.Document(theme: await PdfFonts.instance.themeFor(loc));
    final pageFormat = getPageFormat(pageSize);

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        textDirection: loc.textDirection,
        build: (context) => PdfSharedComponents.buildCoverPage(
          title: documentTitle,
          diveCount: dives.length,
          pageFormat: pageFormat,
          dates: dates,
          l10n: l10n,
          generatedAt: stamp,
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
          textDirection: loc.textDirection,
          build: (context) => PdfFrontMatter.buildDiverPageBody(
            diver: diver,
            dates: dates,
            l10n: l10n,
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
          textDirection: loc.textDirection,
          build: (context) => PdfSharedComponents.buildSummaryPage(
            dives: dives,
            dates: dates,
            units: units,
            l10n: l10n,
          ),
        ),
      );
    }

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
          textDirection: loc.textDirection,
          build: (context) => _buildDivePage(
            dive,
            dates: dates,
            l10n: l10n,
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
    required AppLocalizations l10n,
    PdfProfileSeries? profile,
    List<Signature>? signatures,
    required bool includeVerificationAreas,
    required EquipmentArrangement gearArrangement,
    required Map<String, DiveTypeEntity> diveTypesById,
    required Map<String, String> equipmentSetNamesById,
  }) {
    final chart = profile == null
        ? null
        : PdfProfileChart.build(series: profile, units: units, l10n: l10n);

    return [
      _buildHeader(dive, dates: dates, l10n: l10n),
      pw.SizedBox(height: 12),
      pw.Divider(color: PdfColors.grey400),
      pw.SizedBox(height: 12),

      if (chart != null) ...[chart, pw.SizedBox(height: 16)],

      ..._section(
        l10n.pdf_sectionProfile,
        _profileFields(dive, dates: dates, units: units, l10n: l10n),
      ),
      ..._cylinderSection(dive, units: units, l10n: l10n),
      ..._section(
        l10n.pdf_sectionConditions,
        _conditionFields(dive, units: units, l10n: l10n),
      ),
      ..._section(
        l10n.pdf_sectionWeather,
        _weatherFields(dive, units: units, l10n: l10n),
      ),
      ..._section(l10n.pdf_sectionTeam, _teamFields(dive, l10n)),
      ..._section(
        l10n.pdf_sectionEquipment,
        _equipmentFields(
          dive,
          units: units,
          l10n: l10n,
          arrangement: gearArrangement,
          setNamesById: equipmentSetNamesById,
        ),
      ),
      ..._section(
        l10n.pdf_sectionTechnical,
        _technicalFields(dive, diveTypesById: diveTypesById, l10n: l10n),
      ),
      ..._marineLifeSection(dive, l10n),
      ..._notesSection(dive, l10n),
      ..._customFieldsSection(dive, l10n),
      ..._signatureSection(signatures, dates: dates, l10n: l10n),
      if (includeVerificationAreas) ..._verificationSection(l10n),
    ];
  }

  pw.Widget _buildHeader(
    Dive dive, {
    required PdfDateFormatter dates,
    required AppLocalizations l10n,
  }) {
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
                '${dive.site?.name ?? l10n.pdf_unknownSite}',
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
    style: pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.grey700,
      letterSpacing: pdfTracking(title, 1),
    ),
  );

  List<_Field> _profileFields(
    Dive dive, {
    required PdfDateFormatter dates,
    required UnitFormatter units,
    required AppLocalizations l10n,
  }) {
    return [
      if (dive.maxDepth != null)
        _Field(l10n.pdf_maxDepth, units.formatDepth(dive.maxDepth)),
      if (dive.avgDepth != null)
        _Field(l10n.pdf_avgDepth, units.formatDepth(dive.avgDepth)),
      if (dive.effectiveRuntime != null)
        _Field(
          l10n.pdf_runtime,
          l10n.pdf_minutes('${dive.effectiveRuntime!.inMinutes}'),
        ),
      if (dive.bottomTime != null)
        _Field(
          l10n.pdf_bottomTime,
          l10n.pdf_minutes('${dive.bottomTime!.inMinutes}'),
        ),
      if (dive.entryTime != null)
        _Field(l10n.pdf_timeIn, dates.time(dive.entryTime!)),
      if (dive.exitTime != null)
        _Field(l10n.pdf_timeOut, dates.time(dive.exitTime!)),
      if (dive.surfaceInterval != null)
        _Field(
          l10n.pdf_surfaceInterval,
          _duration(dive.surfaceInterval!, l10n),
        ),
      ..._gasConsumptionFields(dive, units, l10n),
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
  List<_Field> _gasConsumptionFields(
    Dive dive,
    UnitFormatter units,
    AppLocalizations l10n,
  ) {
    final display = units.settings.gasConsumptionDisplay;
    final sac = dive.sac;
    final rmv = display.showsRmv ? dive.rmvFor(units.settings.gasModel) : null;
    final sacFallback = display.showsRmv && !display.showsSac && rmv == null;

    return [
      if ((display.showsSac || sacFallback) && sac != null)
        _Field(l10n.pdf_sac, units.formatSac(sac)),
      if (rmv != null) _Field(l10n.pdf_rmv, units.formatRmv(rmv)),
    ];
  }

  /// Every cylinder, not just the first: a technical dive carries stage and
  /// deco bottles whose pressures matter as much as the back gas.
  List<pw.Widget> _cylinderSection(
    Dive dive, {
    required UnitFormatter units,
    required AppLocalizations l10n,
  }) {
    if (dive.tanks.isEmpty) return const [];

    return [
      _sectionTitle(l10n.pdf_sectionCylinders),
      pw.SizedBox(height: 6),
      ...dive.tanks.map(
        (tank) => _buildCylinderRow(tank, units: units, l10n: l10n),
      ),
      pw.SizedBox(height: 14),
    ];
  }

  pw.Widget _buildCylinderRow(
    DiveTank tank, {
    required UnitFormatter units,
    required AppLocalizations l10n,
  }) {
    final descriptors = <String>[
      tank.gasMix.name,
      if (tank.volume != null)
        units.formatTankVolume(tank.volume, tank.workingPressure),
      if (tank.material != null) tank.material!.localizedName(l10n),
      if (tank.role != TankRole.backGas) tank.role.localizedName(l10n),
    ];

    // A half-filled pressure pair is still worth printing: a logbook records
    // what the diver has, so a missing endpoint becomes a placeholder rather
    // than suppressing the whole range.
    final pressures = <String>[
      if (tank.startPressure != null || tank.endPressure != null)
        pdfPressureRange(units, tank.startPressure, tank.endPressure),
      if (tank.pressureUsed != null)
        l10n.pdf_pressureUsed(units.formatPressure(tank.pressureUsed)),
    ];

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(
              tank.name ??
                  tank.presetName ??
                  l10n.pdf_cylinderNumber('${tank.order + 1}'),
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

  List<_Field> _conditionFields(
    Dive dive, {
    required UnitFormatter units,
    required AppLocalizations l10n,
  }) {
    return [
      if (dive.waterTemp != null)
        _Field(l10n.pdf_waterTemp, units.formatTemperature(dive.waterTemp)),
      if (dive.airTemp != null)
        _Field(l10n.pdf_airTemp, units.formatTemperature(dive.airTemp)),
      if (dive.visibilityMeters != null)
        _Field(
          l10n.pdf_visibility,
          units.formatDistance(dive.visibilityMeters!),
        )
      else if (dive.visibility != null)
        _Field(l10n.pdf_visibility, visibilityName(dive.visibility!, l10n)),
      if (dive.currentStrength != null)
        _Field(l10n.pdf_current, dive.currentStrength!.localizedName(l10n)),
      if (dive.currentDirection != null)
        _Field(
          l10n.pdf_currentDirection,
          dive.currentDirection!.localizedName(l10n),
        ),
      if (dive.effectiveWaterType != null)
        _Field(
          l10n.pdf_waterType,
          dive.effectiveWaterType!.localizedName(l10n),
        ),
      if (dive.effectiveEntryMethod != null)
        _Field(l10n.pdf_entry, dive.effectiveEntryMethod!.localizedName(l10n)),
      if (dive.exitMethod != null)
        _Field(l10n.pdf_exit, dive.exitMethod!.localizedName(l10n)),
      if (dive.altitude != null)
        _Field(l10n.pdf_altitude, units.formatAltitude(dive.altitude)),
    ];
  }

  /// Once the `dive_buddies` junction holds anyone it is authoritative, and the
  /// legacy [Dive.buddy] / [Dive.diveMaster] text is stale (#1864). This is the
  /// same rule as the dive list's Buddy and Dive Master columns.
  List<_Field> _teamFields(Dive dive, AppLocalizations l10n) {
    return [
      for (final buddy in dive.buddies)
        _Field(buddy.role.localizedName(l10n), buddy.buddy.name),
      if (dive.buddies.isEmpty && dive.buddy != null)
        _Field(l10n.pdf_buddy, dive.buddy!),
      if (dive.buddies.isEmpty && dive.diveMaster != null)
        _Field(l10n.pdf_diveMaster, dive.diveMaster!),
      if (dive.diveCenter != null)
        _Field(l10n.pdf_diveCenter, dive.diveCenter!.name),
      if (dive.trip != null) _Field(l10n.pdf_trip, dive.trip!.name),
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
    AppLocalizations? l10n,
  }) => _equipmentFields(
    dive,
    units: units,
    l10n: l10n ?? PdfLocalization.english().l10n,
    arrangement: arrangement,
    setNamesById: setNamesById,
  ).map((f) => (label: f.label, value: f.value)).toList();

  List<_Field> _equipmentFields(
    Dive dive, {
    required UnitFormatter units,
    required AppLocalizations l10n,
    required EquipmentArrangement arrangement,
    required Map<String, String> setNamesById,
  }) {
    // The printed logbook is a document a human reads, so it follows the
    // diver's display arrangement (#1486, #1576). The machine-readable
    // exports (UDDF, CSV, Excel) deliberately do not; they take the
    // repository's deterministic baseline instead, so their output does not
    // churn with a display preference.
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
        '${'  ' * depth}${node.link.item.type.localizedName(l10n)}',
        node.link.item.name,
      ),
      for (final child in node.children) ...rows(child, depth + 1),
    ];
    return [
      // The current editor writes Dive.weights; weightAmount is the legacy
      // scalar kept for older dives.
      if (dive.weights.isNotEmpty)
        _Field(l10n.pdf_weight, units.formatWeight(dive.totalWeight))
      else if (dive.weightAmount != null)
        _Field(l10n.pdf_weight, units.formatWeight(dive.weightAmount)),
      if (dive.weightType != null)
        _Field(l10n.pdf_weightType, dive.weightType!.localizedName(l10n)),
      if (setNames.isNotEmpty)
        _Field(l10n.pdf_equipmentSets(setNames.length), setNames.join(', ')),
      for (final group in arrangeEquipment(
        [for (final n in roots) n.link.item],
        arrangement,
        typeLabel: (type) => type.localizedName(l10n),
      ))
        for (final item in group.items) ...rows(rootsById[item.id]!, 0),
    ];
  }

  List<_Field> _technicalFields(
    Dive dive, {
    required Map<String, DiveTypeEntity> diveTypesById,
    required AppLocalizations l10n,
  }) {
    // Built-in types print under their localized name, the way the app shows
    // them; a custom type keeps the name the diver gave it (#1834, #2252).
    final storedNames = dive.diveTypeNamesFrom(diveTypesById);
    final diveTypeNames = [
      for (var i = 0; i < storedNames.length; i++)
        _diveTypeName(dive.diveTypeIds[i], storedNames[i], diveTypesById, l10n),
    ];
    return [
      if (dive.diveComputerModel != null)
        _Field(l10n.pdf_computer, dive.diveComputerModel!),
      if (dive.diveMode != DiveMode.oc)
        _Field(l10n.pdf_diveMode, dive.diveMode.localizedName(l10n)),
      if (dive.decoAlgorithm != null)
        _Field(l10n.pdf_algorithm, dive.decoAlgorithm!),
      if (dive.gradientFactorLow != null && dive.gradientFactorHigh != null)
        _Field(
          l10n.pdf_gradientFactors,
          '${dive.gradientFactorLow}/${dive.gradientFactorHigh}',
        ),
      if (dive.setpointHigh != null)
        // Deliberately not unit-converted: a CCR setpoint is a partial
        // pressure of oxygen, quoted in bar (or ata) whatever the diver's
        // cylinder-pressure preference. The CCR settings panel does the same.
        _Field(l10n.pdf_setpoint, '${dive.setpointHigh} bar'),
      if (diveTypeNames.isNotEmpty)
        _Field(l10n.pdf_diveType, diveTypeNames.join(', ')),
    ];
  }

  /// [stored] is the name [Dive.diveTypeNamesFrom] settled on for [id].
  String _diveTypeName(
    String id,
    String stored,
    Map<String, DiveTypeEntity> typesById,
    AppLocalizations l10n,
  ) {
    final type = typesById[id];
    if (type != null) return type.isBuiltIn ? type.localizedName(l10n) : stored;
    return builtInDiveTypeName(l10n, id) ?? stored;
  }

  /// Recorded weather, which #1017 asks for beyond the free-text summary.
  List<_Field> _weatherFields(
    Dive dive, {
    required UnitFormatter units,
    required AppLocalizations l10n,
  }) {
    return [
      if (dive.weatherDescription != null)
        _Field(l10n.pdf_weatherConditions, dive.weatherDescription!),
      if (dive.windSpeed != null)
        _Field(l10n.pdf_wind, units.formatWindSpeed(dive.windSpeed)),
      if (dive.windDirection != null)
        _Field(l10n.pdf_windDirection, dive.windDirection!.localizedName(l10n)),
      if (dive.cloudCover != null)
        _Field(l10n.pdf_cloud, dive.cloudCover!.localizedName(l10n)),
      if (dive.precipitation != null)
        _Field(l10n.pdf_precipitation, dive.precipitation!.localizedName(l10n)),
      if (dive.humidity != null)
        _Field(l10n.pdf_humidity, '${dive.humidity!.toStringAsFixed(0)}%'),
      // Swell is a height in meters, so it follows the depth unit the way the
      // dive editor renders it.
      if (dive.swellHeight != null)
        _Field(l10n.pdf_swell, units.formatDepth(dive.swellHeight)),
    ];
  }

  /// User-defined key/value entries. The legacy builder rendered these, so
  /// dropping them would lose data that has no other section to hold it.
  List<pw.Widget> _customFieldsSection(Dive dive, AppLocalizations l10n) {
    if (dive.customFields.isEmpty) return const [];

    const keyStyle = pw.TextStyle(fontSize: 10, color: PdfColors.grey600);
    const valueStyle = pw.TextStyle(fontSize: 10);

    return [
      _sectionTitle(l10n.pdf_sectionAdditionalFields),
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
  List<pw.Widget> _marineLifeSection(Dive dive, AppLocalizations l10n) {
    if (dive.sightings.isEmpty) return const [];

    return [
      _sectionTitle(l10n.pdf_sectionMarineLife),
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

  List<pw.Widget> _notesSection(Dive dive, AppLocalizations l10n) {
    if (dive.notes.isEmpty) return const [];

    return [
      _sectionTitle(l10n.pdf_sectionNotes),
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
    required AppLocalizations l10n,
  }) {
    if (signatures == null || signatures.isEmpty) return const [];

    return [
      _sectionTitle(l10n.pdf_sectionVerifiedBy),
      pw.SizedBox(height: 6),
      pw.Wrap(
        spacing: 8,
        runSpacing: 8,
        children: signatures
            .map(
              (sig) => PdfSharedComponents.buildSignatureBlock(
                sig,
                dates: dates,
                l10n: l10n,
              ),
            )
            .toList(),
      ),
      pw.SizedBox(height: 14),
    ];
  }

  List<pw.Widget> _verificationSection(AppLocalizations l10n) {
    return [
      _sectionTitle(l10n.pdf_sectionVerification),
      pw.SizedBox(height: 6),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          PdfSharedComponents.buildLargeSignatureBlock(
            label: l10n.pdf_instructorSignature,
          ),
          pw.SizedBox(width: 24),
          PdfSharedComponents.buildLargeSignatureBlock(
            label: l10n.pdf_buddySignature,
          ),
          pw.SizedBox(width: 24),
          PdfSharedComponents.buildStampArea(label: l10n.pdf_officialStamp),
        ],
      ),
    ];
  }

  String _duration(Duration d, AppLocalizations l10n) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    return hours > 0
        ? l10n.pdf_hoursMinutes('$hours', '$minutes')
        : l10n.pdf_minutesShort('$minutes');
  }
}

/// One label/value pair inside a section.
class _Field {
  final String label;
  final String value;

  const _Field(this.label, this.value);
}
