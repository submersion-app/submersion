import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_site_badge.dart';

import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('shows the library name as tooltip for a library site only', (
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
        child: const Column(
          children: [
            LibrarySiteBadge(
              site: DiveSite(id: '1', name: 'a', sharedLibraryId: 'L'),
            ),
            LibrarySiteBadge(
              site: DiveSite(id: '2', name: 'b'),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.groups_outlined), findsOneWidget);
    expect(find.byTooltip('In Club'), findsOneWidget);
  });
}
