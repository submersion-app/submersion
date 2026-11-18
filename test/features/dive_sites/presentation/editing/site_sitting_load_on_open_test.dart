import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_sitting_load_on_open.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

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
