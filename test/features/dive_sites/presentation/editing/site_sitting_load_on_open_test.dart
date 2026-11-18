import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_sitting_load_on_open.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';

/// A card editor reads its rows as it opens and again when handed another
/// sitting, and draws them once read (issue #4527, phase 2).
void main() {
  testWidgets('loads on open, again on a new sitting, and draws once read', (
    tester,
  ) async {
    final asked = <EditSession<DiveSite>>[];
    final answer = Completer<void>();
    final a = EditSession<DiveSite>(const DiveSite(id: 'a', name: 'A'));
    final b = EditSession<DiveSite>(const DiveSite(id: 'b', name: 'B'));
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    var builds = 0;

    Widget editor(EditSession<DiveSite> session) => Directionality(
      textDirection: TextDirection.ltr,
      child: _Probe(
        session: session,
        load: (s) {
          asked.add(s);
          return answer.future;
        },
        onBuild: () => builds++,
      ),
    );

    await tester.pumpWidget(editor(a));
    expect(asked, [a]);
    final before = builds;

    answer.complete();
    await tester.pumpAndSettle();
    expect(builds, greaterThan(before));

    await tester.pumpWidget(editor(b));
    expect(asked, [a, b]);
  });

  testWidgets('a list not read yet holds the editor back, and a failed read '
      'offers to read again', (tester) async {
    var reads = 0;
    final answer = Completer<void>();
    final list = SittingList<DiveSite, String>(
      key: 'probe.rows',
      cardId: 'probe',
      read: (_) async {
        reads++;
        if (reads == 1) throw StateError('locked');
        await answer.future;
        return ['row'];
      },
      write: (_, _, _) async => null,
    );
    final session = EditSession<DiveSite>(const DiveSite(id: 'a', name: 'A'));
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: _Gated(session: session, list: list),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l = AppLocalizationsEn();
    expect(find.text(l.recordEdit_loadFailed), findsOneWidget);
    expect(find.text('rows ready'), findsNothing);

    await tester.tap(find.text(l.recordEdit_tryAgain));
    await tester.pump();
    // Still reading: nothing to pick from yet.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('rows ready'), findsNothing);

    answer.complete();
    await tester.pumpAndSettle();
    expect(find.text('rows ready'), findsOneWidget);
  });
}

class _Gated extends StatefulWidget {
  const _Gated({required this.session, required this.list});

  final EditSession<DiveSite> session;
  final SittingList<DiveSite, String> list;

  @override
  State<_Gated> createState() => _GatedState();
}

class _GatedState extends State<_Gated> with SiteSittingLoadOnOpen<_Gated> {
  @override
  EditSession<DiveSite> sittingOf(_Gated widget) => widget.session;

  @override
  Future<void> loadSitting(EditSession<DiveSite> session) =>
      widget.list.load(session);

  @override
  Widget build(BuildContext context) =>
      sittingListPending(widget.list) ?? const Text('rows ready');
}

class _Probe extends StatefulWidget {
  const _Probe({
    required this.session,
    required this.load,
    required this.onBuild,
  });

  final EditSession<DiveSite> session;
  final Future<void> Function(EditSession<DiveSite>) load;
  final VoidCallback onBuild;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with SiteSittingLoadOnOpen<_Probe> {
  @override
  EditSession<DiveSite> sittingOf(_Probe widget) => widget.session;

  @override
  Future<void> loadSitting(EditSession<DiveSite> session) =>
      widget.load(session);

  @override
  Widget build(BuildContext context) {
    widget.onBuild();
    return const SizedBox.shrink();
  }
}
