import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/coordinates/coordinate_format.dart';
import 'package:submersion/shared/widgets/forms/coordinate_field_group.dart';

void main() {
  late TextEditingController latitude;
  late TextEditingController longitude;

  setUp(() {
    latitude = TextEditingController();
    longitude = TextEditingController();
  });

  tearDown(() {
    latitude.dispose();
    longitude.dispose();
  });

  Future<void> pump(
    WidgetTester tester, {
    CoordinateFormat format = CoordinateFormat.decimalDegrees,
    GlobalKey<FormState>? formKey,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: CoordinateFieldGroup(
              latitudeController: latitude,
              longitudeController: longitude,
              format: format,
              invalidMessage: 'Enter a valid coordinate',
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('an out-of-range edit does not clear the stored coordinate', (
    tester,
  ) async {
    latitude.text = '20.361944';
    longitude.text = '-87.029722';
    await pump(tester);

    await tester.enterText(find.byType(TextFormField).first, '91');
    await tester.pump();

    // A typo must never destroy a stored position. 91 is not a latitude, so
    // the controllers keep what they had rather than being emptied.
    expect(latitude.text, '20.361944');
    expect(longitude.text, '-87.029722');
  });

  testWidgets('an out-of-range edit blocks form validation', (tester) async {
    final formKey = GlobalKey<FormState>();
    latitude.text = '20.361944';
    longitude.text = '-87.029722';
    await pump(tester, formKey: formKey);

    expect(formKey.currentState!.validate(), isTrue);

    await tester.enterText(find.byType(TextFormField).first, '91');
    await tester.pump();

    // Saving must not silently keep the old value behind the diver's back.
    expect(formKey.currentState!.validate(), isFalse);
  });

  testWidgets('clearing every field does clear the coordinate', (tester) async {
    latitude.text = '20.361944';
    longitude.text = '-87.029722';
    await pump(tester);

    await tester.enterText(find.byType(TextFormField).first, '');
    await tester.enterText(find.byType(TextFormField).last, '');
    await tester.pump();

    // Blank is a deliberate removal, not a typo.
    expect(latitude.text, '');
    expect(longitude.text, '');
  });

  testWidgets('a valid edit writes decimal degrees through', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextFormField).first, '20.361944');
    await tester.enterText(find.byType(TextFormField).last, '-87.029722');
    await tester.pump();

    expect(latitude.text, '20.361944');
    expect(longitude.text, '-87.029722');
  });
}
