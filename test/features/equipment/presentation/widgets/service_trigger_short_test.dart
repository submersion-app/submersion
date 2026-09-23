import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_trigger_text.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The short form of a clock's trigger, for a one-line chip or a tooltip
/// where [formatServiceTriggerText]'s joined line does not fit.
///
/// Every short form carries its own preposition ("in 12d", "in 3 dives"),
/// because it composes into equipment_service_dueRelative, which does not
/// supply one.
void main() {
  final t0 = DateTime(2025, 1, 1);
  final now = DateTime(2026, 1, 1);

  ServiceClockStatus status({
    DateTime? dueDate,
    Map<ExposureUnit, ClockUsage> usageByUnit = const {},
    ServiceClockSeverity severity = ServiceClockSeverity.dueSoon,
  }) => ServiceClockStatus(
    schedule: ServiceSchedule(
      id: 's1',
      equipmentId: 'e1',
      serviceKindId: 'k1',
      createdAt: t0,
      updatedAt: t0,
    ),
    kind: ServiceKind(
      id: 'k1',
      name: 'General service',
      defaultIntervalDays: 365,
      isBuiltIn: true,
      createdAt: t0,
      updatedAt: t0,
    ),
    anchor: t0,
    dueDate: dueDate,
    usageByUnit: usageByUnit,
    severity: severity,
    now: now,
  );

  /// Pumps a throwaway widget so the formatter can read its l10n.
  Future<String> render(
    WidgetTester tester,
    ServiceClockStatus s, {
    Locale locale = const Locale('en'),
  }) async {
    late String out;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            out = formatServiceTriggerShort(
              context,
              units: const UnitFormatter(AppSettings()),
              now: now,
              status: s,
            );
            return const SizedBox();
          },
        ),
      ),
    );
    return out;
  }

  testWidgets('a date clock reads as a short relative day count', (
    tester,
  ) async {
    final text = await render(tester, status(dueDate: DateTime(2026, 1, 13)));
    expect(text, 'in 12d');
  });

  testWidgets('a dives clock reads as a short remaining count', (tester) async {
    final text = await render(
      tester,
      status(
        usageByUnit: {
          ExposureUnit.dives: const ClockUsage(interval: 50, since: 47),
        },
      ),
    );
    expect(text, 'in 3 dives');
  });

  testWidgets('an hours clock keeps one fractional digit', (tester) async {
    final text = await render(
      tester,
      status(
        usageByUnit: {
          ExposureUnit.hours: const ClockUsage(interval: 100, since: 95.5),
        },
      ),
    );
    expect(text, 'in 4.5 hours');
  });

  testWidgets('a date trigger wins when the clock also ticks on dives', (
    tester,
  ) async {
    final text = await render(
      tester,
      status(
        dueDate: DateTime(2026, 1, 13),
        usageByUnit: {
          ExposureUnit.dives: const ClockUsage(interval: 50, since: 47),
        },
      ),
    );
    expect(text, 'in 12d');
  });

  testWidgets('with no date, the unit closest to expiry wins', (tester) async {
    final text = await render(
      tester,
      status(
        usageByUnit: {
          // 40 percent of the interval left.
          ExposureUnit.dives: const ClockUsage(interval: 50, since: 30),
          // 10 percent left, so this one is the one reported.
          ExposureUnit.hours: const ClockUsage(interval: 100, since: 90),
        },
      ),
    );
    expect(text, 'in 10.0 hours');
  });

  testWidgets('a spent usage clock never reports a negative remainder', (
    tester,
  ) async {
    final text = await render(
      tester,
      status(
        usageByUnit: {
          ExposureUnit.dives: const ClockUsage(interval: 50, since: 62),
        },
        severity: ServiceClockSeverity.overdue,
      ),
    );
    expect(text, 'in 0 dives');
  });

  testWidgets('one dive left reads in the singular', (tester) async {
    // An integer unit takes the CLDR plural, so a count of one must not read
    // "in 1 dives" (#2260).
    final text = await render(
      tester,
      status(
        usageByUnit: {
          ExposureUnit.dives: const ClockUsage(interval: 50, since: 49),
        },
      ),
    );
    expect(text, 'in 1 dive');
  });

  testWidgets('one battery cycle left reads in the singular', (tester) async {
    final text = await render(
      tester,
      status(
        usageByUnit: {
          ExposureUnit.cycles: const ClockUsage(interval: 300, since: 299),
        },
      ),
    );
    expect(text, 'in 1 battery cycle');
  });

  testWidgets('a zero-dive count keeps its digit in fr', (tester) async {
    // fr puts 0 in the `one` category, so a branch that hardcoded the
    // singular would print no count at all for a spent clock.
    final text = await render(
      tester,
      status(
        usageByUnit: {
          ExposureUnit.dives: const ClockUsage(interval: 50, since: 50),
        },
      ),
      locale: const Locale('fr'),
    );
    expect(text, contains('0'));
  });

  testWidgets('a clock with no configured trigger yields an empty string', (
    tester,
  ) async {
    final text = await render(tester, status());
    expect(text, '');
  });

  testWidgets('a zero-day count keeps its digit in fr', (tester) async {
    // The CLDR `one` category covers zero in French, so a branch that
    // hardcoded the singular would drop the count entirely.
    final text = await render(
      tester,
      status(dueDate: now),
      locale: const Locale('fr'),
    );
    expect(text, contains('0'));
  });
}
