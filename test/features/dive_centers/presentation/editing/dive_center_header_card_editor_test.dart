import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/editing/dive_center_edit_fields.dart';
import 'package:submersion/features/dive_centers/presentation/editing/dive_center_header_card_editor.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_avatar.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_logo_field.dart';
import 'package:submersion/l10n/arb/app_localizations_de.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

DiveCenter _center({Uint8List? logo, bool closed = false}) => DiveCenter(
  id: 'dc1',
  name: 'Reef Divers',
  logo: logo,
  isPermanentlyClosed: closed,
  createdAt: DateTime(2020),
  updatedAt: DateTime(2020),
);

/// The header editor of [center] in a sitting, in [locale].
Future<EditSession<DiveCenter>> _pumpEditor(
  WidgetTester tester,
  DiveCenter center, {
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(700, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final session = EditSession(center);
  addTearDown(session.dispose);
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    testApp(
      overrides: overrides,
      locale: locale,
      child: Scaffold(
        body: SingleChildScrollView(
          child: DiveCenterHeaderCardEditor(session: session),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return session;
}

/// The dive centre header block's editor (issue #4527, phase 3).
void main() {
  final l = AppLocalizationsEn();
  final logo = Uint8List.fromList(
    img.encodeJpg(img.Image(width: 4, height: 4), quality: 80),
  );

  testWidgets('the rating stars are named in the diver\'s language', (
    tester,
  ) async {
    await _pumpEditor(tester, _center(), locale: const Locale('de'));

    final de = AppLocalizationsDe();
    expect(find.byTooltip(de.diveSites_edit_rating_starTooltip(1)), findsOne);
    expect(find.byTooltip(de.diveSites_edit_rating_starTooltip(3)), findsOne);
    expect(find.byTooltip('3 stars'), findsNothing);
  });

  testWidgets('a stored logo shows in the editor', (tester) async {
    await _pumpEditor(tester, _center(logo: logo));

    final avatar = tester.widget<DiveCenterAvatar>(
      find.descendant(
        of: find.byType(DiveCenterLogoField),
        matching: find.byType(DiveCenterAvatar),
      ),
    );
    expect(avatar.logo, logo);
  });

  testWidgets('with no logo the editor shows the store icon', (tester) async {
    await _pumpEditor(tester, _center());

    expect(
      find.descendant(
        of: find.byType(DiveCenterLogoField),
        matching: find.byIcon(Icons.store),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Remove Photo clears the logo in the sitting, with no contacts '
      'offered', (tester) async {
    final session = await _pumpEditor(tester, _center(logo: logo));

    await tester.tap(find.bySemanticsLabel(l.diveCenters_field_logo));
    await tester.pumpAndSettle();
    // A shop is not in the address book.
    expect(find.text(l.profilePhoto_source_contacts), findsNothing);
    await tester.tap(find.text(l.profilePhoto_action_remove));
    await tester.pumpAndSettle();

    expect(session.valueOf(diveCenterLogoField), isNull);
    expect(session.changedCardIds, {'header'});
  });

  testWidgets('a closed centre opens with the switch on and its hint', (
    tester,
  ) async {
    await _pumpEditor(tester, _center(closed: true));

    final closed = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('dive-center-edit-closed')),
    );
    expect(closed.value, isTrue);
    expect(find.text(l.diveCenters_hint_permanentlyClosed), findsOneWidget);
  });
}
