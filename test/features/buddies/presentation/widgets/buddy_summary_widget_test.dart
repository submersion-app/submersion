import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_summary_widget.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// Serves a fixed buddy list without touching a database.
class _StubBuddyListNotifier extends StateNotifier<AsyncValue<List<Buddy>>>
    implements BuddyListNotifier {
  _StubBuddyListNotifier(List<Buddy> buddies) : super(AsyncValue.data(buddies));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final _now = DateTime(2026, 1, 1);

Uint8List _jpeg() {
  final image = img.Image(width: 32, height: 32);
  img.fill(image, color: img.ColorRgb8(10, 20, 30));
  return Uint8List.fromList(img.encodeJpg(image, quality: 80));
}

Buddy _buddy({required String id, required String name, Uint8List? photo}) =>
    Buddy(id: id, name: name, photo: photo, createdAt: _now, updatedAt: _now);

Future<Widget> _widget(List<Buddy> buddies) async => testApp(
  locale: const Locale('en'),
  overrides: [
    ...await getBaseOverrides(),
    buddyListNotifierProvider.overrideWith(
      (ref) => _StubBuddyListNotifier(buddies),
    ),
  ],
  child: const BuddySummaryWidget(),
);

void main() {
  testWidgets('a buddy with a stored photo renders it in the preview list', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _widget([_buddy(id: 'b1', name: 'Jane Doe', photo: _jpeg())]),
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
      await _widget([_buddy(id: 'b1', name: 'Jane Doe')]),
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
}
