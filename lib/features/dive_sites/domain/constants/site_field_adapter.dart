import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/text/markdown/notes_plain_text.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/domain/constants/site_field.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entry_method_list.dart';
import 'package:submersion/shared/constants/entity_field.dart';

/// "Xh Ym" for a duration of an hour or more, "Xmin" otherwise.
///
/// Mirrors how the site detail page renders its duration statistics, so the
/// same dive reads the same way in the list and on the page.
///
/// Rounds to whole seconds first. SQLite's AVG returns fractional seconds,
/// and the detail page rounds before formatting; truncating here instead
/// would report a different minute for the same dive.
String _formatDurationSeconds(num seconds) {
  final totalMinutes = seconds.round() ~/ 60;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}min';
}

/// Adapter bridging [SiteWithCount] entities with [SiteField] for the generic
/// table infrastructure.
class SiteFieldAdapter extends EntityFieldAdapter<SiteWithCount, SiteField> {
  static final SiteFieldAdapter instance = SiteFieldAdapter._();
  SiteFieldAdapter._();

  static final Map<String, List<SiteField>> _fieldsByCategory = () {
    final map = <String, List<SiteField>>{};
    for (final f in SiteField.values) {
      map.putIfAbsent(f.categoryName, () => []).add(f);
    }
    return map;
  }();

  @override
  List<SiteField> get allFields => SiteField.values;

  @override
  Map<String, List<SiteField>> get fieldsByCategory => _fieldsByCategory;

  @override
  dynamic extractValue(SiteField field, SiteWithCount entity) {
    final site = entity.site;
    switch (field) {
      case SiteField.siteName:
        return site.name;
      case SiteField.location:
        return site.locationString;
      case SiteField.country:
        return site.country;
      case SiteField.region:
        return site.region;
      case SiteField.city:
        return site.city;
      case SiteField.island:
        return site.island;
      case SiteField.bodyOfWater:
        return site.bodyOfWater;
      case SiteField.diveCount:
        return entity.diveCount;
      case SiteField.maxDepth:
        return site.maxDepth;
      case SiteField.minDepth:
        return site.minDepth;
      case SiteField.altitude:
        return site.altitude;
      case SiteField.waterType:
        return site.waterType?.displayName;
      case SiteField.typicalVisibility:
      case SiteField.typicalCurrent:
        // No backing column. These members are retained because saved table
        // layouts reference them by name, so removing them would throw on
        // load. They render blank until a real column exists.
        return null;
      case SiteField.difficulty:
        return site.difficulty;
      case SiteField.entryType:
        return _methodNames(site.entryMethods);
      case SiteField.exitMethod:
        return _methodNames(site.exitMethods);
      case SiteField.bestSeason:
        // No backing column; retained for saved-layout compatibility.
        return null;
      case SiteField.mooringNumber:
        return site.mooringNumber;
      case SiteField.hazards:
        return site.hazards;
      case SiteField.rating:
        return site.rating;
      case SiteField.notes:
        return site.notes.isEmpty ? null : markdownToPlainText(site.notes);
      case SiteField.latitude:
        return site.location?.latitude;
      case SiteField.longitude:
        return site.location?.longitude;
      case SiteField.depthRange:
        if (site.minDepth == null && site.maxDepth == null) return null;
        return (min: site.minDepth, max: site.maxDepth);
      case SiteField.lastDived:
        return entity.lastDivedAt;
      case SiteField.maxDepthReached:
        return entity.maxDepthReached;
      case SiteField.firstDived:
        return entity.firstDivedAt;
      case SiteField.averageDepthReached:
        return entity.averageDepthReached;
      case SiteField.longestDive:
        return entity.longestDiveSeconds;
      case SiteField.averageDuration:
        return entity.averageDurationSeconds;
      // Stored names, as the table already renders difficulty and water type
      // through displayName; an empty list reads as no value.
      case SiteField.siteTypes:
        return entity.siteTypes.isEmpty
            ? null
            : [for (final t in entity.siteTypes) t.name];
      case SiteField.tags:
        return entity.tags.isEmpty
            ? null
            : [for (final t in entity.tags) t.name];
    }
  }

  @override
  String formatValue(SiteField field, dynamic value, UnitFormatter units) {
    if (value == null) return kFieldValuePlaceholder;
    switch (field) {
      case SiteField.siteName:
      case SiteField.location:
      case SiteField.country:
      case SiteField.region:
      case SiteField.city:
      case SiteField.island:
      case SiteField.bodyOfWater:
      case SiteField.waterType:
      case SiteField.typicalVisibility:
      case SiteField.typicalCurrent:
      case SiteField.entryType:
      case SiteField.exitMethod:
      case SiteField.bestSeason:
      case SiteField.mooringNumber:
      case SiteField.hazards:
      case SiteField.notes:
        return value as String;
      case SiteField.diveCount:
        return (value as int).toString();
      case SiteField.maxDepth:
      case SiteField.minDepth:
        return units.formatDepth(value as double, decimals: 0);
      case SiteField.altitude:
        return units.formatAltitude(value as double);
      case SiteField.difficulty:
        return (value as SiteDifficulty).displayName;
      case SiteField.rating:
        return formatRatingForDisplay(value as double);
      case SiteField.latitude:
        return units.formatLatitude(value as double);
      case SiteField.longitude:
        return units.formatLongitude(value as double);
      case SiteField.depthRange:
        final range = value as ({double? min, double? max});
        final min = range.min;
        final max = range.max;
        if (min != null && max != null) {
          // One trailing symbol for the pair ("16-98ft"), matching the site
          // list card's historical rendering.
          final low = units.convertDepth(min).toStringAsFixed(0);
          return '$low-${units.formatDepth(max, decimals: 0)}';
        }
        return units.formatDepth(max ?? min, decimals: 0);
      case SiteField.lastDived:
        return units.formatDate(value as DateTime);
      case SiteField.maxDepthReached:
        return units.formatDepth(value as double, decimals: 0);
      case SiteField.firstDived:
        return units.formatDate(value as DateTime);
      case SiteField.averageDepthReached:
        return units.formatDepth(value as double, decimals: 1);
      case SiteField.longestDive:
      case SiteField.averageDuration:
        return _formatDurationSeconds(value as num);
      case SiteField.siteTypes:
      case SiteField.tags:
        return (value as List).join(', ');
    }
  }

  @override
  SiteField fieldFromName(String name) {
    return SiteField.values.firstWhere((e) => e.name == name);
  }
}

/// A site's entry or exit methods for a table cell, in the export vocabulary
/// ([EntryMethod.displayName]); null when there are none.
String? _methodNames(List<EntryMethod> methods) => methods.isEmpty
    ? null
    : joinEntryMethodNames(methods, (m) => m.displayName);
