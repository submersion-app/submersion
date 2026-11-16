import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/ui/chart_viewport.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_profile_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_profile_card_editor.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The open Profile card draws the page's profile section over the sitting
/// (issue #4527, plan 6).
void main() {
  final dive = Dive(id: 'd1', dateTime: DateTime.utc(2026));
  const zoomed = ChartViewport(zoom: 2, offsetX: 0.25, offsetY: 0);

  testWidgets('keeps one chart key across rebuilds, and the page\'s zoom', (
    tester,
  ) async {
    final session = EditSession<Dive>(dive);
    addTearDown(session.dispose);
    final page = DiveDetailProfileSection(
      diveId: 'd1',
      exportKey: GlobalKey(),
      onSafetyFindingDetails: () {},
      onSetPrimarySource: (_) {},
      viewport: zoomed,
      onViewportChanged: (_) {},
    );
    late StateSetter rebuild;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [diveProvider('d1').overrideWith((ref) async => null)],
        child: MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return DiveProfileEditorSource(
                section: page,
                child: DiveProfileCardEditor(session: session),
              );
            },
          ),
        ),
      ),
    );
    DiveDetailProfileSection drawn() =>
        tester.widget(find.byType(DiveDetailProfileSection));
    final first = drawn();
    expect(first.editing, session);
    expect(first.viewport, zoomed);
    expect(first.onViewportChanged, page.onViewportChanged);
    expect(first.exportKey, isNot(page.exportKey));

    rebuild(() {});
    await tester.pump();
    expect(drawn().exportKey, same(first.exportKey));
  });
}
