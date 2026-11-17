import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_edit_page.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_avatar.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

Uint8List _jpeg() {
  final image = img.Image(width: 32, height: 32);
  img.fill(image, color: img.ColorRgb8(0, 90, 160));
  return Uint8List.fromList(img.encodeJpg(image, quality: 80));
}

/// The logo on the dive center edit page (#4460).
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  Future<DiveCenter> seed({Uint8List? logo}) {
    final now = DateTime(2026);
    return DiveCenterRepository().createDiveCenter(
      DiveCenter(
        id: '',
        name: 'Toucan Diving',
        logo: logo,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> pumpPage(WidgetTester tester, String centerId) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiveCenterEditPage(
              centerId: centerId,
              embedded: true,
              onSaved: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
  }

  testWidgets('an existing logo is shown and saved unchanged', (tester) async {
    final logo = _jpeg();
    final center = await seed(logo: logo);
    await pumpPage(tester, center.id);

    final avatar = tester.widget<DiveCenterAvatar>(
      find.byType(DiveCenterAvatar),
    );
    expect(avatar.logo, logo);
    await save(tester);

    final saved = await DiveCenterRepository().getDiveCenterById(center.id);
    expect(saved!.logo, logo);
  });

  testWidgets('tapping the logo offers Remove, and remove clears it on save', (
    tester,
  ) async {
    final center = await seed(logo: _jpeg());
    await pumpPage(tester, center.id);

    await tester.tap(find.bySemanticsLabel('Logo'));
    await tester.pumpAndSettle();
    expect(find.text('Choose from Contacts'), findsNothing);
    await tester.tap(find.text('Remove Photo'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<DiveCenterAvatar>(find.byType(DiveCenterAvatar)).logo,
      isNull,
    );
    await save(tester);

    final saved = await DiveCenterRepository().getDiveCenterById(center.id);
    expect(saved!.logo, isNull);
    expect(saved.name, 'Toucan Diving');
  });

  testWidgets('a center with no logo shows the store icon', (tester) async {
    final center = await seed();
    await pumpPage(tester, center.id);

    expect(find.byIcon(Icons.store), findsOneWidget);
  });
}
