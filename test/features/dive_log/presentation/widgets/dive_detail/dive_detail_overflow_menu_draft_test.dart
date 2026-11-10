import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_computer/presentation/providers/reparse_providers.dart';
import 'package:submersion/features/dive_import/presentation/providers/dive_resync_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_mirror_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_overflow_menu.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_app.dart';

/// "Mark as complete" on a draft's menu (issue #637): only once it is out
/// of the water.
void main() {
  Future<void> pumpMenu(WidgetTester tester, Dive dive) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...await getBaseOverrides(),
          diveHasRawDataProvider(dive.id).overrideWith((ref) async => false),
          diveHasImportedFileProvider(
            dive.id,
          ).overrideWith((ref) async => false),
          preDiveSessionForDiveProvider(
            dive.id,
          ).overrideWith((ref) async => null),
          mirrorCandidatesProvider(dive.id).overrideWith((ref) async => []),
        ],
        child: DiveDetailOverflowMenu(
          dive: dive,
          embedded: false,
          menuKey: GlobalKey(),
          displayOptions: MenuController(),
          onSelected: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
  }

  final entry = DateTime.utc(2026, 7, 17, 10);
  Dive draft({DateTime? exit}) => Dive(
    id: 'draft',
    dateTime: entry,
    entryTime: entry,
    exitTime: exit,
    isDraft: true,
  );

  testWidgets('offered once the draft is out of the water', (tester) async {
    await pumpMenu(tester, draft(exit: entry.add(const Duration(minutes: 50))));

    expect(find.text('Mark as complete'), findsOneWidget);
  });

  testWidgets('not offered while the draft is in the water', (tester) async {
    await pumpMenu(tester, draft());

    expect(find.text('Mark as complete'), findsNothing);
  });
}
