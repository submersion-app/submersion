import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/editing/dive_center_header_card_editor.dart';
import 'package:submersion/l10n/arb/app_localizations_de.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// The dive centre header block's editor (issue #4527, phase 3).
void main() {
  testWidgets('the rating stars are named in the diver\'s language', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(700, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = EditSession(
      DiveCenter(
        id: 'dc1',
        name: 'Reef Divers',
        createdAt: DateTime(2020),
        updatedAt: DateTime(2020),
      ),
    );
    addTearDown(session.dispose);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        locale: const Locale('de'),
        child: Scaffold(
          body: SingleChildScrollView(
            child: DiveCenterHeaderCardEditor(session: session),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final de = AppLocalizationsDe();
    expect(find.byTooltip(de.diveSites_edit_rating_starTooltip(1)), findsOne);
    expect(find.byTooltip(de.diveSites_edit_rating_starTooltip(3)), findsOne);
    expect(find.byTooltip('3 stars'), findsNothing);
  });
}
