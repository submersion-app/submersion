import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_mirror_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_buddies_section.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

final _now = DateTime(2024, 1, 1);

final _testRoles = [
  for (final (i, id) in DiveRole.builtInIds.indexed)
    DiveRole(
      id: id,
      name: id,
      isBuiltIn: true,
      sortOrder: i,
      createdAt: _now,
      updatedAt: _now,
    ),
];

Uint8List _jpeg() {
  final image = img.Image(width: 32, height: 32);
  img.fill(image, color: img.ColorRgb8(10, 20, 30));
  return Uint8List.fromList(img.encodeJpg(image, quality: 80));
}

Diver _diver(String id, String name, {Uint8List? photo}) =>
    Diver(id: id, name: name, photo: photo, createdAt: _now, updatedAt: _now);

Dive _dive({String? diverId}) => Dive(
  id: 'dive-1',
  diverId: diverId,
  dateTime: _now,
  diverRoleIds: const [DiveRole.rearGuardId],
);

Widget _buildSection({
  required Dive dive,
  Map<String, Diver> diversById = const {},
  Diver? currentDiver,
  bool ownerNeverLoads = false,
}) {
  return ProviderScope(
    overrides: [
      buddiesForDiveProvider(
        dive.id,
      ).overrideWith((ref) async => const <BuddyWithRole>[]),
      allDiveRolesProvider.overrideWith((ref) async => _testRoles),
      siblingDivesProvider(dive.id).overrideWith((ref) async => const []),
      diverByIdProvider.overrideWith(
        (ref, id) => ownerNeverLoads
            ? Completer<Diver?>().future
            : Future.value(diversById[id]),
      ),
      currentDiverProvider.overrideWith((ref) async => currentDiver),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(child: DiveBuddiesSection(dive: dive)),
      ),
    ),
  );
}

void main() {
  group('own role tile (#4458)', () {
    testWidgets("shows the dive owner's photo and name", (tester) async {
      final photo = _jpeg();
      await tester.pumpWidget(
        _buildSection(
          dive: _dive(diverId: 'diver-1'),
          diversById: {'diver-1': _diver('diver-1', 'Eric G', photo: photo)},
        ),
      );
      await tester.pumpAndSettle();

      final avatar = tester.widget<ProfileAvatar>(find.byType(ProfileAvatar));
      expect(avatar.photo, same(photo));
      expect(find.text('Eric G'), findsOneWidget);
      expect(find.text('Rear Guard'), findsOneWidget);
      expect(find.text('Me'), findsNothing);
    });

    testWidgets('keeps the person icon when the owner has no photo', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSection(
          dive: _dive(diverId: 'diver-1'),
          diversById: {'diver-1': _diver('diver-1', 'Eric G')},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.byType(ProfileAvatar), findsNothing);
      expect(find.text('Eric G'), findsOneWidget);
    });

    testWidgets('uses the dive owner, not the active diver', (tester) async {
      final ownerPhoto = _jpeg();
      await tester.pumpWidget(
        _buildSection(
          dive: _dive(diverId: 'owner'),
          diversById: {'owner': _diver('owner', 'Owner', photo: ownerPhoto)},
          currentDiver: _diver('active', 'Active Diver', photo: _jpeg()),
        ),
      );
      await tester.pumpAndSettle();

      final avatar = tester.widget<ProfileAvatar>(find.byType(ProfileAvatar));
      expect(avatar.photo, same(ownerPhoto));
      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('Active Diver'), findsNothing);
    });

    testWidgets('falls back to the active diver for a dive with no owner', (
      tester,
    ) async {
      final photo = _jpeg();
      await tester.pumpWidget(
        _buildSection(
          dive: _dive(),
          currentDiver: _diver('active', 'Active Diver', photo: photo),
        ),
      );
      await tester.pumpAndSettle();

      final avatar = tester.widget<ProfileAvatar>(find.byType(ProfileAvatar));
      expect(avatar.photo, same(photo));
      expect(find.text('Active Diver'), findsOneWidget);
    });

    testWidgets('says Me with the person icon when no diver resolves', (
      tester,
    ) async {
      await tester.pumpWidget(_buildSection(dive: _dive(diverId: 'gone')));
      await tester.pumpAndSettle();

      expect(find.text('Me'), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.byType(ProfileAvatar), findsNothing);
    });

    testWidgets('says Me when the owner has a blank name', (tester) async {
      await tester.pumpWidget(
        _buildSection(
          dive: _dive(diverId: 'diver-1'),
          diversById: {'diver-1': _diver('diver-1', '  ')},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Me'), findsOneWidget);
    });

    testWidgets('waits for the owner instead of flashing Me', (tester) async {
      await tester.pumpWidget(
        _buildSection(dive: _dive(diverId: 'diver-1'), ownerNeverLoads: true),
      );
      // The spinner animates forever, so pump frames rather than settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Me'), findsNothing);
      expect(find.byIcon(Icons.person), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
