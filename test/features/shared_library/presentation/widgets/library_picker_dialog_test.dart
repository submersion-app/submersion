import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_picker_dialog.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

/// Two libraries the profile belongs to, with [roles] in both. Nothing in
/// the page listens to the library providers, as on the site list.
Future<String?> _pick(
  WidgetTester tester, {
  required SharedLibraryRoles roles,
  bool dismiss = false,
}) async {
  final store = SharedLibraryStore();
  await tester.runAsync(() async {
    await DiverRepository().createDiver(
      Diver(
        id: 'd',
        name: 'Ann',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    for (final id in ['A', 'B']) {
      await store.upsertLibrary(
        SharedLibrary(
          id: id,
          name: 'Library $id',
          connectedAccountId: 'x',
          prefix: id,
          roles: roles,
        ),
      );
      await store.upsertMembership(
        SharedLibraryMembership(
          id: 'ms-$id',
          diverId: 'd',
          libraryId: id,
          memberId: 'm',
          displayName: 'Ann',
          libraryName: 'Library $id',
          backendKind: 's3',
        ),
      );
    }
  });
  String? picked = 'unset';
  await tester.pumpWidget(
    testApp(
      overrides: [
        ...await getBaseOverrides(),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd'),
      ],
      locale: const Locale('en'),
      child: Consumer(
        builder: (context, ref, _) => TextButton(
          onPressed: () async =>
              picked = await showLibraryPickerDialog(context, ref),
          child: const Text('pick'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('pick'));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pumpAndSettle();
  if (dismiss) {
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
  }
  return picked;
}

void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  testWidgets('cancelling the choice says nothing', (tester) async {
    final picked = await _pick(
      tester,
      roles: const SharedLibraryRoles(editors: {'m'}),
      dismiss: true,
    );
    expect(picked, isNull);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('with no library to add to, it says so', (tester) async {
    final picked = await _pick(tester, roles: SharedLibraryRoles.empty);
    expect(picked, isNull);
    expect(
      find.text('No shared site library here lets you add sites.'),
      findsOneWidget,
    );
  });

  testWidgets('adding asks first, and a cancel adds nothing', (tester) async {
    final store = SharedLibraryStore();
    await tester.runAsync(() async {
      await DiverRepository().createDiver(
        Diver(
          id: 'd',
          name: 'Ann',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      await store.upsertLibrary(
        const SharedLibrary(
          id: 'A',
          name: 'Library A',
          connectedAccountId: 'x',
          prefix: 'A',
          roles: SharedLibraryRoles(editors: {'m'}),
        ),
      );
      await store.upsertMembership(
        const SharedLibraryMembership(
          id: 'ms-A',
          diverId: 'd',
          libraryId: 'A',
          memberId: 'm',
          displayName: 'Ann',
          libraryName: 'Library A',
          backendKind: 's3',
        ),
      );
    });
    SharedLibrary? picked;
    var done = false;
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...await getBaseOverrides(),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd'),
        ],
        locale: const Locale('en'),
        child: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () async {
              picked = await pickLibraryToAddTo(
                context,
                ref,
                siteCount: 1,
                siteName: 'Blue',
              );
              done = true;
            },
            child: const Text('pick'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('pick'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Add Blue to Library A?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(done, isTrue);
    expect(picked, isNull);
  });
}
