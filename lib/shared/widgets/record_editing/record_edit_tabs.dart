import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_host.dart';

/// A record page whose cards are spread over tabs, such as a trip's six
/// (issue #4527, phase 3). One sitting spans every tab.
///
/// The strip offers the empty cards of the tab in view, and a card asked to
/// show itself on another tab (a Save refused for it) brings that tab
/// forward. Each tab's view is wrapped in [RecordEditKeepAlive], so an open
/// card, and text typed in it that cannot be read yet, survive a visit to
/// another tab.
///
/// The page supplies which tab each card is on, the tab in view and how to
/// show one, and its strip entries for every tab; it redraws when the tab
/// in view changes, so the strip follows.
mixin RecordEditTabs<W extends ConsumerStatefulWidget, T>
    on RecordEditHost<W, T> {
  /// The tab [cardId] is on; null for a card on every tab, such as a header
  /// block.
  int? tabOfCard(String cardId);

  /// The tab in view.
  int get tabInView;

  /// Brings [tab] into view.
  void showTab(int tab);

  /// The cards the page is leaving out, on every tab, in the page's order.
  List<AddStripEntry> addStripEntriesOnEveryTab(T working);

  /// The last request to show a card that this page answered by changing
  /// tab, and the controller it came from (serials count per controller),
  /// so one request moves the page once.
  ({Object controller, int serial})? _revealServed;

  @override
  List<AddStripEntry> addStripEntries(T working) {
    final inView = tabInView;
    return [
      for (final entry in addStripEntriesOnEveryTab(working))
        if (_onTab(entry.cardId, inView)) entry,
    ];
  }

  bool _onTab(String cardId, int tab) {
    final cardTab = tabOfCard(cardId);
    return cardTab == null || cardTab == tab;
  }

  @override
  void onEditChanged() {
    super.onEditChanged();
    if (!mounted) return;
    final controller = maybeEditController;
    final request = controller?.revealRequest;
    if (controller == null || request == null) return;
    final served = _revealServed;
    if (served != null &&
        identical(served.controller, controller) &&
        served.serial == request.serial) {
      return;
    }
    final tab = tabOfCard(request.cardId);
    if (tab == null || tab == tabInView) return;
    _revealServed = (controller: controller, serial: request.serial);
    // The card's frame on that tab answers the request as it is built.
    showTab(tab);
  }
}

/// Keeps one tab's view of a record page alive while the record is
/// unlocked, so its open cards and what is typed in them stay as they are
/// while another tab is in view. Locked, it lets the view go as the tab
/// view would, so a page that only reads builds just the tab in view.
class RecordEditKeepAlive<T> extends StatefulWidget {
  const RecordEditKeepAlive({super.key, required this.child});

  final Widget child;

  @override
  State<RecordEditKeepAlive<T>> createState() => _RecordEditKeepAliveState<T>();
}

class _RecordEditKeepAliveState<T> extends State<RecordEditKeepAlive<T>>
    with AutomaticKeepAliveClientMixin {
  bool _unlocked = false;

  @override
  bool get wantKeepAlive => _unlocked;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Called again on every change of the sitting's controller.
    final unlocked = RecordEditScope.maybeOf<T>(context)?.isUnlocked ?? false;
    if (unlocked == _unlocked) return;
    _unlocked = unlocked;
    updateKeepAlive();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
