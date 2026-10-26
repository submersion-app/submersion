// The demo-data tools run under `flutter test` and drive the app's database
// the way its tests do.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:math';

import 'package:drift/drift.dart' show DriftSqlType, GeneratedColumn;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';

import '../harvest/harvester.dart';
import '../shape/dive_shape.dart';
import '../shape/shape_extractor.dart';

class PrivacyViolation {
  const PrivacyViolation(this.kind, this.where);

  /// `profile` or `text`.
  final String kind;
  final String where;

  @override
  String toString() => '$kind: $where';
}

/// The last gate before a demo logbook is written (issue #3708): no dive in
/// it may resemble one real dive, and no personal text in it may be a value
/// from a source.
///
/// **Profiles.** Both dives are resampled to [_points] points over their own
/// duration. Their distance is the depth RMSE divided by the larger maximum
/// depth, plus half the relative difference in duration, plus half the
/// relative difference in maximum depth. Below [similarityThreshold] the demo
/// dive is too close to that source dive. An unreshaped copy is at 0; the
/// reshaper's smallest change (4% in depth and in time) lands near 0.06.
///
/// **Text.** Every value in a personal column (names, notes, serials, contact
/// details) is hashed with the harvest's salt and looked up among the
/// sources' hashes. Values from the app's public catalogues are allowed.
class PrivacyCheck {
  PrivacyCheck._();

  static const similarityThreshold = 0.04;
  static const _points = 200;

  /// Whether [column] holds text the check compares against the sources.
  static bool isPersonalText(GeneratedColumn<Object> column) =>
      column.type == DriftSqlType.string &&
      personalColumn.hasMatch(column.name);

  static final personalColumn = RegExp(
    r'(name|notes|note|description|serial|email|phone|address|buddy|'
    r'master|captain|operator|instructor|comment|title|label|signature)$',
  );

  static double distance(DiveShape a, DiveShape b) {
    final maxA = a.maxDepth;
    final maxB = b.maxDepth;
    final maxBoth = max(maxA, maxB);
    if (maxBoth <= 0) return 1;
    final ra = _resample(a);
    final rb = _resample(b);
    var sum = 0.0;
    for (var i = 0; i < _points; i++) {
      final d = ra[i] - rb[i];
      sum += d * d;
    }
    final rmse = sqrt(sum / _points) / maxBoth;
    final durA = a.durationSec.toDouble();
    final durB = b.durationSec.toDouble();
    final dur = (durA - durB).abs() / max(1.0, max(durA, durB));
    return rmse + 0.5 * dur + 0.5 * (maxA - maxB).abs() / maxBoth;
  }

  static bool tooClose(DiveShape a, DiveShape b) =>
      distance(a, b) < similarityThreshold;

  /// Checks [demoDb]: its dives against [sources], its personal text against
  /// [sourceStringHashes].
  static Future<List<PrivacyViolation>> run({
    required AppDatabase demoDb,
    required List<DiveShape> sources,
    required Set<String> sourceStringHashes,
    required String salt,
    Set<String> publicStrings = const {},
  }) async {
    final violations = <PrivacyViolation>[];
    // Reads [demoDb] through the app's repositories; the caller restores
    // whatever database it had open.
    DatabaseService.instance.setTestDatabase(demoDb);
    final demoShapes = await ShapeExtractor().fromDatabase();
    for (final demo in demoShapes) {
      for (final s in sources) {
        if (!_comparable(demo, s)) continue;
        if (tooClose(demo, s)) {
          violations.add(PrivacyViolation('profile', 'demo dive ${demo.id}'));
          break;
        }
      }
    }

    final allowed = {for (final s in publicStrings) s.trim().toLowerCase()};
    for (final t in demoDb.allTables) {
      for (final c in t.$columns) {
        if (!isPersonalText(c)) continue;
        final rows = await demoDb
            .customSelect(
              'SELECT DISTINCT "${c.name}" AS v FROM "${t.actualTableName}" '
              'WHERE "${c.name}" IS NOT NULL',
            )
            .get();
        for (final row in rows) {
          final v = row.read<String>('v').trim();
          if (v.length < 3 || allowed.contains(v.toLowerCase())) continue;
          if (sourceStringHashes.contains(Harvester.hashString(salt, v))) {
            // The value is the demo's own text, which would be published if
            // it passed, so naming it here reveals nothing new.
            violations.add(
              PrivacyViolation('text', '${t.actualTableName}.${c.name} "$v"'),
            );
          }
        }
      }
    }
    return violations;
  }

  /// Dives whose depth and duration differ by more than a fifth cannot be
  /// within the threshold; skipping them keeps the check quick.
  static bool _comparable(DiveShape a, DiveShape b) {
    final ma = a.maxDepth;
    final mb = b.maxDepth;
    final da = a.durationSec;
    final db = b.durationSec;
    return (ma - mb).abs() <= 0.2 * max(ma, mb) &&
        (da - db).abs() <= 0.2 * max(da, db);
  }

  static List<double> _resample(DiveShape s) {
    final out = List<double>.filled(_points, 0);
    final samples = s.samples;
    if (samples.isEmpty) return out;
    final dur = max(1, s.durationSec);
    var j = 0;
    for (var i = 0; i < _points; i++) {
      final t = dur * i / (_points - 1);
      while (j < samples.length - 2 && samples[j + 1].t < t) {
        j++;
      }
      final a = samples[j];
      final b = samples[min(j + 1, samples.length - 1)];
      final span = b.t - a.t;
      final f = span <= 0 ? 0.0 : ((t - a.t) / span).clamp(0.0, 1.0);
      out[i] = a.depth + (b.depth - a.depth) * f;
    }
    return out;
  }
}
