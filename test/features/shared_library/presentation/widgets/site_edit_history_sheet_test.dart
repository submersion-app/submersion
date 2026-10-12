import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/features/shared_library/presentation/widgets/site_edit_history_sheet.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

const _site = DiveSite(id: 's', name: 'Blue Hole', sharedLibraryId: 'L');

FieldClock _clock(DateTime at, String member) => FieldClock(
  hlc: Hlc(at.millisecondsSinceEpoch, 0, member),
  memberId: member,
);

Future<Widget> _app({required Widget child, SharedSiteState? state}) async =>
    testApp(
      overrides: [
        ...await getBaseOverrides(),
        siteLibraryStateProvider('s').overrideWith((ref) async => state),
        libraryMemberNamesProvider(
          'L',
        ).overrideWith((ref) async => {'a': 'Ann', 'b': 'Bob'}),
      ],
      locale: const Locale('en'),
      child: child,
    );

void main() {
  testWidgets('lists every field, newest edit first, with the editor', (
    tester,
  ) async {
    final state = SharedSiteState(
      siteId: 's',
      libraryId: 'L',
      clocks: {
        'name': _clock(DateTime.utc(2026, 10, 1), 'a'),
        'hazards': _clock(DateTime.utc(2026, 10, 12), 'b'),
        'notes': _clock(DateTime.utc(2026, 10, 5), 'zz'),
      },
    );
    await tester.pumpWidget(
      await _app(
        child: const SiteEditHistorySheet(site: _site),
        state: state,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Blue Hole'), findsOneWidget);
    final hazards = tester.getTopLeft(find.text('Hazards'));
    final notes = tester.getTopLeft(find.text('Notes'));
    final name = tester.getTopLeft(find.text('Name'));
    expect(hazards.dy, lessThan(notes.dy));
    expect(notes.dy, lessThan(name.dy));
    expect(find.textContaining('Bob'), findsOneWidget);
    expect(find.textContaining('Ann'), findsOneWidget);
    // An unknown member falls back to its id.
    expect(find.textContaining('zz'), findsOneWidget);
  });

  testWidgets('a site without library state shows only the header', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _app(child: const SiteEditHistorySheet(site: _site)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Blue Hole'), findsOneWidget);
    expect(find.byType(ListTile), findsOneWidget);
  });

  testWidgets('showSiteEditHistorySheet opens the sheet', (tester) async {
    await tester.pumpWidget(
      await _app(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showSiteEditHistorySheet(context, site: _site),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(SiteEditHistorySheet), findsOneWidget);
    expect(find.text('Blue Hole'), findsOneWidget);
  });
}
