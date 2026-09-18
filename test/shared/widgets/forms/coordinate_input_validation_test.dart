import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/coordinates/coordinate_format.dart';
import 'package:submersion/shared/widgets/forms/coordinate_input.dart';
import 'package:submersion/shared/widgets/forms/coordinate_validation_messages.dart';

/// Issue #2035: the coordinate error named the wrong axis and sat under the
/// wrong field. Each axis now carries its own message.
void main() {
  const messages = CoordinateValidationMessages(
    invalidLatitude: 'Invalid latitude',
    invalidLongitude: 'Invalid longitude',
    latitudeRequired: 'Latitude is required',
    longitudeRequired: 'Longitude is required',
    invalidCoordinates: 'Invalid coordinates',
  );

  late GlobalKey<FormState> formKey;
  late CoordinateInputValue? reported;

  setUp(() {
    formKey = GlobalKey<FormState>();
    reported = null;
  });

  Future<void> pumpInput(
    WidgetTester tester, {
    required CoordinateFormat format,
    double? latitude,
    double? longitude,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: CoordinateInput(
                format: format,
                latitude: latitude,
                longitude: longitude,
                onChanged: (value) => reported = value,
                messages: messages,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Finder fieldAt(int index) => find.byType(TextFormField).at(index);

  Finder errorUnder(Finder field, String message) =>
      find.descendant(of: field, matching: find.text(message));

  group('decimal degrees', () {
    testWidgets('a blank group shows no error', (tester) async {
      await pumpInput(tester, format: CoordinateFormat.decimalDegrees);
      await tester.pump();

      expect(find.textContaining('Invalid'), findsNothing);
      expect(find.textContaining('required'), findsNothing);
      expect(formKey.currentState!.validate(), isTrue);
    });

    testWidgets('a missing longitude is reported on the longitude field', (
      tester,
    ) async {
      await pumpInput(tester, format: CoordinateFormat.decimalDegrees);

      await tester.enterText(fieldAt(0), '48.8566');
      await tester.pump();

      expect(errorUnder(fieldAt(1), 'Longitude is required'), findsOneWidget);
      expect(find.text('Invalid latitude'), findsNothing);
      expect(find.text('Latitude is required'), findsNothing);
      expect(formKey.currentState!.validate(), isFalse);
    });

    testWidgets('a missing latitude is reported on the latitude field', (
      tester,
    ) async {
      await pumpInput(tester, format: CoordinateFormat.decimalDegrees);

      await tester.enterText(fieldAt(1), '2.3522');
      await tester.pump();

      expect(errorUnder(fieldAt(0), 'Latitude is required'), findsOneWidget);
      expect(find.text('Longitude is required'), findsNothing);
    });

    testWidgets('an unreadable longitude is reported on the longitude field', (
      tester,
    ) async {
      await pumpInput(tester, format: CoordinateFormat.decimalDegrees);

      await tester.enterText(fieldAt(0), '48.8566');
      await tester.enterText(fieldAt(1), 'east');
      await tester.pump();

      expect(errorUnder(fieldAt(1), 'Invalid longitude'), findsOneWidget);
      expect(find.text('Invalid latitude'), findsNothing);
      expect(formKey.currentState!.validate(), isFalse);
    });

    testWidgets('an out-of-range latitude is reported on the latitude field', (
      tester,
    ) async {
      await pumpInput(tester, format: CoordinateFormat.decimalDegrees);

      await tester.enterText(fieldAt(0), '91');
      await tester.enterText(fieldAt(1), '2.3522');
      await tester.pump();

      expect(errorUnder(fieldAt(0), 'Invalid latitude'), findsOneWidget);
      expect(find.text('Invalid longitude'), findsNothing);
    });

    testWidgets('both axes wrong shows both messages', (tester) async {
      await pumpInput(tester, format: CoordinateFormat.decimalDegrees);

      await tester.enterText(fieldAt(0), 'abc');
      await tester.enterText(fieldAt(1), 'def');
      await tester.pump();

      expect(errorUnder(fieldAt(0), 'Invalid latitude'), findsOneWidget);
      expect(errorUnder(fieldAt(1), 'Invalid longitude'), findsOneWidget);
    });

    testWidgets('completing the pair clears the error', (tester) async {
      await pumpInput(tester, format: CoordinateFormat.decimalDegrees);

      await tester.enterText(fieldAt(0), '48.8566');
      await tester.pump();
      expect(find.text('Longitude is required'), findsOneWidget);

      await tester.enterText(fieldAt(1), '2.3522');
      await tester.pump();
      expect(find.text('Longitude is required'), findsNothing);
      expect(formKey.currentState!.validate(), isTrue);
    });

    testWidgets('a decimal comma is accepted', (tester) async {
      await pumpInput(tester, format: CoordinateFormat.decimalDegrees);

      await tester.enterText(fieldAt(0), '48,8566');
      await tester.enterText(fieldAt(1), '-4,5678');
      await tester.pump();

      expect(reported!.latitude, closeTo(48.8566, 1e-9));
      expect(reported!.longitude, closeTo(-4.5678, 1e-9));
      expect(find.textContaining('Invalid'), findsNothing);
      expect(formKey.currentState!.validate(), isTrue);
    });

    testWidgets('a decimal comma in one field is not read as a pasted pair', (
      tester,
    ) async {
      await pumpInput(
        tester,
        format: CoordinateFormat.decimalDegrees,
        latitude: 20.0,
        longitude: 10.0,
      );

      // '43,5' also reads as the pair (43, 5). Taking it that way would
      // silently overwrite the latitude the diver did not touch.
      await tester.enterText(fieldAt(1), '43,5');
      await tester.pump();

      expect(reported!.latitude, closeTo(20.0, 1e-9));
      expect(reported!.longitude, closeTo(43.5, 1e-9));
      expect(find.text('20.000000'), findsOneWidget);
    });

    testWidgets('a comma-separated UTM pair still pastes into one field', (
      tester,
    ) async {
      await pumpInput(tester, format: CoordinateFormat.decimalDegrees);

      await tester.enterText(fieldAt(0), '16Q 496898,2251535');
      await tester.pump();

      expect(reported!.latitude, closeTo(20.361944, 2e-5));
      expect(reported!.longitude, closeTo(-87.029722, 2e-5));
    });
  });

  group('degree layouts', () {
    testWidgets('a missing longitude is reported on the longitude row', (
      tester,
    ) async {
      await pumpInput(tester, format: CoordinateFormat.degreesMinutesSeconds);

      // Sub-fields: latDeg, latMin, latSec, lonDeg, lonMin, lonSec.
      await tester.enterText(fieldAt(0), '48');
      await tester.pump();

      expect(errorUnder(fieldAt(3), 'Longitude is required'), findsOneWidget);
      expect(find.text('Invalid latitude'), findsNothing);
      expect(find.text('Latitude is required'), findsNothing);
      expect(formKey.currentState!.validate(), isFalse);
    });

    testWidgets('impossible minutes are reported on the right axis', (
      tester,
    ) async {
      await pumpInput(tester, format: CoordinateFormat.degreesDecimalMinutes);

      // Sub-fields: latDeg, latMin, lonDeg, lonMin.
      await tester.enterText(fieldAt(0), '48');
      await tester.enterText(fieldAt(2), '2');
      await tester.enterText(fieldAt(3), '75');
      await tester.pump();

      expect(errorUnder(fieldAt(2), 'Invalid longitude'), findsOneWidget);
      expect(find.text('Invalid latitude'), findsNothing);
    });

    testWidgets('a decimal comma in the minutes is accepted', (tester) async {
      await pumpInput(tester, format: CoordinateFormat.degreesDecimalMinutes);

      await tester.enterText(fieldAt(0), '48');
      await tester.enterText(fieldAt(1), '30,5');
      await tester.enterText(fieldAt(2), '2');
      await tester.enterText(fieldAt(3), '15');
      await tester.pump();

      expect(reported!.latitude, closeTo(48 + 30.5 / 60, 1e-9));
      expect(reported!.longitude, closeTo(2.25, 1e-9));
      expect(find.textContaining('Invalid'), findsNothing);
    });

    testWidgets('a decimal comma in both minutes and seconds is accepted', (
      tester,
    ) async {
      await pumpInput(tester, format: CoordinateFormat.degreesMinutesSeconds);

      // Sub-fields: latDeg, latMin, latSec, lonDeg, lonMin, lonSec.
      await tester.enterText(fieldAt(0), '48');
      await tester.enterText(fieldAt(1), '30,5');
      await tester.enterText(fieldAt(2), '1,5');
      await tester.enterText(fieldAt(3), '2');
      await tester.pump();

      expect(reported!.latitude, closeTo(48 + 30.5 / 60 + 1.5 / 3600, 1e-9));
      expect(find.textContaining('Invalid'), findsNothing);
    });

    testWidgets('unreadable degrees are not dropped in favour of the minutes', (
      tester,
    ) async {
      await pumpInput(tester, format: CoordinateFormat.degreesDecimalMinutes);

      // Sub-fields: latDeg, latMin, lonDeg, lonMin. Composed naively, this
      // reads as 30 degrees, silently discarding what was typed.
      await tester.enterText(fieldAt(0), 'abc');
      await tester.enterText(fieldAt(1), '30');
      await tester.enterText(fieldAt(2), '2');
      await tester.pump();

      expect(reported!.latitude, isNull);
      expect(errorUnder(fieldAt(0), 'Invalid latitude'), findsOneWidget);
      expect(formKey.currentState!.validate(), isFalse);
    });

    testWidgets('unreadable minutes are not dropped', (tester) async {
      await pumpInput(tester, format: CoordinateFormat.degreesDecimalMinutes);

      await tester.enterText(fieldAt(0), '48');
      await tester.enterText(fieldAt(1), 'x');
      await tester.enterText(fieldAt(2), '2');
      await tester.pump();

      expect(reported!.latitude, isNull);
      expect(errorUnder(fieldAt(0), 'Invalid latitude'), findsOneWidget);
    });
  });

  group('grid layouts', () {
    testWidgets('an incomplete UTM entry names neither axis', (tester) async {
      await pumpInput(tester, format: CoordinateFormat.utm);

      await tester.enterText(fieldAt(0), '16Q');
      await tester.pump();

      expect(errorUnder(fieldAt(0), 'Invalid coordinates'), findsOneWidget);
      expect(find.text('Invalid latitude'), findsNothing);
      expect(find.text('Latitude is required'), findsNothing);
      expect(formKey.currentState!.validate(), isFalse);
    });

    testWidgets('an unreadable MGRS reference names neither axis', (
      tester,
    ) async {
      await pumpInput(tester, format: CoordinateFormat.mgrs);

      await tester.enterText(fieldAt(0), '16Q DH');
      await tester.pump();

      expect(errorUnder(fieldAt(0), 'Invalid coordinates'), findsOneWidget);
    });
  });
}
