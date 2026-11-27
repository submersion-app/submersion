import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/opening_hours/opening_hours.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_opening_hours_card_editor.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import 'site_editor_harness.dart';

/// The Opening hours card edited in place (issue #5073).
void main() {
  final l = AppLocalizationsEn();
  const site = DiveSite(id: 's1', name: 'Stoney Cove');

  Future<SiteEditorHarness> pump(WidgetTester tester, {DiveSite s = site}) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 2400);
    addTearDown(tester.view.reset);
    return pumpSiteEditor(
      tester,
      s,
      (session) => SiteOpeningHoursCardEditor(session: session),
    );
  }

  OpeningHours? hoursOf(SiteEditorHarness h) =>
      h.session.valueOf(siteOpeningHoursField);

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('a new schedule starts closed every day', (tester) async {
    final h = await pump(tester);

    await tapKey(tester, 'hours_add_schedule');

    final schedule = hoursOf(h)!.schedules.single;
    for (var d = DateTime.monday; d <= DateTime.sunday; d++) {
      expect(schedule.dayHours(d).isClosed, isTrue);
    }
  });

  testWidgets('a day set to hours gets a morning, then another range', (
    tester,
  ) async {
    final h = await pump(tester);
    await tapKey(tester, 'hours_add_schedule');

    await tapKey(tester, 'hours_day_0_6_hours');
    expect(
      hoursOf(h)!.schedules.single.dayHours(DateTime.saturday).ranges,
      const [TimeRange(480, 720)],
    );

    await tapKey(tester, 'hours_day_0_6_add_range');
    expect(
      hoursOf(h)!.schedules.single.dayHours(DateTime.saturday).ranges,
      const [TimeRange(480, 720), TimeRange(780, 900)],
    );

    await tapKey(tester, 'hours_day_0_6_remove_range_0');
    expect(
      hoursOf(h)!.schedules.single.dayHours(DateTime.saturday).ranges,
      const [TimeRange(780, 900)],
    );
  });

  testWidgets('copying a day reaches only the days picked', (tester) async {
    final h = await pump(tester);
    await tapKey(tester, 'hours_add_schedule');
    await tapKey(tester, 'hours_day_0_6_24h');

    await tapKey(tester, 'hours_day_0_6_copy');
    await tapKey(tester, 'hours_copy_day_7');
    await tapKey(tester, 'hours_copy_confirm');

    final schedule = hoursOf(h)!.schedules.single;
    expect(schedule.dayHours(DateTime.sunday), const DayHours.open24h());
    expect(schedule.dayHours(DateTime.friday).isClosed, isTrue);
  });

  testWidgets('seasonal starts as 1 Apr to 31 Oct', (tester) async {
    final h = await pump(tester);
    await tapKey(tester, 'hours_add_schedule');

    await tapKey(tester, 'hours_schedule_0_seasonal');

    expect(
      hoursOf(h)!.schedules.single.season,
      const YearlyDateRange(start: MonthDay(4, 1), end: MonthDay(10, 31)),
    );
    expect(find.text('Apr 1'), findsOneWidget);
    expect(find.text('Oct 31'), findsOneWidget);
  });

  testWidgets('24/7 keeps the schedules underneath', (tester) async {
    final h = await pump(tester);
    await tapKey(tester, 'hours_add_schedule');
    await tapKey(tester, 'hours_day_0_6_hours');

    await tapKey(tester, 'hours_always_open');
    expect(hoursOf(h)!.alwaysOpen, isTrue);
    expect(find.byKey(const ValueKey('hours_add_schedule')), findsNothing);

    await tapKey(tester, 'hours_always_open');
    expect(hoursOf(h)!.alwaysOpen, isFalse);
    expect(
      hoursOf(h)!.schedules.single.dayHours(DateTime.saturday).ranges,
      const [TimeRange(480, 720)],
    );
  });

  testWidgets('deleting the last schedule with no note leaves no hours', (
    tester,
  ) async {
    final h = await pump(tester);
    await tapKey(tester, 'hours_add_schedule');

    await tapKey(tester, 'hours_schedule_0_delete');

    expect(hoursOf(h), isNull);
  });

  testWidgets('the note writes through', (tester) async {
    final h = await pump(tester);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('hours_note')),
        matching: find.byType(EditableText),
      ),
      'Book slots by phone',
    );
    await tester.pump();

    expect(hoursOf(h)!.note, 'Book slots by phone');
  });

  testWidgets('overlapping hours block saving, with the reason', (
    tester,
  ) async {
    final h = await pump(tester);

    h.session.set(
      siteOpeningHoursField,
      OpeningHours(
        schedules: [
          OpeningSchedule(
            days: {
              DateTime.saturday: DayHours.ranges(const [
                TimeRange(480, 720),
                TimeRange(700, 800),
              ]),
            },
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(siteOpeningHoursIsValid(h.session), isFalse);
    expect(find.text(l.diveSites_hours_invalid), findsOneWidget);
  });
}
