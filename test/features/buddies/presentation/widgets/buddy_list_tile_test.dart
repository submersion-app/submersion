import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/domain/constants/buddy_field.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_list_tile.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/shared/models/entity_card_view_config.dart';
import 'package:submersion/shared/providers/entity_card_config_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

const _config = EntityCardViewConfig<BuddyField>(
  slots: [
    EntityCardSlotConfig(slotId: 'title', field: BuddyField.buddyName),
    EntityCardSlotConfig(slotId: 'subtitle', field: BuddyField.email),
    EntityCardSlotConfig(slotId: 'stat1', field: BuddyField.diveCount),
    EntityCardSlotConfig(slotId: 'stat2', field: BuddyField.lastDive),
  ],
);

final _epoch = DateTime.fromMillisecondsSinceEpoch(0);

Future<List<dynamic>> _overrides({
  EntityCardViewConfig<BuddyField> config = _config,
}) async => [
  ...await getBaseOverrides(),
  buddyDetailedCardConfigProvider.overrideWith(
    (ref) => EntityCardConfigNotifier<BuddyField>(
      defaultConfig: config,
      fieldFromName: BuddyFieldAdapter.instance.fieldFromName,
    ),
  ),
  diveRoleMapProvider.overrideWith(
    (ref) async => {
      DiveRole.instructorId: DiveRole(
        id: DiveRole.instructorId,
        name: 'Instructor',
        isBuiltIn: true,
        createdAt: _epoch,
        updatedAt: _epoch,
      ),
    },
  ),
];

Buddy _buddy({
  String name = 'Jane Doe',
  String? email = 'jane@example.com',
  String? phone = '+1 555 0100',
  Uint8List? photo,
  CertificationLevel? level = CertificationLevel.rescue,
  CertificationAgency? agency = CertificationAgency.padi,
}) {
  return Buddy(
    id: 'b1',
    name: name,
    email: email,
    phone: phone,
    photo: photo,
    certificationLevel: level,
    certificationAgency: agency,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  testWidgets('renders slots, cert chip, usual role and contact icons', (
    tester,
  ) async {
    final entry = BuddyWithDiveCount(
      buddy: _buddy(),
      diveCount: 23,
      lastDiveAt: DateTime(2024, 3, 5),
      usualRoleId: DiveRole.instructorId,
    );
    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(),
        locale: const Locale('en'),
        child: BuddyListTile(entry: entry, onTap: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.text('jane@example.com'), findsOneWidget);
    expect(find.text('Rescue Diver · PADI'), findsOneWidget);
    expect(find.text('23 dives'), findsOneWidget);
    expect(find.text('Instructor'), findsOneWidget);
    expect(find.byIcon(Icons.mail_outline), findsOneWidget);
    expect(find.byIcon(Icons.phone_outlined), findsOneWidget);
    expect(find.text('JD'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('hides the usual role for the plain buddy role and empty bits', (
    tester,
  ) async {
    final entry = BuddyWithDiveCount(
      buddy: _buddy(email: null, phone: null, level: null, agency: null),
      diveCount: 0,
      usualRoleId: DiveRole.buddyId,
    );
    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(),
        locale: const Locale('en'),
        child: BuddyListTile(entry: entry, onTap: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.byIcon(Icons.badge_outlined), findsNothing);
    expect(find.byIcon(Icons.mail_outline), findsNothing);
    expect(find.byIcon(Icons.phone_outlined), findsNothing);
    expect(find.textContaining('·'), findsNothing);
    expect(find.textContaining('--'), findsNothing);
  });

  testWidgets('renders the stored photo and falls back to initials', (
    tester,
  ) async {
    final image = img.Image(width: 64, height: 64);
    img.fill(image, color: img.ColorRgb8(10, 20, 30));
    final bytes = Uint8List.fromList(img.encodeJpg(image, quality: 80));

    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(),
        child: BuddyListTile(
          entry: BuddyWithDiveCount(buddy: _buddy(photo: bytes), diveCount: 1),
          onTap: () {},
        ),
      ),
    );
    await tester.pump();

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundImage, isA<ResizeImage>());
    expect(find.text('JD'), findsNothing);

    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(),
        child: BuddyListTile(
          entry: BuddyWithDiveCount(buddy: _buddy(), diveCount: 1),
          onTap: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('JD'), findsOneWidget);
  });

  testWidgets('keeps the title readable on a narrow German phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const longName = 'Maximiliane Schwarzenberger-Hoffmann';
    final entry = BuddyWithDiveCount(
      buddy: _buddy(name: longName),
      diveCount: 123,
      lastDiveAt: DateTime(2024, 3, 5),
      usualRoleId: DiveRole.instructorId,
    );

    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(),
        locale: const Locale('de'),
        child: BuddyListTile(entry: entry, onTap: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.text(longName)).width, greaterThan(150));
  });

  testWidgets('shows a checkbox in selection mode', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(),
        child: BuddyListTile(
          entry: BuddyWithDiveCount(buddy: _buddy(), diveCount: 1),
          isSelectionMode: true,
          isChecked: true,
          onTap: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Checkbox), findsOneWidget);
  });
}
