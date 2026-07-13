import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/geofence_editor_sheet.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('save is disabled until a center is chosen', (tester) async {
    final overrides = await getBaseOverrides();
    overrides.add(sitesProvider.overrideWith((ref) async => <DiveSite>[]));

    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showGeofenceEditor(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save geofence'),
    );
    expect(saveButton.onPressed, isNull, reason: 'disabled without a center');
  });
}
