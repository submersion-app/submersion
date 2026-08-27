import 'dart:io';

import 'package:flutter/material.dart';
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
  String? photoPath,
  CertificationLevel? level = CertificationLevel.rescue,
  CertificationAgency? agency = CertificationAgency.padi,
}) {
  return Buddy(
    id: 'b1',
    name: name,
    email: email,
    phone: phone,
    photoPath: photoPath,
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

  testWidgets('loads an existing photo file and falls back to initials', (
    tester,
  ) async {
    // Real file I/O inside a testWidgets body runs under FakeAsync and never
    // completes; do it synchronously so the test does not deadlock.
    final dir = Directory.systemTemp.createTempSync('buddy-photo');
    addTearDown(() => dir.deleteSync(recursive: true));
    final photo = File('${dir.path}/jane.png');
    // A 1x1 transparent PNG.
    photo.writeAsBytesSync(const [
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x48,
      0x44,
      0x52,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x08,
      0x06,
      0x00,
      0x00,
      0x00,
      0x1F,
      0x15,
      0xC4,
      0x89,
      0x00,
      0x00,
      0x00,
      0x0A,
      0x49,
      0x44,
      0x41,
      0x54,
      0x78,
      0x9C,
      0x63,
      0x00,
      0x01,
      0x00,
      0x00,
      0x05,
      0x00,
      0x01,
      0x0D,
      0x0A,
      0x2D,
      0xB4,
      0x00,
      0x00,
      0x00,
      0x00,
      0x49,
      0x45,
      0x4E,
      0x44,
      0xAE,
      0x42,
      0x60,
      0x82,
    ]);

    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(),
        child: BuddyListTile(
          entry: BuddyWithDiveCount(
            buddy: _buddy(photoPath: photo.path),
            diveCount: 1,
          ),
          onTap: () {},
        ),
      ),
    );
    await tester.pump();

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundImage, isA<FileImage>());
    expect(find.text('JD'), findsNothing);

    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(),
        child: BuddyListTile(
          entry: BuddyWithDiveCount(
            buddy: _buddy(photoPath: '${dir.path}/missing.png'),
            diveCount: 1,
          ),
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
