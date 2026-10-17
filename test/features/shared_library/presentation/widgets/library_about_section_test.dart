import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/shared_library/library_details_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/shared_library/presentation/providers/library_connection_providers.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_about_section.dart';

import '../../../../helpers/test_app.dart';

class _FakeDetails implements LibraryDetailsService {
  final calls = <({String name, String? description, String diverId})>[];
  Object? failWith;

  @override
  Future<void> save({
    required String libraryId,
    required String diverId,
    required String name,
    String? description,
  }) async {
    if (failWith != null) throw failWith!;
    calls.add((name: name, description: description, diverId: diverId));
  }
}

const _library = SharedLibrary(
  id: 'L',
  name: 'Reef Survey',
  connectedAccountId: 'a',
  prefix: 'site-sync',
  description: 'Group sites around the sound',
);

const _membership = SharedLibraryMembership(
  id: 'ms',
  diverId: 'd',
  libraryId: 'L',
  memberId: 'm',
  displayName: 'Ann',
  libraryName: 'Reef Survey',
  backendKind: 's3',
);

Widget _app(
  _FakeDetails details,
  SharedLibraryRole role, {
  SharedLibrary library = _library,
}) => testApp(
  overrides: [libraryDetailsServiceProvider.overrideWithValue(details)],
  locale: const Locale('en'),
  child: LibraryAboutSection(
    library: library,
    role: role,
    membership: _membership,
  ),
);

void main() {
  testWidgets('an owner edits the name and description', (tester) async {
    final details = _FakeDetails();
    await tester.pumpWidget(_app(details, SharedLibraryRole.owner));
    await tester.pumpAndSettle();
    expect(find.text('About'), findsOneWidget);
    expect(find.text('Group sites around the sound'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    expect(find.text('Edit library details'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Library name'),
      '  Group Sites ',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Description'),
      'Our dives',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(details.calls.single.name, 'Group Sites');
    expect(details.calls.single.description, 'Our dives');
    expect(details.calls.single.diverId, 'd');
    expect(find.text('Edit library details'), findsNothing);
  });

  testWidgets('a reader reads the description but cannot edit', (tester) async {
    final details = _FakeDetails();
    await tester.pumpWidget(_app(details, SharedLibraryRole.reader));
    await tester.pumpAndSettle();
    expect(find.text('Group sites around the sound'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    expect(find.text('Edit library details'), findsNothing);
  });

  testWidgets('a reader sees nothing when there is no description', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _FakeDetails(),
        SharedLibraryRole.reader,
        library: _library.copyWith(clearDescription: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('About'), findsNothing);
  });

  testWidgets('a long description is clipped on the page', (tester) async {
    final long = 'Reef ' * 400;
    await tester.pumpWidget(
      _app(
        _FakeDetails(),
        SharedLibraryRole.reader,
        library: _library.copyWith(description: long),
      ),
    );
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(find.text(long));
    expect(text.maxLines, LibraryAboutSection.descriptionLines);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('an empty name blocks saving', (tester) async {
    final details = _FakeDetails();
    await tester.pumpWidget(_app(details, SharedLibraryRole.owner));
    await tester.pumpAndSettle();
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Library name'),
      '   ',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name'), findsOneWidget);
    expect(details.calls, isEmpty);
  });

  testWidgets('a refused save keeps the dialog and what was typed', (
    tester,
  ) async {
    final details = _FakeDetails()
      ..failWith = const CloudStorageException('offline');
    await tester.pumpWidget(_app(details, SharedLibraryRole.owner));
    await tester.pumpAndSettle();
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Description'),
      'A long description typed offline',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Edit library details'), findsOneWidget);
    expect(find.text('A long description typed offline'), findsOneWidget);
    expect(find.textContaining('offline'), findsWidgets);
    // Fixed, the same dialog saves.
    details.failWith = null;
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      details.calls.single.description,
      'A long description typed offline',
    );
    expect(find.text('Edit library details'), findsNothing);
  });
}
