import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/rules/data/services/rule_applier_support.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';

/// What identifies a dive or site in a change list (#3513): a dive by its
/// number, site and date as on the dive list; a site by its name and place.
class RuleTargetInfo {
  const RuleTargetInfo({
    required this.name,
    this.number,
    this.date,
    this.place,
  });

  /// The dive's site name, or the site's name; null for a dive with none.
  final String? name;
  final int? number;

  /// The dive's wall clock, flagged UTC.
  final DateTime? date;

  /// The site's region and country.
  final String? place;
}

class RuleTargetLabels {
  AppDatabase get _db => DatabaseService.instance.database;

  /// Info for each of [ids] that still exists.
  Future<Map<String, RuleTargetInfo>> infoFor(
    RuleSubject subject,
    Iterable<String> ids,
  ) async {
    final out = <String, RuleTargetInfo>{};
    for (final chunk in ruleIdChunks(ids.toSet().toList())) {
      final vars = [for (final id in chunk) Variable.withString(id)];
      final marks = placeholders(chunk.length);
      if (subject == RuleSubject.dives) {
        final rows = await _db
            .customSelect(
              'SELECT d.id, d.dive_number, d.dive_date_time, s.name AS site '
              'FROM dives d LEFT JOIN dive_sites s ON s.id = d.site_id '
              'WHERE d.id IN ($marks)',
              variables: vars,
            )
            .get();
        for (final r in rows) {
          out[r.read<String>('id')] = RuleTargetInfo(
            name: r.readNullable<String>('site'),
            number: r.readNullable<int>('dive_number'),
            date: wallClockUtcFromMillis(r.read<int>('dive_date_time')),
          );
        }
      } else {
        final rows = await _db
            .customSelect(
              'SELECT id, name, region, country FROM dive_sites '
              'WHERE id IN ($marks)',
              variables: vars,
            )
            .get();
        for (final r in rows) {
          final place = [
            r.readNullable<String>('region'),
            r.readNullable<String>('country'),
          ].whereType<String>().where((s) => s.isNotEmpty).join(', ');
          out[r.read<String>('id')] = RuleTargetInfo(
            name: r.read<String>('name'),
            place: place.isEmpty ? null : place,
          );
        }
      }
    }
    return out;
  }
}
