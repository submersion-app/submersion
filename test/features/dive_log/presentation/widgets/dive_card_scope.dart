import 'package:flutter/widgets.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

/// [card] as the dive page builds it: under the page's lock (issue #4527),
/// which the page always offers. Locked unless [unlocked] holds the dive,
/// in a sitting with nothing changed, so whole-record operations may run.
Widget onDivePage(Widget card, {Dive? unlocked}) =>
    _DiveCardScope(unlocked: unlocked, child: card);

class _DiveCardScope extends StatefulWidget {
  const _DiveCardScope({required this.child, this.unlocked});

  final Widget child;
  final Dive? unlocked;

  @override
  State<_DiveCardScope> createState() => _DiveCardScopeState();
}

class _DiveCardScopeState extends State<_DiveCardScope> {
  final _controller = RecordEditController<Dive>(onSave: (_) async {});

  @override
  void initState() {
    super.initState();
    final dive = widget.unlocked;
    if (dive != null) _controller.unlock(dive);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RecordEditScope<Dive>(controller: _controller, child: widget.child);
}
