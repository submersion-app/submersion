// pre-push: scans lib/l10n/arb/
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../helpers/icu_plural_branches.dart';

/// Arabic has six CLDR plural categories, and the counted noun changes form
/// across them: one (1) and two (2) take the singular and the dual, few (3 to
/// 10) the plural, and many (11 to 99) and other (100 and up) the singular
/// again. A plural that gives only `=1` and `other` falls back to `other` for
/// every count above one without an error, so 2 never reads as a dual and
/// either 3 to 10 or 11 and up get the wrong noun form.
///
/// Issue #2879: the trip overview strings were written with only zero, one
/// and other. The same gap ran through most of app_ar.arb, so the guard covers
/// the whole file.
void main() {
  test('every Arabic plural gives the two, few and many forms', () {
    final arb =
        jsonDecode(File('lib/l10n/arb/app_ar.arb').readAsStringSync())
            as Map<String, dynamic>;

    final offenders = <String>[];
    arb.forEach((key, value) {
      if (key.startsWith('@') || value is! String) return;
      forEachPluralArgument(value, (argument, branches) {
        final missing = [
          if (!branches.containsKey('two') && !branches.containsKey('=2'))
            'two',
          if (!branches.containsKey('few')) 'few',
          if (!branches.containsKey('many')) 'many',
        ];
        if (missing.isNotEmpty) {
          offenders.add('$key [$argument] lacks ${missing.join(', ')}');
        }
      });
    });

    expect(
      offenders,
      isEmpty,
      reason:
          '${offenders.length} plural(s) in app_ar.arb miss Arabic plural '
          'categories, so their counts fall back to `other` and take the '
          'wrong noun form.\n'
          '${offenders.take(20).join('\n')}'
          '${offenders.length > 20 ? '\n...and ${offenders.length - 20} more' : ''}',
    );
  });

  // Counts are masked first: 3 and 100 differ by digits alone when a branch
  // falls back to `other`, which is exactly the bug being guarded.
  test('the trip overview plurals render a distinct form per category', () {
    final digits = RegExp(r'\p{Nd}+', unicode: true);
    final ar = lookupAppLocalizations(const Locale('ar'));

    final renders = <String, String Function(int)>{
      'trips_overview_checklist_dueSoon': ar.trips_overview_checklist_dueSoon,
      'trips_overview_checklist_overdue': ar.trips_overview_checklist_overdue,
      'trips_overview_gear_packed': ar.trips_overview_gear_packed,
      'trips_overview_gear_cylinders': ar.trips_overview_gear_cylinders,
      'trips_overview_gear_serviceAlerts': ar.trips_overview_gear_serviceAlerts,
      'trips_overview_itinerary_days': ar.trips_overview_itinerary_days,
      'trips_overview_itinerary_divesPlanned':
          ar.trips_overview_itinerary_divesPlanned,
      'trips_overview_plan_sharing': ar.trips_overview_plan_sharing,
      'trips_itinerary_plannedDives': ar.trips_itinerary_plannedDives,
    };

    renders.forEach((key, render) {
      // one (1), two (2), few (3), other (100).
      final shapes = [
        for (final n in [1, 2, 3, 100]) render(n).replaceAll(digits, '#'),
      ];
      expect(shapes.toSet(), hasLength(4), reason: '$key: $shapes');
    });
  });

  test('the counted noun agrees with its count', () {
    final ar = lookupAppLocalizations(const Locale('ar'));

    expect(ar.trips_overview_itinerary_days(1), 'يوم واحد');
    expect(ar.trips_overview_itinerary_days(2), 'يومان');
    expect(ar.trips_overview_itinerary_days(3), '3 أيام');
    expect(ar.trips_overview_itinerary_days(11), '11 يومًا');
    expect(ar.trips_overview_itinerary_days(100), '100 يوم');

    expect(ar.trips_overview_gear_cylinders(2), 'أسطوانتان');
    expect(ar.trips_overview_gear_cylinders(10), '10 أسطوانات');
    expect(ar.trips_overview_gear_cylinders(25), '25 أسطوانة');
  });
}
