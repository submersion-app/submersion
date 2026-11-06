import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/presentation/localizations/week_start_material_localizations.dart';
import 'package:submersion/core/presentation/localizations/week_start_scope.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Pumps an app in [locale] whose Material localizations come through
/// [WeekStartScope] with [firstWeekday], and returns a context below it.
Future<BuildContext> _pumpScope(
  WidgetTester tester, {
  required int? firstWeekday,
  Locale locale = const Locale('en'),
}) async {
  late BuildContext captured;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [firstWeekdayProvider.overrideWithValue(firstWeekday)],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => WeekStartScope(child: child!),
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return captured;
}

void main() {
  group('WeekStartMaterialLocalizations', () {
    test('changes the week start and nothing else', () async {
      const delegate = WeekStartMaterialLocalizationsDelegate(DateTime.monday);
      final localizations = await delegate.load(const Locale('en'));
      final base = await GlobalMaterialLocalizations.delegate.load(
        const Locale('en'),
      );

      // en (en_US) starts on Sunday; the override moves it to Monday.
      expect(base.firstDayOfWeekIndex, 0);
      expect(localizations.firstDayOfWeekIndex, 1);

      // A sample across getters, methods with arguments and the date
      // formatting the pickers lean on.
      expect(localizations.okButtonLabel, base.okButtonLabel);
      expect(localizations.narrowWeekdays, base.narrowWeekdays);
      expect(
        localizations.tabLabel(tabIndex: 2, tabCount: 5),
        base.tabLabel(tabIndex: 2, tabCount: 5),
      );
      final date = DateTime(2026, 11, 6);
      expect(localizations.formatMediumDate(date), base.formatMediumDate(date));
      expect(localizations.formatMonthYear(date), base.formatMonthYear(date));
    });

    test('a Saturday start maps to index 6', () async {
      const delegate = WeekStartMaterialLocalizationsDelegate(
        DateTime.saturday,
      );
      final localizations = await delegate.load(const Locale('en'));
      expect(localizations.firstDayOfWeekIndex, 6);
    });

    test('no first day keeps the language default', () async {
      const delegate = WeekStartMaterialLocalizationsDelegate(null);
      final localizations = await delegate.load(const Locale('de'));
      expect(localizations, isNot(isA<WeekStartMaterialLocalizations>()));
      expect(localizations.firstDayOfWeekIndex, 1);
    });

    test('reloads only when the first day changes', () {
      const monday = WeekStartMaterialLocalizationsDelegate(DateTime.monday);
      expect(
        monday.shouldReload(
          const WeekStartMaterialLocalizationsDelegate(DateTime.monday),
        ),
        isFalse,
      );
      expect(
        monday.shouldReload(
          const WeekStartMaterialLocalizationsDelegate(DateTime.sunday),
        ),
        isTrue,
      );
    });
  });

  group('WeekStartScope', () {
    testWidgets('starts an English app on Monday', (tester) async {
      final context = await _pumpScope(tester, firstWeekday: DateTime.monday);
      final localizations = MaterialLocalizations.of(context);
      expect(localizations.firstDayOfWeekIndex, 1);
      // The rest of the app keeps its language.
      expect(localizations.okButtonLabel, 'OK');
    });

    testWidgets('starts a German app on Sunday', (tester) async {
      final context = await _pumpScope(
        tester,
        firstWeekday: DateTime.sunday,
        locale: const Locale('de'),
      );
      expect(MaterialLocalizations.of(context).firstDayOfWeekIndex, 0);
    });

    testWidgets('without a first day keeps the language default', (
      tester,
    ) async {
      final context = await _pumpScope(tester, firstWeekday: null);
      expect(MaterialLocalizations.of(context).firstDayOfWeekIndex, 0);
    });

    testWidgets('the date picker opens under the override', (tester) async {
      final context = await _pumpScope(tester, firstWeekday: DateTime.monday);
      unawaited(
        showDatePicker(
          context: context,
          initialDate: DateTime(2026, 11, 6),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        ),
      );
      await tester.pumpAndSettle();

      final pickerContext = tester.element(find.byType(DatePickerDialog));
      expect(MaterialLocalizations.of(pickerContext).firstDayOfWeekIndex, 1);
    });
  });
}
