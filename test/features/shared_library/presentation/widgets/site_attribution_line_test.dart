import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/features/shared_library/presentation/widgets/site_attribution_line.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

const _site = DiveSite(id: 's', name: 'S', sharedLibraryId: 'L');

FieldClock _clock(DateTime at, String member) => FieldClock(
  hlc: Hlc(at.millisecondsSinceEpoch, 0, member),
  memberId: member,
);

void main() {
  testWidgets('renders the newest clock with the member name', (tester) async {
    final state = SharedSiteState(
      siteId: 's',
      libraryId: 'L',
      clocks: {
        'name': _clock(DateTime.utc(2026, 10, 1), 'a'),
        'hazards': _clock(DateTime.utc(2026, 10, 12), 'b'),
      },
    );
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...await getBaseOverrides(),
          siteLibraryStateProvider('s').overrideWith((ref) async => state),
          libraryMemberNamesProvider(
            'L',
          ).overrideWith((ref) async => {'a': 'Ann', 'b': 'Bob'}),
        ],
        locale: const Locale('en'),
        child: const SiteAttributionLine(site: _site),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Last edited by Bob'), findsOneWidget);
  });

  testWidgets('falls back to a short member id when the card is missing', (
    tester,
  ) async {
    final state = SharedSiteState(
      siteId: 's',
      libraryId: 'L',
      clocks: {'name': _clock(DateTime.utc(2026, 1, 1), 'abcdef123456')},
    );
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...await getBaseOverrides(),
          siteLibraryStateProvider('s').overrideWith((ref) async => state),
          libraryMemberNamesProvider('L').overrideWith((ref) async => const {}),
        ],
        locale: const Locale('en'),
        child: const SiteAttributionLine(site: _site),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('abcdef12'), findsOneWidget);
    expect(find.textContaining('abcdef123456'), findsNothing);
  });

  testWidgets('renders nothing for a personal site', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: await getBaseOverrides(),
        locale: const Locale('en'),
        child: const SiteAttributionLine(
          site: DiveSite(id: 'p', name: 'P'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Text), findsNothing);
  });
}
