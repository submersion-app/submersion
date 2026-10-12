import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/site_picker_site_tile.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';

import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('the picker tile shows the library badge for a library site', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          sharedLibrariesProvider.overrideWith(
            (ref) => Stream.value(const [
              SharedLibrary(
                id: 'L',
                name: 'Club',
                connectedAccountId: 'a',
                prefix: 'p',
              ),
            ]),
          ),
        ],
        locale: const Locale('en'),
        child: Column(
          children: [
            SitePickerSiteTile(
              site: const DiveSite(id: 's', name: 'Blue', sharedLibraryId: 'L'),
              isSelected: false,
              isNearby: false,
              subtitle: null,
              onTap: () {},
            ),
            SitePickerSiteTile(
              site: const DiveSite(id: 'p', name: 'Mine'),
              isSelected: false,
              isNearby: false,
              subtitle: null,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.groups_outlined), findsOneWidget);
    expect(find.byIcon(Icons.location_on), findsOneWidget);
  });
}
