import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

/// Wraps one card of a record page so it can be edited in place.
///
/// Locked, or on a page with no [RecordEditScope], [child] is shown
/// untouched. Unlocked, the card's [RecordCardHeader] gains its pencil; once
/// opened, [child] gives way to the card's editor, drawn where it sat.
///
/// The tree beneath a frame keeps one shape while the card is closed, so
/// unlocking and locking never remount [child].
///
/// When the controller asks this card to show itself
/// ([RecordEditController.revealRequest]), the frame scrolls into view.
class RecordCardFrame<T> extends StatefulWidget {
  const RecordCardFrame({super.key, required this.card, required this.child});

  final EditCard<T> card;

  /// The card's read widget.
  final Widget child;

  @override
  State<RecordCardFrame<T>> createState() => _RecordCardFrameState<T>();
}

class _RecordCardFrameState<T> extends State<RecordCardFrame<T>> {
  /// The newest reveal request this frame has seen. Null until the first
  /// look, which only notes what is already there: a request is for the
  /// frames on the page when it is made.
  int? _seenRevealSerial;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final request = RecordEditScope.maybeOf<T>(context)?.revealRequest;
    final seen = _seenRevealSerial;
    _seenRevealSerial = request?.serial ?? seen ?? 0;
    if (seen == null || request == null) return;
    if (request.serial <= seen || request.cardId != widget.card.id) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.1,
        duration: const Duration(milliseconds: 200),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final controller = RecordEditScope.maybeOf<T>(context);
    final session = controller?.session;
    if (controller == null || session == null) {
      return RecordCardFrameScope(data: null, child: widget.child);
    }

    final isOpen = controller.openCardIds.contains(card.id);
    return RecordCardFrameScope(
      data: RecordCardFrameData(
        isOpen: isOpen,
        isChanged: session.changedCardIds.contains(card.id),
        onOpen: () => controller.openCard(card.id),
        onDone: () => controller.closeCard(card.id),
      ),
      child: isOpen ? _OpenCard<T>(card: card, session: session) : widget.child,
    );
  }
}

/// A card with its editor showing, outlined in the accent colour.
class _OpenCard<T> extends StatelessWidget {
  const _OpenCard({required this.card, required this.session});

  final EditCard<T> card;
  final EditSession<T> session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themed = theme.cardTheme.shape;
    final radius = themed is RoundedRectangleBorder
        ? themed.borderRadius
        : BorderRadius.circular(12);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: theme.colorScheme.primary, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            RecordCardHeader(title: card.title(context)),
            const Divider(),
            card.editorBuilder(context, session),
          ],
        ),
      ),
    );
  }
}
