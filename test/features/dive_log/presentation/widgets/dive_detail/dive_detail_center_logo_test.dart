import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_avatar.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_details_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

/// The dive center row on a dive's detail page shows the center's logo
/// (#4460), and only when it has one.
void main() {
  Uint8List jpeg() {
    final image = img.Image(width: 32, height: 32);
    img.fill(image, color: img.ColorRgb8(0, 90, 160));
    return Uint8List.fromList(img.encodeJpg(image, quality: 80));
  }

  DiveCenter center({Uint8List? logo}) => DiveCenter(
    id: 'c1',
    name: 'Toucan Diving',
    logo: logo,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> pumpSection(WidgetTester tester, Dive dive) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          computersForDiveProvider(dive.id).overrideWith((ref) async => []),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: DiveDetailsSection(dive: dive)),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('the dive center row shows its logo', (tester) async {
    final logo = jpeg();
    await pumpSection(
      tester,
      createTestDiveWithBottomTime().copyWith(diveCenter: center(logo: logo)),
    );

    expect(find.text('Toucan Diving'), findsOneWidget);
    final avatar = tester.widget<DiveCenterAvatar>(
      find.byType(DiveCenterAvatar),
    );
    expect(identical(avatar.logo, logo), isTrue);
  });

  testWidgets('no logo, no leading avatar', (tester) async {
    await pumpSection(
      tester,
      createTestDiveWithBottomTime().copyWith(diveCenter: center()),
    );

    expect(find.text('Toucan Diving'), findsOneWidget);
    expect(find.byType(DiveCenterAvatar), findsNothing);
  });
}
