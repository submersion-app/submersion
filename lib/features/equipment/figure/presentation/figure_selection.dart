import 'dart:async';

import 'package:flutter/widgets.dart';

/// Selection shared by every page that shows the figure beside a list of
/// its items (spec 8.4): a tap highlights the item on the figure and in the
/// list for a moment, and scrolls the other one into view.
mixin FigureSelection<T extends StatefulWidget> on State<T> {
  String? _selectedId;
  int _serial = 0;
  Timer? _flashTimer;
  final Map<String, GlobalKey> _rowKeys = {};

  /// Goes on the figure's card, so a badge tap can scroll it into view.
  final GlobalKey figureKey = GlobalKey();

  /// The highlighted item, cleared after a moment so the highlight reads as
  /// a flash rather than a selection mode.
  String? get selectedFigureItemId => _selectedId;

  /// Bumped on every selection, for `DiverFigure.selectionSerial`.
  int get figureSelectionSerial => _serial;

  /// The key for [id]'s row, so a figure tap can scroll the row into view.
  GlobalKey figureRowKey(String id) => _rowKeys.putIfAbsent(id, GlobalKey.new);

  /// Highlights [id]. A tap on the figure brings the item's row into view;
  /// a tap on a row's badge ([revealFigure]) brings the figure into view
  /// instead, which matters on a long list whose figure has scrolled away.
  void selectFigureItem(String id, {bool revealFigure = false}) {
    _flashTimer?.cancel();
    setState(() {
      _selectedId = id;
      _serial++;
    });
    _flashTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _selectedId = null);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = revealFigure
          ? figureKey.currentContext
          : _rowKeys[id]?.currentContext;
      if (target != null && target.mounted) {
        Scrollable.ensureVisible(
          target,
          alignment: 0.3,
          duration: const Duration(milliseconds: 300),
        );
      }
    });
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }
}
