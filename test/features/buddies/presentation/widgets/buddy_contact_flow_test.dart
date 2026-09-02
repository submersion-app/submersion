import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_list_content.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';

class _StubBuddyListNotifier extends StateNotifier<AsyncValue<List<Buddy>>>
    implements BuddyListNotifier {
  _StubBuddyListNotifier() : super(const AsyncValue.data(<Buddy>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Uint8List _png() {
  final image = img.Image(width: 200, height: 200);
  img.fill(image, color: img.ColorRgb8(200, 30, 30));
  return Uint8List.fromList(img.encodePng(image));
}

Uint8List _jpeg() {
  final image = img.Image(width: 200, height: 200);
  img.fill(image, color: img.ColorRgb8(10, 120, 200));
  return Uint8List.fromList(img.encodeJpg(image, quality: 85));
}

Contact _contact({Uint8List? photo}) => Contact(
  id: 'c1',
  displayName: 'Jane Doe',
  emails: [const Email(address: 'jane@example.com')],
  phones: [const Phone(number: '+1 555 0100')],
  photo: photo == null ? null : Photo(fullSize: photo),
);

/// Hosts the list inside a router so the import's `context.push` resolves,
/// and records what the destination received.
Future<Map<String, dynamic>?> _runImport(
  WidgetTester tester,
  Future<Contact?> Function() picker,
) async {
  Map<String, dynamic>? received;

  final router = GoRouter(
    initialLocation: '/buddies',
    routes: [
      GoRoute(
        path: '/buddies',
        builder: (context, state) =>
            BuddyListContent(pickContactOverride: picker),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) {
              received = state.extra as Map<String, dynamic>?;
              return const Scaffold(body: Text('new buddy form'));
            },
          ),
        ],
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...await getBaseOverrides(),
        allBuddiesWithDiveCountProvider.overrideWith(
          (ref) => const <BuddyWithDiveCount>[],
        ),
        buddyListNotifierProvider.overrideWith(
          (ref) => _StubBuddyListNotifier(),
        ),
        buddyListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
        diveRoleMapProvider.overrideWith((ref) async => <String, DiveRole>{}),
      ],
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byIcon(Icons.more_vert));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Import from Contacts'));

  // runAsync: the photo encode runs on a real isolate via compute.
  for (var i = 0; i < 25; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  return received;
}

void main() {
  testWidgets('an imported contact carries name, email, phone and photo', (
    tester,
  ) async {
    final extra = await _runImport(
      tester,
      () async => _contact(photo: _jpeg()),
    );

    expect(extra, isNotNull);
    expect(extra!['name'], 'Jane Doe');
    expect(extra['email'], 'jane@example.com');
    expect(extra['phone'], '+1 555 0100');
    expect(
      extra['photo'],
      isA<Uint8List>(),
      reason: 'the contact photo should be encoded and carried through',
    );
  });

  testWidgets('the push happens on every layout, including master-detail', (
    tester,
  ) async {
    // Regression guard: the old master-detail branch ran context.go with no
    // data, so an iPad in landscape landed on a blank form. 1400 logical px is
    // comfortably above the 1100pt master-detail breakpoint.
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final extra = await _runImport(tester, () async => _contact());

    expect(extra, isNotNull);
    expect(extra!['name'], 'Jane Doe');
  });

  testWidgets('a contact with no photo still imports its other fields', (
    tester,
  ) async {
    final extra = await _runImport(tester, () async => _contact());

    expect(extra!['photo'], isNull);
    expect(extra['name'], 'Jane Doe');
  });

  testWidgets('cancelling the picker navigates nowhere', (tester) async {
    final extra = await _runImport(tester, () async => null);

    expect(extra, isNull);
    expect(find.text('new buddy form'), findsNothing);
  });

  testWidgets('a PNG contact photo survives the import', (tester) async {
    // The address book gives no filename and does not guarantee JPEG. When
    // this path claimed '.jpg', decodeNamedImage handed PNG bytes to the JPEG
    // decoder and a perfectly valid photo was dropped as undecodable.
    final extra = await _runImport(tester, () async => _contact(photo: _png()));

    expect(extra, isNotNull);
    expect(
      extra!['photo'],
      isA<Uint8List>(),
      reason: 'a PNG contact photo must not be discarded as undecodable',
    );
  });
}
