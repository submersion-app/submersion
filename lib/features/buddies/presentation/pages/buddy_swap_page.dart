import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/nearby/nearby_card_host.dart';
import 'package:submersion/core/services/nearby/nearby_carrier.dart';
import 'package:submersion/features/buddies/data/services/buddy_card_nfc.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_card.dart';
import 'package:submersion/features/buddies/domain/services/buddy_card_codec.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_card_providers.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_swap_providers.dart';
import 'package:submersion/features/buddies/presentation/services/buddy_swap_session.dart';
import 'package:submersion/features/buddies/presentation/utils/open_buddy_card.dart';
import 'package:submersion/features/buddies/presentation/widgets/swap/card_summary.dart';
import 'package:submersion/features/buddies/presentation/widgets/swap/nearby_section.dart';
import 'package:submersion/features/buddies/presentation/widgets/swap/share_choices_sheet.dart';
import 'package:submersion/features/buddies/presentation/widgets/swap/show_card_qr_sheet.dart';
import 'package:submersion/features/buddies/presentation/widgets/swap/swap_method_groups.dart';
import 'package:submersion/features/buddies/presentation/widgets/swap/swap_request_sheet.dart';
import 'package:submersion/features/buddies/presentation/widgets/swap/your_card_section.dart';
import 'package:submersion/features/cylinder_passports/data/services/nfc_tag_service.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_scan_sheet.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';
import 'package:submersion/features/demo_mode/presentation/demo_seal_guard.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Swap with a buddy (issues #3728, #4598): your card on top, divers
/// nearby, then the ways to give your card and to get theirs; two columns
/// on a wide page.
class BuddySwapPage extends ConsumerStatefulWidget {
  const BuddySwapPage({super.key});

  @override
  ConsumerState<BuddySwapPage> createState() => _BuddySwapPageState();
}

class _BuddySwapPageState extends ConsumerState<BuddySwapPage>
    with WidgetsBindingObserver {
  static final _log = LoggerService.forClass(BuddySwapPage);
  BuddySwapSession? _session;
  StreamSubscription<NearbyCardEvent>? _events;
  Timer? _refresh;
  BuddyCard? _card;
  bool _cardFailed = false;

  /// The diver whose request sheet is open, so an expired request can close
  /// it, and what closes it.
  String? _openRequest;
  Completer<void>? _closeOpenRequest;

  /// Requests waiting for the open sheet to close: one question at a time.
  final _queuedRequests = <CardRequested>[];

  /// Bumped by every start and stop, so a start still building the card
  /// when the page was left (or started again) gives up.
  int _runs = 0;
  NearbyAvailability? _availability;

  /// The nearby session could not start (a platform error); the fallbacks
  /// still work and the diver can try again.
  bool _startFailed = false;
  List<NearbyCardPeer> _peers = const [];
  final _waitingFor = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
    // Divers leave without saying so; the list drops them as they age out.
    _refresh = Timer.periodic(const Duration(seconds: 5), (_) {
      final session = _session;
      if (mounted && session != null) setState(() => _peers = session.peers);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refresh?.cancel();
    unawaited(_stop());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) unawaited(_stop());
    if (state == AppLifecycleState.resumed && _session == null) {
      unawaited(_start());
    }
  }

  Future<void> _start() async {
    final run = ++_runs;
    final BuddyCard? card;
    try {
      card = await ref.read(myBuddyCardProvider.future);
    } on Object catch (e, stackTrace) {
      _log.error(
        'Buddy card could not be built',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted && run == _runs) _cardGone();
      return;
    }
    if (!mounted || run != _runs) return;
    if (card == null) {
      // No current diver: nothing to send, but receiving still works.
      _cardGone();
      return;
    }
    final session = ref.read(buddySwapSessionFactoryProvider)(card);
    _session = session;
    _events = session.events.listen(_onEvent);
    final NearbyAvailability availability;
    try {
      availability = await session.start();
    } on Object catch (e, stackTrace) {
      _log.error(
        'Buddy swap session did not start',
        error: e,
        stackTrace: stackTrace,
      );
      await session.stop();
      if (mounted && run == _runs) {
        setState(() {
          _card = card;
          _cardFailed = false;
          _availability = null;
          _startFailed = true;
        });
      }
      return;
    }
    if (!mounted || run != _runs) {
      // The page closed, or was left or restarted, while the radio was
      // coming on: this start is stale and its session ends.
      await session.stop();
      return;
    }
    setState(() {
      _card = card;
      _cardFailed = false;
      _startFailed = false;
      _availability = availability;
      _peers = session.peers;
    });
  }

  /// The card could not be built, now or on a rebuild: the old one (and
  /// everything built on it) is gone too, so the page shows the failure.
  void _cardGone() => setState(() {
    _card = null;
    _cardFailed = true;
  });

  /// Stops at once, before any await: from [dispose] nothing after the
  /// first await is guaranteed to run before the page is gone.
  Future<void> _stop() async {
    _runs++;
    // Requests made on this session end with it: their rows are free
    // again, and requests still waiting their turn are declined.
    _waitingFor.clear();
    for (final request in _queuedRequests) {
      request.decide(false);
    }
    _queuedRequests.clear();
    // The request on screen closes too; its sheet answers no.
    final close = _closeOpenRequest;
    if (close != null && !close.isCompleted) close.complete();
    final session = _session;
    _session = null;
    final stopping = session?.stop();
    final events = _events;
    _events = null;
    await events?.cancel();
    await stopping;
  }

  Future<void> _restart() async {
    await _stop();
    ref.invalidate(myBuddyCardProvider);
    await _start();
  }

  void _onEvent(NearbyCardEvent event) {
    if (!mounted) return;
    final l10n = context.l10n;
    switch (event) {
      case CardPeersChanged(:final peers):
        setState(() => _peers = peers);
      case CardRequested():
        _queuedRequests.add(event);
        if (_openRequest == null) unawaited(_answerQueued());
      case CardReceived(:final from, :final cardBytes):
        setState(() => _waitingFor.remove(from.swapId));
        openBuddyCard(context, BuddyCardCodec.decodeFull(cardBytes));
      case CardRequestExpired(:final from):
        if (_openRequest == from.swapId) {
          final close = _closeOpenRequest;
          if (close != null && !close.isCompleted) close.complete();
        } else {
          final queued = _queuedRequests
              .where((r) => r.from.swapId == from.swapId)
              .toList();
          for (final r in queued) {
            _queuedRequests.remove(r);
            r.decide(false);
          }
        }
      case CardSwapFailed(:final peer, :final reason):
        setState(() => _waitingFor.remove(peer.swapId));
        _say(switch (reason) {
          NearbyCardFailure.declined => l10n.buddySwap_failed_declined(
            peer.name,
          ),
          NearbyCardFailure.timedOut => l10n.buddySwap_failed_timedOut(
            peer.name,
          ),
          NearbyCardFailure.lost => l10n.buddySwap_failed_lost(peer.name),
          NearbyCardFailure.newerApp => l10n.buddySwap_failed_newerApp(
            peer.name,
          ),
        });
    }
  }

  /// Asks about each queued request in turn, one sheet at a time.
  Future<void> _answerQueued() async {
    while (mounted && _queuedRequests.isNotEmpty) {
      final request = _queuedRequests.removeAt(0);
      final card = _card;
      if (card == null) {
        request.decide(false);
        continue;
      }
      _openRequest = request.from.swapId;
      final close = _closeOpenRequest = Completer<void>();
      final accepted = await showSwapRequestSheet(
        context,
        from: request.from,
        youSend: buddyCardSummary(card, context.l10n),
        closed: close.future,
      );
      _openRequest = null;
      _closeOpenRequest = null;
      request.decide(accepted);
    }
  }

  /// Demo mode (issue #3708): the sample diver's card leaves the phone by
  /// no route, however this screen was reached.
  bool _mayShare() => demoSealGuard(context, DemoSealedFeature.share);

  void _say(String message) => ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(message)));

  Future<void> _request(NearbyCardPeer peer) async {
    setState(() => _waitingFor.add(peer.swapId));
    await _session?.request(peer);
  }

  Future<void> _changeChoices() async {
    final choices = await ref.read(myBuddyCardChoicesProvider.future);
    final available = await ref.read(myBuddyCardFieldsProvider.future);
    if (!mounted) return;
    // Each toggle saves the whole diver row: one at a time, in order, so a
    // slower earlier save never lands after a newer choice.
    Future<void>? saves;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ShareChoicesSheet(
        initial: choices,
        available: available,
        onChanged: (next) => saves = (saves ?? Future.value()).then(
          (_) => saveMyBuddyCardChoices(ref, next),
        ),
      ),
    );
    if (saves == null) return;
    // Every toggle is saved before the card is rebuilt from them.
    await saves;
    if (mounted) await _restart();
  }

  Future<void> _scanCode() async {
    final text = await showPassportScanSheet(context);
    if (text == null || !mounted) return;
    openBuddyCard(context, BuddyCardCodec.decodeLink(text));
  }

  /// Shares the card as a file written to a temporary folder. A share
  /// keeps the file: the receiving app may read it after the share sheet
  /// returns, and the OS clears its temporary folder in time.
  Future<void> _sendFile(Rect? anchor) async {
    final card = _card;
    if (card == null || !_mayShare()) return;
    final l10n = context.l10n;
    Directory? temp;
    var keepForShare = false;
    try {
      temp = await Directory.systemTemp.createTemp('buddy_card');
      final name = BuddyCardCodec.fileNameFor(card.name);
      final file = File(p.join(temp.path, name));
      await file.writeAsBytes(BuddyCardCodec.encodeFull(card));
      keepForShare = canShareFiles;
      await shareFileAtPath(
        file.path,
        name,
        'application/json',
        dialogTitle: l10n.buddySwap_action_sendFile,
        sharePositionOrigin: anchor,
      );
    } on Object catch (e, stackTrace) {
      _log.error(
        'Buddy card file was not shared',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) _say(l10n.buddySwap_sendFailed);
    } finally {
      if (!keepForShare) {
        try {
          await temp?.delete(recursive: true);
        } on Object {
          // The OS clears its temporary folder in time.
        }
      }
    }
  }

  Future<void> _openFile() async {
    final l10n = context.l10n;
    try {
      final bytes = await ref.read(buddyCardFilePickerProvider)();
      if (bytes == null || !mounted) return;
      openBuddyCard(context, BuddyCardCodec.decodeFull(bytes));
    } on Object catch (e) {
      _log.info('Buddy card file was not opened: $e');
      if (mounted) _say(l10n.buddyCard_error_unreadable);
    }
  }

  void _showCode(BuddyCard card) {
    if (!_mayShare()) return;
    try {
      unawaited(showCardQrSheet(context, card));
    } on BuddyCardTooLarge {
      _say(context.l10n.buddySwap_qr_tooLarge);
    }
  }

  static BuddyCardNfcText _nfcText(AppLocalizations l10n) => BuddyCardNfcText(
    readPrompt: l10n.buddySwap_tap_prompt,
    writePrompt: l10n.buddySwap_sticker_prompt,
    notACard: l10n.buddyCard_error_notACard,
    unreadable: l10n.buddyCard_error_unreadable,
    readFailed: l10n.passport_nfc_readFailed,
    written: l10n.buddySwap_sticker_written,
    tooSmall: l10n.buddySwap_sticker_tooSmall,
    notWritable: l10n.buddySwap_sticker_notWritable,
    writeFailed: l10n.passport_nfc_writeFailed,
  );

  Future<void> _readTag() async {
    final l10n = context.l10n;
    try {
      final result = await ref
          .read(buddyCardNfcProvider)
          .readCard(_nfcText(l10n));
      if (mounted) openBuddyCard(context, result);
    } on NfcSessionCancelled {
      // The diver closed the sheet.
    } on Object {
      if (mounted) _say(l10n.buddySwap_nfc_unavailable);
    }
  }

  Future<void> _writeSticker() async {
    final card = _card;
    if (card == null || !_mayShare()) return;
    final l10n = context.l10n;
    String? message;
    try {
      await ref.read(buddyCardNfcProvider).writeSticker(card, _nfcText(l10n));
      message = l10n.buddySwap_sticker_written;
    } on NfcSessionCancelled {
      // The diver closed the sheet.
    } on BuddyCardStickerTooSmall {
      message = l10n.buddySwap_sticker_tooSmall;
    } on BuddyCardStickerNotWritable {
      message = l10n.buddySwap_sticker_notWritable;
    } on Object {
      message = l10n.buddySwap_nfc_unavailable;
    }
    // The diver may have left the screen while the sticker was written.
    if (message != null && mounted) _say(message);
  }

  /// Two columns from this page width (not the window's: on desktop the
  /// page sits beside the navigation rail).
  static const double _twoColumnWidth = 720;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final card = _card;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.buddySwap_title)),
      body: card == null && !_cardFailed
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final yours = <Widget>[
                  YourCardSection(card: card, onEdit: _changeChoices),
                  // The nearby session runs on the diver's card: none, no
                  // nearby, and nothing to give.
                  if (card != null)
                    NearbySection(
                      availability: _availability,
                      failed: _startFailed,
                      peers: _peers,
                      waitingFor: _waitingFor,
                      onTap: _request,
                      onRetry: _restart,
                    ),
                ];
                final methods = <Widget>[
                  if (card != null)
                    GiveCardGroup(
                      onShowCode: () => _showCode(card),
                      onSendFile: _sendFile,
                      onWriteSticker: _writeSticker,
                    ),
                  GetCardGroup(
                    onScanCode: _scanCode,
                    onOpenFile: _openFile,
                    onReadTag: _readTag,
                  ),
                ];
                const padding = EdgeInsets.symmetric(vertical: 8);
                if (constraints.maxWidth < _twoColumnWidth) {
                  return ListView(
                    padding: padding,
                    children: [...yours, ...methods],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ListView(padding: padding, children: yours),
                    ),
                    // One primary list per route: on iOS and Android both
                    // would attach to the route's controller, and a
                    // status-bar tap could not tell which to scroll.
                    Expanded(
                      child: ListView(
                        primary: false,
                        padding: padding,
                        children: methods,
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
