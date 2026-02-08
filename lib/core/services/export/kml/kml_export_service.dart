import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:xml/xml.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/core/services/export/shared/unit_converters.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Handles KML export for Google Earth visualization.
class KmlExportService {
  final _dateFormat = DateFormat('yyyy-MM-dd');

  /// Export dive sites to KML format and share via system sheet.
  ///
  /// Returns a tuple of (file path, skipped count) where skipped count
  /// is the number of sites without coordinates.
  Future<(String, int)> exportToKml({
    required List<DiveSite> sites,
    required List<Dive> dives,
    required DepthUnit depthUnit,
    required DateFormatPreference dateFormat,
  }) async {
    final (kmlContent, skippedCount) = _buildKmlDocument(
      sites: sites,
      dives: dives,
      depthUnit: depthUnit,
      dateFormat: dateFormat,
    );

    final dateStr = _dateFormat.format(DateTime.now());
    final fileName = 'submersion_sites_$dateStr.kml';

    final filePath = await saveAndShareFile(
      kmlContent,
      fileName,
      'application/vnd.google-earth.kml+xml',
    );

    return (filePath, skippedCount);
  }

  /// Generate KML content without sharing.
  Future<(String, int)> generateKmlContent({
    required List<DiveSite> sites,
    required List<Dive> dives,
    required DepthUnit depthUnit,
    required DateFormatPreference dateFormat,
  }) async {
    return _buildKmlDocument(
      sites: sites,
      dives: dives,
      depthUnit: depthUnit,
      dateFormat: dateFormat,
    );
  }

  /// Save KML file to a user-selected location.
  ///
  /// Returns a tuple of (saved file path or null, skipped count).
  Future<(String?, int)> saveKmlToFile({
    required List<DiveSite> sites,
    required List<Dive> dives,
    required DepthUnit depthUnit,
    required DateFormatPreference dateFormat,
  }) async {
    final (kmlContent, skippedCount) = _buildKmlDocument(
      sites: sites,
      dives: dives,
      depthUnit: depthUnit,
      dateFormat: dateFormat,
    );

    final dateStr = _dateFormat.format(DateTime.now());
    final fileName = 'submersion_sites_$dateStr.kml';

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save KML File',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['kml'],
      bytes: Uint8List.fromList(utf8.encode(kmlContent)),
    );

    if (result == null) return (null, skippedCount);

    if (!Platform.isAndroid) {
      final file = File(result);
      await file.writeAsString(kmlContent);
    }

    return (result, skippedCount);
  }

  // ==================== Internal Helpers ====================

  (String, int) _buildKmlDocument({
    required List<DiveSite> sites,
    required List<Dive> dives,
    required DepthUnit depthUnit,
    required DateFormatPreference dateFormat,
  }) {
    final sitesWithCoords = sites.where((s) => s.location != null).toList();
    final skippedCount = sites.length - sitesWithCoords.length;

    if (sitesWithCoords.isEmpty) {
      throw Exception(
        'No dive sites with GPS coordinates to export. '
        'Add coordinates to your dive sites first.',
      );
    }

    // Build dive lookup by site ID
    final divesBySite = <String, List<Dive>>{};
    for (final dive in dives) {
      if (dive.site != null) {
        divesBySite.putIfAbsent(dive.site!.id, () => []).add(dive);
      }
    }

    // Build KML document
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');

    builder.element(
      'kml',
      attributes: {'xmlns': 'http://www.opengis.net/kml/2.2'},
      nest: () {
        builder.element(
          'Document',
          nest: () {
            builder.element('name', nest: 'Submersion Dive Sites');
            builder.element(
              'description',
              nest:
                  'Exported from Submersion on ${_dateFormat.format(DateTime.now())}',
            );

            for (final site in sitesWithCoords) {
              final siteDives = divesBySite[site.id] ?? [];
              siteDives.sort((a, b) => b.dateTime.compareTo(a.dateTime));

              builder.element(
                'Placemark',
                nest: () {
                  builder.element('name', nest: site.name);
                  builder.element(
                    'description',
                    nest: () {
                      builder.cdata(
                        _buildKmlDescription(
                          site,
                          siteDives,
                          depthUnit,
                          dateFormat,
                        ),
                      );
                    },
                  );
                  builder.element(
                    'Point',
                    nest: () {
                      builder.element(
                        'coordinates',
                        nest:
                            '${site.location!.longitude},${site.location!.latitude},0',
                      );
                    },
                  );
                },
              );
            }
          },
        );
      },
    );

    final kmlContent = builder.buildDocument().toXmlString(pretty: true);
    return (kmlContent, skippedCount);
  }

  String _buildKmlDescription(
    DiveSite site,
    List<Dive> siteDives,
    DepthUnit depthUnit,
    DateFormatPreference dateFormat,
  ) {
    final buffer = StringBuffer();

    buffer.writeln('<h3>${_escapeHtml(site.name)}</h3>');

    if (site.country != null || site.region != null) {
      final locationParts = <String>[];
      if (site.region != null) locationParts.add(site.region!);
      if (site.country != null) locationParts.add(site.country!);
      buffer.writeln(
        '<p><b>Location:</b> ${_escapeHtml(locationParts.join(', '))}</p>',
      );
    }

    if (site.minDepth != null || site.maxDepth != null) {
      final minDepth = site.minDepth != null
          ? convertDepth(site.minDepth, depthUnit)
          : '?';
      final maxDepth = site.maxDepth != null
          ? convertDepth(site.maxDepth, depthUnit)
          : '?';
      buffer.writeln(
        '<p><b>Depth:</b> $minDepth - $maxDepth ${depthUnit.symbol}</p>',
      );
    }

    if (site.difficulty != null) {
      buffer.writeln(
        '<p><b>Difficulty:</b> ${site.difficulty!.displayName}</p>',
      );
    }

    if (site.description.isNotEmpty) {
      buffer.writeln(
        '<p><b>Description:</b> ${_escapeHtml(site.description)}</p>',
      );
    }

    if (site.conditions != null) {
      final conditions = site.conditions!;
      if (conditions.waterType != null) {
        buffer.writeln(
          '<p><b>Water Type:</b> ${_escapeHtml(conditions.waterType!)}</p>',
        );
      }
      if (conditions.typicalCurrent != null) {
        buffer.writeln(
          '<p><b>Typical Current:</b> ${_escapeHtml(conditions.typicalCurrent!)}</p>',
        );
      }
      if (conditions.entryType != null) {
        buffer.writeln(
          '<p><b>Entry:</b> ${_escapeHtml(conditions.entryType!)}</p>',
        );
      }
    }

    if (site.hazards != null && site.hazards!.isNotEmpty) {
      buffer.writeln('<p><b>Hazards:</b> ${_escapeHtml(site.hazards!)}</p>');
    }

    if (site.accessNotes != null && site.accessNotes!.isNotEmpty) {
      buffer.writeln('<p><b>Access:</b> ${_escapeHtml(site.accessNotes!)}</p>');
    }

    if (site.rating != null) {
      final stars =
          '\u2605' * site.rating!.round() +
          '\u2606' * (5 - site.rating!.round());
      buffer.writeln('<p><b>Rating:</b> $stars</p>');
    }

    if (siteDives.isNotEmpty) {
      buffer.writeln('<hr/>');
      buffer.writeln('<h4>Dives at this site (${siteDives.length})</h4>');
      buffer.writeln('<ul>');

      for (final dive in siteDives) {
        final dateStr = formatDateForExport(dive.dateTime, dateFormat);
        final depth = dive.maxDepth != null
            ? '${convertDepth(dive.maxDepth, depthUnit)}${depthUnit.symbol}'
            : '?';
        final duration = dive.duration != null
            ? '${dive.duration!.inMinutes}min'
            : '?';
        buffer.writeln('<li><b>$dateStr</b> - $depth, $duration</li>');
      }

      buffer.writeln('</ul>');
    }

    return buffer.toString();
  }

  String _escapeHtml(String text) {
    return const HtmlEscape().convert(text);
  }
}
