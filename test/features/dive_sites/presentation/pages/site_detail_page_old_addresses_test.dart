import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_reader_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_pane_header.dart';

import '../../../../helpers/mock_providers.dart';
import 'site_detail_page_unlock_harness.dart';

/// The old site edit addresses (`/sites/<id>/edit`, `?suggest=1`) once the
/// form is gone (issue #4527, phase 2, plan 7): Review Focus 1 and 2 on a
/// phone, where the page opens unlocked, and on a wide window, where it
/// moves into the list pane in edit mode first.
void main() {
  final l = AppLocalizationsEn();
  const wide = Size(1400, 900);
  final librarySite = harnessSite.copyWith(
    diverId: 'other',
    sharedLibraryId: 'L',
  );

  /// The library's overrides, with [role] as the profile's role there.
  List<Override> library(SharedLibraryRole role) => [
    libraryRoleProvider('L').overrideWith((ref) async => role),
    libraryConnectedHereProvider('L').overrideWith((ref) async => true),
    siteLibraryStateProvider('s1').overrideWith((ref) async => null),
    libraryMemberNamesProvider('L').overrideWith((ref) async => const {}),
    currentMembershipProvider('L').overrideWith(
      (ref) async => const SharedLibraryMembership(
        id: 'm1',
        diverId: 'me',
        libraryId: 'L',
        memberId: 'mem1',
        displayName: 'Me',
        libraryName: 'Club',
        backendKind: 'folder',
      ),
    ),
  ];

  /// Whether the page's open sitting is a library reader's.
  bool readerSittingOpen(WidgetTester tester) => isReaderSitting(
    RecordEditScope.maybeOf<DiveSite>(
      tester.element(find.byType(RecordCardFrame<DiveSite>).first),
    )!.session,
  );

  // Review Focus 2 on a phone: the sitting the role allows.
  for (final (role, reader) in const [
    (SharedLibraryRole.reader, true),
    (SharedLibraryRole.editor, false),
  ]) {
    testWidgets('?suggest=1 opens the sitting a ${role.name} may have', (
      tester,
    ) async {
      await pumpSitePage(
        tester,
        site: librarySite,
        initialLocation: '/sites/s1/edit?suggest=1',
        extra: library(role),
      );

      expect(find.byType(RecordEditBar), findsOneWidget);
      expect(readerSittingOpen(tester), reader);
    });
  }

  testWidgets('on a wide window the old address moves into the list pane '
      'in edit mode', (tester) async {
    final page = await pumpSitePage(
      tester,
      size: wide,
      initialLocation: '/sites/s1/edit?suggest=1',
    );
    await tester.pumpAndSettle();

    final uri = page.router!.routerDelegate.currentConfiguration.uri;
    expect(uri.path, '/sites');
    expect(uri.queryParameters, {'selected': 's1', 'mode': 'edit'});
  });

  // Review Focus 1 in the pane: a deleted site's edit mode says not found,
  // locked, and throws nothing.
  testWidgets('the pane opened unlocked on a deleted site says not found, '
      'locked', (tester) async {
    await pumpSitePage(
      tester,
      size: wide,
      embedded: true,
      initialLocation: '/sites/gone?mode=edit',
      extra: [siteProvider('gone').overrideWith((_) async => null)],
    );

    expect(find.text(l.diveSites_detail_siteNotFound_body), findsOneWidget);
    expect(find.byType(RecordEditPaneHeader), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // Review Focus 2 in the pane: a reader's edit mode is a reader's sitting.
  testWidgets("a reader's pane opened unlocked holds a reader's sitting", (
    tester,
  ) async {
    await pumpSitePage(
      tester,
      site: librarySite,
      size: wide,
      embedded: true,
      openUnlocked: true,
      extra: library(SharedLibraryRole.reader),
    );

    expect(find.byType(RecordEditPaneHeader), findsOneWidget);
    expect(readerSittingOpen(tester), isTrue);
  });
}
