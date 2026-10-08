import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_summary_widget.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

final _now = DateTime(2026, 1, 1);

Uint8List _jpeg() {
  final image = img.Image(width: 32, height: 32);
  img.fill(image, color: img.ColorRgb8(10, 20, 30));
  return Uint8List.fromList(img.encodeJpg(image, quality: 80));
}

Buddy _buddy({required String id, required String name, Uint8List? photo}) =>
    Buddy(id: id, name: name, photo: photo, createdAt: _now, updatedAt: _now);

BuddyWithDiveCount _entry(
  Buddy buddy, {
  int diveCount = 0,
  DateTime? lastDiveAt,
}) => BuddyWithDiveCount(
  buddy: buddy,
  diveCount: diveCount,
  lastDiveAt: lastDiveAt,
);

Future<Widget> _widget(List<BuddyWithDiveCount> entries) async => testApp(
  locale: const Locale('en'),
  overrides: [
    ...await getBaseOverrides(),
    allBuddiesWithDiveCountProvider.overrideWith((ref) => entries),
  ],
  child: const BuddySummaryWidget(),
);

void main() {
  // The trailing date in "Recent Buddies" is formatted by intl, which
  // resolves against Intl.defaultLocale: a process global that a preceding
  // test can leave on a non-English locale. Pin it so the asserted month
  // spelling ("Mar 15, 2026") is deterministic regardless of run order.
  late String? previousLocale;

  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });

  tearDown(() => Intl.defaultLocale = previousLocale);

  testWidgets('a buddy with a stored photo renders it in the preview list', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _widget([
        _entry(
          _buddy(id: 'b1', name: 'Jane Doe', photo: _jpeg()),
          lastDiveAt: _now,
        ),
      ]),
    );
    await tester.pump();

    final avatar = tester.widget<ProfileAvatar>(find.byType(ProfileAvatar));
    expect(avatar.photo, isNotNull);

    // Decoded at draw size rather than the stored 512px, so a long preview
    // list cannot balloon the image cache.
    final circle = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(circle.backgroundImage, isA<ResizeImage>());
    expect(find.text('JD'), findsNothing);
  });

  testWidgets('a buddy without a photo falls back to initials', (tester) async {
    await tester.pumpWidget(
      await _widget([
        _entry(
          _buddy(id: 'b1', name: 'Jane Doe'),
          lastDiveAt: _now,
        ),
      ]),
    );
    await tester.pump();

    final avatar = tester.widget<ProfileAvatar>(find.byType(ProfileAvatar));
    expect(avatar.photo, isNull);
    expect(find.text('JD'), findsOneWidget);
  });

  testWidgets('an empty buddy list renders without an avatar', (tester) async {
    await tester.pumpWidget(await _widget(const []));
    await tester.pump();

    expect(find.byType(ProfileAvatar), findsNothing);
  });

  testWidgets('a certified buddy shows the certification line as subtitle', (
    tester,
  ) async {
    final certified = Buddy(
      id: 'b1',
      name: 'Jane Doe',
      certificationLevel: CertificationLevel.rescue.name,
      certificationAgency: CertificationAgency.padi.name,
      certificationTitle: 'Rescue Diver',
      createdAt: _now,
      updatedAt: _now,
    );

    await tester.pumpWidget(
      await _widget([_entry(certified, lastDiveAt: _now)]),
    );
    await tester.pump();

    expect(find.text('Rescue Diver · PADI'), findsOneWidget);
  });

  group('Recent Buddies', () {
    testWidgets('sorts by last dive date, not alphabetically', (tester) async {
      final alice = _entry(
        _buddy(id: 'b1', name: 'Alice'),
        lastDiveAt: DateTime(2026, 1, 1),
      );
      final zoe = _entry(
        _buddy(id: 'b2', name: 'Zoe'),
        lastDiveAt: DateTime(2026, 3, 1),
      );

      await tester.pumpWidget(await _widget([alice, zoe]));
      await tester.pump();

      final names = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((tile) => (tile.title as Text).data)
          .toList();
      expect(names, ['Zoe', 'Alice']);
    });

    testWidgets('excludes buddies who were never dived with', (tester) async {
      final neverDived = _entry(_buddy(id: 'b1', name: 'Never Dived'));
      final dived = _entry(
        _buddy(id: 'b2', name: 'Dived'),
        lastDiveAt: _now,
      );

      await tester.pumpWidget(await _widget([neverDived, dived]));
      await tester.pump();

      expect(find.text('Dived'), findsOneWidget);
      expect(find.text('Never Dived'), findsNothing);
    });

    testWidgets('shows at most five buddies', (tester) async {
      final entries = List.generate(
        6,
        (i) => _entry(
          _buddy(id: 'b$i', name: 'Buddy $i'),
          lastDiveAt: DateTime(2026, 1, i + 1),
        ),
      );

      await tester.pumpWidget(await _widget(entries));
      await tester.pump();

      // Six entries total; the "Most Dives" card renders zero rows since
      // diveCount is 0 for all of them, so every visible tile belongs to
      // "Recent Buddies", capped at five.
      expect(find.byType(ListTile), findsNWidgets(5));
      expect(find.text('Buddy 0'), findsNothing);
    });

    testWidgets('hides the card entirely when nobody has a recorded dive', (
      tester,
    ) async {
      await tester.pumpWidget(
        await _widget([_entry(_buddy(id: 'b1', name: 'Alice'))]),
      );
      await tester.pump();

      expect(find.text('Recent Buddies'), findsNothing);
    });

    testWidgets('shows a formatted last-dive date as trailing info', (
      tester,
    ) async {
      await tester.pumpWidget(
        await _widget([
          _entry(
            _buddy(id: 'b1', name: 'Alice'),
            lastDiveAt: DateTime(2026, 3, 15),
          ),
        ]),
      );
      await tester.pump();

      expect(find.text('Mar 15, 2026'), findsOneWidget);
    });
  });

  group('Most Dives', () {
    testWidgets('sorts by dive count, not alphabetically', (tester) async {
      final alice = _entry(_buddy(id: 'b1', name: 'Alice'), diveCount: 2);
      final zoe = _entry(_buddy(id: 'b2', name: 'Zoe'), diveCount: 10);

      await tester.pumpWidget(await _widget([alice, zoe]));
      await tester.pump();

      expect(find.text('Most Dives'), findsOneWidget);
      final names = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((tile) => (tile.title as Text).data)
          .toList();
      expect(names, ['Zoe', 'Alice']);
    });

    testWidgets('excludes buddies with zero recorded dives', (tester) async {
      final never = _entry(_buddy(id: 'b1', name: 'Never'), diveCount: 0);
      final some = _entry(_buddy(id: 'b2', name: 'Some'), diveCount: 3);

      await tester.pumpWidget(await _widget([never, some]));
      await tester.pump();

      expect(find.text('Some'), findsOneWidget);
      expect(find.text('Never'), findsNothing);
    });

    testWidgets('hides the card entirely when nobody has a recorded dive', (
      tester,
    ) async {
      await tester.pumpWidget(
        await _widget([_entry(_buddy(id: 'b1', name: 'Alice'))]),
      );
      await tester.pump();

      expect(find.text('Most Dives'), findsNothing);
    });

    testWidgets('shows the dive count as trailing info', (tester) async {
      await tester.pumpWidget(
        await _widget([_entry(_buddy(id: 'b1', name: 'Alice'), diveCount: 3)]),
      );
      await tester.pump();

      expect(find.text('3 dives'), findsOneWidget);
    });
  });
}
