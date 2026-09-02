import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/features/buddies/presentation/pages/buddy_edit_page.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

Uint8List _jpeg() {
  final image = img.Image(width: 64, height: 64);
  img.fill(image, color: img.ColorRgb8(10, 20, 30));
  return Uint8List.fromList(img.encodeJpg(image, quality: 80));
}

/// Builds the same two-route shape the real app uses for contact import: a
/// list that pushes `/buddies/new` with the imported fields as `extra`.
GoRouter _router(Map<String, dynamic> extra) {
  return GoRouter(
    initialLocation: '/buddies',
    routes: [
      GoRoute(
        path: '/buddies',
        builder: (context, state) => ElevatedButton(
          onPressed: () => context.push('/buddies/new', extra: extra),
          child: const Text('import'),
        ),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) {
              final e = state.extra as Map<String, dynamic>?;
              return BuddyEditPage(
                initialName: e?['name'] as String?,
                initialEmail: e?['email'] as String?,
                initialPhone: e?['phone'] as String?,
                initialPhoto: e?['photo'] as Uint8List?,
              );
            },
          ),
        ],
      ),
    ],
  );
}

void main() {
  testWidgets('the new-buddy route carries the imported name through extra', (
    tester,
  ) async {
    await tester.pumpWidget(
      testAppRouter(
        overrides: await getBaseOverrides(),
        locale: const Locale('en'),
        router: _router({
          'name': 'Jane Doe',
          'email': 'jane@example.com',
          'phone': '+1 555 0100',
          'photo': null,
        }),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('import'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.widgetWithText(TextFormField, 'Jane Doe'), findsOneWidget);
  });

  testWidgets('an imported contact photo reaches the edit form', (
    tester,
  ) async {
    await tester.pumpWidget(
      testAppRouter(
        overrides: await getBaseOverrides(),
        locale: const Locale('en'),
        router: _router({
          'name': 'Jane Doe',
          'email': null,
          'phone': null,
          'photo': _jpeg(),
        }),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('import'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final avatar = tester.widget<ProfileAvatar>(find.byType(ProfileAvatar));
    expect(
      avatar.photo,
      isNotNull,
      reason: 'the photo picked from Contacts must survive the route hop',
    );
  });

  testWidgets('a contact with no photo still imports its name', (tester) async {
    await tester.pumpWidget(
      testAppRouter(
        overrides: await getBaseOverrides(),
        locale: const Locale('en'),
        router: _router({
          'name': 'Jane Doe',
          'email': null,
          'phone': null,
          'photo': null,
        }),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('import'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final avatar = tester.widget<ProfileAvatar>(find.byType(ProfileAvatar));
    expect(avatar.photo, isNull);
    expect(find.text('JD'), findsOneWidget);
  });
}
