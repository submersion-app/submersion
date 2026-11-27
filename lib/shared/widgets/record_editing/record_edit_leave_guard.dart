import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/forms/discard_dialog.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/tab_visibility.dart';

/// Ends a sitting without saving, asking first when it has unsaved changes.
///
/// True means the record is now locked. False means the diver chose to keep
/// editing and nothing changed, or a save is running: a sitting that is
/// being written cannot be discarded, and locks by itself when the write
/// ends.
Future<bool> cancelSitting<T>(
  BuildContext context,
  RecordEditController<T> controller,
) async {
  if (controller.isBusy) return false;
  if (controller.isDirty && !await showDiscardDialog(context)) return false;
  controller.lock();
  return true;
}

/// Guards a record page's sitting: it is not left with unsaved changes
/// unasked, and nothing happens to it while it is being saved.
///
/// With changes pending, going back asks whether to discard them. With none,
/// the page simply closes, and an unlocked record is locked on the way out.
///
/// While a save is running the page takes no input, from a pointer or the
/// keyboard, and going back does nothing. Otherwise a keystroke could reach
/// a sitting that has already been handed to the database, and a discard
/// could lock the page while the write carries on. The save ends shortly
/// and either locks the page or gives it back.
///
/// The system Back while the on-screen keyboard is up for a field on the
/// page only closes the keyboard: on Android that Back is the key that
/// hides it, and was taken for leaving the page (#4961). Some devices also
/// send a Back while the keyboard is moving, as a field is tapped and it
/// opens or as it closes: that Back does nothing at all (#5059). The app
/// bar's back arrow is a deliberate leave and still asks.
class RecordEditLeaveGuard<T> extends StatelessWidget {
  const RecordEditLeaveGuard({
    super.key,
    required this.controller,
    required this.child,
    this.backsOutFirst,
  });

  final RecordEditController<T> controller;
  final Widget child;

  /// Whether the page has a step of its own that Back closes first (the
  /// photo viewer's fullscreen): while it does, Back leaves the sitting as
  /// it is and asks nothing. Read as Back arrives, before that step's own
  /// handler runs.
  final bool Function()? backsOutFirst;

  @override
  Widget build(BuildContext context) {
    return _SystemBackClosesKeyboard(
      child: ListenableBuilder(
        listenable: controller,
        child: child,
        builder: (context, child) {
          // A kept-alive tab that is hidden (Training, Media and Documents)
          // lets Back through and asks nothing: the tab on screen answers
          // it, and the page leaves with this one's sitting, as the old forms
          // did (#3437).
          final shown = TabVisibility.isVisible(context);
          return PopScope(
            canPop: !controller.isBusy && (!controller.isDirty || !shown),
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) {
                controller.lock();
                return;
              }
              // A route tells every scope of a Back another refused: hidden,
              // this one has nothing to ask.
              if (!shown || controller.isBusy) return;
              // Back closes the page's own step first; the sitting stays.
              if (backsOutFirst?.call() ?? false) return;
              // With nothing to save this guard let the pop through: a scope
              // inside the page refused it for a step of its own (the photo
              // viewer leaving fullscreen first), and the page stays.
              if (!controller.isDirty) return;
              final navigator = Navigator.of(context);
              if (!await cancelSitting(context, controller)) return;
              // The page went while the question was open (an editor closed
              // by a change of diver, the question being in the root
              // navigator): popping now would take the page under it.
              if (!context.mounted) return;
              if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
              // A page with nothing under it (the list pane's, its tab's first
              // page) locks and stays: there is nowhere to go back to.
              if (navigator.canPop()) navigator.pop();
            },
            // Both stay in the tree, so a save starting or ending never
            // rebuilds the page beneath them. Excluding focus also takes it
            // from a field that has it, which closes the keyboard.
            child: AbsorbPointer(
              absorbing: controller.isBusy,
              child: ExcludeFocus(excluding: controller.isBusy, child: child!),
            ),
          );
        },
      ),
    );
  }
}

/// Answers the system Back, ahead of every route, by closing the on-screen
/// keyboard when it is up for a field in [child], and by doing nothing while
/// the keyboard is still moving.
///
/// The system Back reaches the router's back button dispatcher before any
/// [PopScope] hears of it, while the app bar's back arrow goes straight to
/// the navigator; listening here is what tells the two apart. Without a
/// router (a bare [MaterialApp]) there is no dispatcher, and Back goes on
/// as it would.
class _SystemBackClosesKeyboard extends StatefulWidget {
  const _SystemBackClosesKeyboard({required this.child});

  final Widget child;

  @override
  State<_SystemBackClosesKeyboard> createState() =>
      _SystemBackClosesKeyboardState();
}

class _SystemBackClosesKeyboardState extends State<_SystemBackClosesKeyboard>
    with WidgetsBindingObserver {
  /// How long after the keyboard last moved, or a field on the page took
  /// focus, a Back is still taken for the device's own. The keyboard's
  /// animation takes a few hundred milliseconds.
  static const _keyboardSettles = Duration(seconds: 1);

  /// Has focus whenever something in [_SystemBackClosesKeyboard.child] does;
  /// never takes focus itself.
  final _page = FocusNode(
    debugLabel: 'RecordEditLeaveGuard',
    canRequestFocus: false,
    skipTraversal: true,
  );

  /// Runs while the keyboard is moving or has only just stopped: restarted
  /// on every change of the window's bottom inset and whenever a field on
  /// the page takes focus, which is when the keyboard is about to open.
  Timer? _keyboardMoving;

  /// The window's bottom inset as last seen.
  double? _inset;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_onFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _inset ??= View.of(context).viewInsets.bottom;
  }

  @override
  void dispose() {
    _keyboardMoving?.cancel();
    FocusManager.instance.removeListener(_onFocusChanged);
    WidgetsBinding.instance.removeObserver(this);
    _page.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final inset = View.of(context).viewInsets.bottom;
    if (inset == _inset) return;
    _inset = inset;
    _keyboardMoved();
  }

  void _onFocusChanged() {
    if (_page.hasFocus && _isField(FocusManager.instance.primaryFocus)) {
      _keyboardMoved();
    }
  }

  void _keyboardMoved() {
    _keyboardMoving?.cancel();
    _keyboardMoving = Timer(_keyboardSettles, () => _keyboardMoving = null);
  }

  static bool _isField(FocusNode? node) =>
      node?.context?.findAncestorStateOfType<EditableTextState>() != null;

  Future<bool> _onSystemBack() async {
    final field = FocusManager.instance.primaryFocus;
    // The keyboard is opening or closing: the Back came with it, not from
    // the diver, and the page and the keyboard stay as they are. Only while
    // the keyboard can be this page's: a page above it in its navigator, or
    // a field outside it (a dialog, which sits in the root navigator above
    // the shell's), answers its own Back.
    final fieldElsewhere = !_page.hasFocus && _isField(field);
    if (_keyboardMoving != null &&
        !fieldElsewhere &&
        (ModalRoute.of(context)?.isCurrent ?? true)) {
      return true;
    }
    // A field on another page (one pushed above this) answers its own Back.
    if (field == null || !_page.hasFocus || !_isField(field)) return false;
    // The window, not MediaQuery: a Scaffold body above this page (the
    // shell's) has the keyboard's inset taken out of its MediaQuery.
    if (View.of(context).viewInsets.bottom <= 0) return false;
    field.unfocus();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final page = Focus(
      focusNode: _page,
      includeSemantics: false,
      child: widget.child,
    );
    if (Router.maybeOf(context)?.backButtonDispatcher == null) return page;
    return BackButtonListener(onBackButtonPressed: _onSystemBack, child: page);
  }
}
