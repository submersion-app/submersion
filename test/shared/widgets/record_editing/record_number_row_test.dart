import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_number_row.dart';

@immutable
class _Rec {
  const _Rec({this.altitude});

  final double? altitude;

  @override
  bool operator ==(Object other) => other is _Rec && other.altitude == altitude;

  @override
  int get hashCode => altitude.hashCode;
}

/// Compared with `==`: the row supplies the "same number on screen" rule.
final _altitude = EditField<_Rec, double?>(
  id: 'altitude',
  cardId: 'altitude',
  read: (r) => r.altitude,
  write: (r, v) => _Rec(altitude: v),
);

const _metresPerFoot = 0.3048;

double _toFeet(double metres) => metres / _metresPerFoot;
double _fromFeet(double feet) => feet * _metresPerFoot;

RecordEditController<_Rec> _unlocked(_Rec stored) {
  final controller = RecordEditController<_Rec>(onSave: (_) async {})
    ..unlock(stored)
    ..openCard('altitude');
  addTearDown(controller.dispose);
  return controller;
}

Widget _host(
  RecordEditController<_Rec> controller, {
  bool feet = true,
  bool allowNegative = true,
  bool integer = false,
  int fractionDigits = 0,
  String? placeholder,
  bool showRow = true,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: RecordEditScope<_Rec>(
        controller: controller,
        child: Column(
          children: [
            if (showRow)
              RecordNumberRow<_Rec>(
                session: controller.session!,
                field: _altitude,
                label: 'Altitude',
                suffixText: feet ? 'ft' : 'm',
                toDisplay: feet ? _toFeet : null,
                fromDisplay: feet ? _fromFeet : null,
                allowNegative: allowNegative,
                integer: integer,
                fractionDigits: fractionDigits,
                placeholder: placeholder,
              ),
            const TextField(key: ValueKey('elsewhere')),
          ],
        ),
      ),
    ),
  );
}

/// Opens the resting row and types [text] into it.
Future<void> _type(WidgetTester tester, String resting, String text) async {
  await tester.tap(find.text(resting));
  await tester.pump();
  await tester.enterText(find.byType(TextFormField), text);
  await tester.pump();
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold)));

/// The row 600 px down a page seen through a 300 px high window.
Widget _tallHost(RecordEditController<_Rec> controller) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: 300,
          child: RecordEditScope<_Rec>(
            controller: controller,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 600),
                  RecordNumberRow<_Rec>(
                    session: controller.session!,
                    field: _altitude,
                    label: 'Altitude',
                    suffixText: 'm',
                  ),
                  const SizedBox(height: 600),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the value in the display unit with its suffix', (
    tester,
  ) async {
    final controller = _unlocked(const _Rec(altitude: 1234.5));
    await tester.pumpWidget(_host(controller));

    expect(find.text('Altitude'), findsOneWidget);
    expect(find.text('4050 ft'), findsOneWidget);
    expect(controller.isDirty, isFalse);
  });

  testWidgets('an empty value shows the placeholder', (tester) async {
    final controller = _unlocked(const _Rec());
    await tester.pumpWidget(_host(controller, placeholder: '1013'));

    expect(find.text('1013'), findsOneWidget);
  });

  // 4050 ft reads back as 1,234.44 m. Focusing the row and leaving it must
  // not turn that into a change.
  testWidgets('opening the row and leaving it keeps the sitting clean', (
    tester,
  ) async {
    final controller = _unlocked(const _Rec(altitude: 1234.5));
    await tester.pumpWidget(_host(controller));

    await tester.tap(find.text('4050 ft'));
    await tester.pump();
    expect(find.byType(TextFormField), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('elsewhere')));
    await tester.pump();

    expect(controller.isDirty, isFalse);
    expect(controller.session!.valueOf(_altitude), 1234.5);
  });

  testWidgets('typing sets the value in canonical units', (tester) async {
    final controller = _unlocked(const _Rec(altitude: 1234.5));
    await tester.pumpWidget(_host(controller));

    await _type(tester, '4050 ft', '100');

    expect(controller.session!.valueOf(_altitude), closeTo(30.48, 0.001));
    expect(controller.session!.changedCardIds, {'altitude'});
  });

  testWidgets('typing the shown number back clears the change', (tester) async {
    final controller = _unlocked(const _Rec(altitude: 1234.5));
    await tester.pumpWidget(_host(controller));
    await _type(tester, '4050 ft', '100');

    await tester.enterText(find.byType(TextFormField), '4050');
    await tester.pump();

    expect(controller.isDirty, isFalse);
  });

  testWidgets('emptying the row clears the value', (tester) async {
    final controller = _unlocked(const _Rec(altitude: 1234.5));
    await tester.pumpWidget(_host(controller));

    await _type(tester, '4050 ft', '');

    expect(controller.session!.valueOf(_altitude), isNull);
    expect(controller.isDirty, isTrue);
  });

  testWidgets('typing unreadable text marks the card and shows the message', (
    tester,
  ) async {
    final controller = _unlocked(const _Rec(altitude: 1234.5));
    await tester.pumpWidget(_host(controller));

    await _type(tester, '4050 ft', '1.2.3');

    expect(controller.invalidCardIds, {'altitude'});
    expect(controller.isDirty, isFalse);
    expect(find.text(_l10n(tester).numberInput_invalidNumber('.')), findsOne);
  });

  testWidgets('fixing it clears the mark', (tester) async {
    final controller = _unlocked(const _Rec(altitude: 1234.5));
    await tester.pumpWidget(_host(controller));
    await _type(tester, '4050 ft', '1.2.3');

    await tester.enterText(find.byType(TextFormField), '120');
    await tester.pump();

    expect(controller.invalidCardIds, isEmpty);
    expect(
      controller.session!.valueOf(_altitude),
      closeTo(120 * _metresPerFoot, 0.001),
    );
  });

  testWidgets('a negative number is refused when the row forbids one', (
    tester,
  ) async {
    final controller = _unlocked(const _Rec(altitude: 1234.5));
    await tester.pumpWidget(_host(controller, allowNegative: false));

    await _type(tester, '4050 ft', '-5');

    expect(controller.invalidCardIds, {'altitude'});
    expect(controller.isDirty, isFalse);
    expect(find.text(_l10n(tester).numberInput_notNegative), findsOne);
  });

  testWidgets('a negative number is a value when the row allows one', (
    tester,
  ) async {
    final controller = _unlocked(const _Rec(altitude: 1234.5));
    await tester.pumpWidget(_host(controller));

    await _type(tester, '4050 ft', '-5');

    expect(controller.invalidCardIds, isEmpty);
    expect(
      controller.session!.valueOf(_altitude),
      closeTo(-5 * _metresPerFoot, 0.001),
    );
  });

  testWidgets('a whole-number row refuses a fraction', (tester) async {
    final controller = _unlocked(const _Rec(altitude: 1234.5));
    await tester.pumpWidget(_host(controller, integer: true));

    await _type(tester, '4050 ft', '12.5');

    expect(controller.invalidCardIds, {'altitude'});
    expect(find.text(_l10n(tester).numberInput_invalidWholeNumber), findsOne);
  });

  testWidgets('a row removed with unreadable text clears its mark', (
    tester,
  ) async {
    final controller = _unlocked(const _Rec(altitude: 1234.5));
    await tester.pumpWidget(_host(controller));
    await _type(tester, '4050 ft', '1.2.3');
    expect(controller.invalidCardIds, {'altitude'});

    await tester.pumpWidget(_host(controller, showRow: false));

    expect(controller.invalidCardIds, isEmpty);
  });

  testWidgets('a value set from elsewhere shows in the resting row', (
    tester,
  ) async {
    final controller = _unlocked(const _Rec(altitude: 1234.5));
    await tester.pumpWidget(_host(controller));

    controller.session!.set(_altitude, 304.8);
    await tester.pump();

    expect(find.text('1000 ft'), findsOneWidget);
  });

  testWidgets('decimals follow fractionDigits', (tester) async {
    final controller = _unlocked(const _Rec(altitude: 1.5));
    await tester.pumpWidget(_host(controller, feet: false, fractionDigits: 1));

    expect(find.text('1.5 m'), findsOneWidget);
  });

  testWidgets('a change of unit re-shows an untouched value', (tester) async {
    final controller = _unlocked(const _Rec(altitude: 1200));
    await tester.pumpWidget(_host(controller));
    expect(find.text('3937 ft'), findsOneWidget);

    await tester.pumpWidget(_host(controller, feet: false));
    await tester.pump();

    expect(find.text('1200 m'), findsOneWidget);
    expect(controller.isDirty, isFalse);
  });

  testWidgets('with no controller above it the row still edits the session', (
    tester,
  ) async {
    final controller = _unlocked(const _Rec(altitude: 1234.5));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RecordNumberRow<_Rec>(
            session: controller.session!,
            field: _altitude,
            label: 'Altitude',
            suffixText: 'm',
          ),
        ),
      ),
    );

    await _type(tester, '1235 m', '1.2.3');
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextFormField), '50');
    await tester.pump();

    expect(controller.session!.valueOf(_altitude), 50);
  });

  // A refused Done or Save names the unreadable field, and its row brings
  // itself into view: on a tall card it can be far from the card's top.
  group('a row asked to show itself', () {
    Finder field() => find.byType(TextFormField);

    /// Types unreadable text into the row, then scrolls it out of sight.
    Future<RecordEditController<_Rec>> unreadableAndAway(
      WidgetTester tester,
    ) async {
      final controller = _unlocked(const _Rec(altitude: 120));
      await tester.pumpWidget(_tallHost(controller));
      await tester.ensureVisible(find.text('120 m'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('120 m'));
      await tester.pump();
      await tester.enterText(field(), '1.2.3');
      await tester.pump();
      expect(controller.invalidCardIds, {'altitude'});
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pump();
      expect(tester.getRect(field()).top, greaterThan(300));
      return controller;
    }

    void expectInView(WidgetTester tester) {
      final rect = tester.getRect(field());
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(300));
    }

    testWidgets('a refused Done scrolls the row into view', (tester) async {
      final controller = await unreadableAndAway(tester);

      controller.closeCard('altitude');
      await tester.pumpAndSettle();

      expectInView(tester);
      expect(controller.openCardIds, {'altitude'});
      expect(controller.revealRequest, isNull, reason: 'answered');
    });

    testWidgets('a refused Save scrolls the row into view', (tester) async {
      final controller = await unreadableAndAway(tester);

      expect(await controller.save(), isFalse);
      await tester.pumpAndSettle();

      expectInView(tester);
    });

    testWidgets('asked again after scrolling away, it scrolls again', (
      tester,
    ) async {
      final controller = await unreadableAndAway(tester);
      controller.closeCard('altitude');
      await tester.pumpAndSettle();
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pump();

      controller.closeCard('altitude');
      await tester.pumpAndSettle();

      expectInView(tester);
    });

    testWidgets('a request that names another field does not move it', (
      tester,
    ) async {
      final controller = await unreadableAndAway(tester);
      // Another field of the same card became unreadable first.
      controller
        ..setFieldInvalid('altitude', 'altitude', invalid: false)
        ..setFieldInvalid('altitude', 'pressure', invalid: true)
        ..setFieldInvalid('altitude', 'altitude', invalid: true);

      controller.closeCard('altitude');
      await tester.pumpAndSettle();

      expect(controller.revealRequest!.fieldId, 'pressure');
      expect(tester.getRect(field()).top, greaterThan(300));
    });
  });
}
