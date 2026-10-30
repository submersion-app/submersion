import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart' as permissions;

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
import 'package:submersion/features/buddies/presentation/widgets/swap/nearby_divers_list.dart';
import 'package:submersion/features/buddies/presentation/widgets/swap/share_choices_sheet.dart';
import 'package:submersion/features/buddies/presentation/widgets/swap/show_card_qr_sheet.dart';
import 'package:submersion/features/buddies/presentation/widgets/swap/swap_fallback_buttons.dart';
import 'package:submersion/features/buddies/presentation/widgets/swap/swap_request_sheet.dart';
import 'package:submersion/features/cylinder_passports/data/services/nfc_tag_service.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_scan_sheet.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';
import 'package:submersion/features/demo_mode/presentation/demo_seal_guard.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Swap with a buddy (issue #3728): divers nearby first, the other ways to
/// swap below.
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
      if (mounted) setState(() => _cardFailed = true);
      return;
    }
    if (!mounted || card == null || run != _runs) return;
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
      _startFailed = false;
      _availability = availability;
      _peers = session.peers;
    });
  }

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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final card = _card;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.buddySwap_title)),
      body: card == null
          ? _cardFailed
                ? _CardFailed(onScan: _scanCode, onOpen: _openFile)
                : const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (_availability == NearbyAvailability.ready)
                  NearbyDiversList(
                    peers: _peers,
                    waitingFor: _waitingFor,
                    onTap: _request,
                  )
                else
                  _Unavailable(
                    availability: _availability,
                    failed: _startFailed,
                    onRetry: _restart,
                  ),
                const SizedBox(height: 8),
                _SharingLine(
                  summary: buddyCardSummary(card, l10n),
                  onChange: _changeChoices,
                ),
                SwapFallbackButtons(
                  onShowCode: () => _showCode(card),
                  onScanCode: _scanCode,
                  onSendFile: _sendFile,
                  onOpenFile: _openFile,
                  onWriteSticker: _writeSticker,
                  onReadTag: _readTag,
                ),
              ],
            ),
    );
  }
}

class _SharingLine extends StatelessWidget {
  const _SharingLine({required this.summary, required this.onChange});

  final String summary;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            l10n.buddySwap_sharing(summary),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          TextButton(
            onPressed: onChange,
            child: Text(l10n.buddySwap_sharing_change),
          ),
        ],
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({
    required this.availability,
    required this.failed,
    required this.onRetry,
  });

  final NearbyAvailability? availability;
  final bool failed;
  final VoidCallback onRetry;

  static bool get _isPhone =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  String _message(AppLocalizations l10n) => failed
      ? l10n.buddySwap_nearby_failed
      : switch (availability) {
          NearbyAvailability.unauthorized => l10n.nearbyPair_permissionDenied,
          NearbyAvailability.bluetoothOff => l10n.nearbyPair_bluetoothOff,
          _ => l10n.nearbyPair_unsupported,
        };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (availability == null && !failed) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(
            Icons.bluetooth_disabled,
            size: 40,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(_message(l10n), textAlign: TextAlign.center),
          if (availability != NearbyAvailability.unsupported)
            TextButton(
              onPressed: onRetry,
              child: Text(l10n.common_action_tryAgain),
            ),
          if (availability == NearbyAvailability.unauthorized && _isPhone)
            TextButton(
              onPressed: () async {
                try {
                  await permissions.openAppSettings();
                } on Object {
                  // Nowhere to send the diver on this platform.
                }
              },
              child: Text(l10n.nearbyPair_openSettings),
            ),
        ],
      ),
    );
  }
}

/// The diver's own card could not be built (a missing profile, a database
/// error): receiving still works.
class _CardFailed extends StatelessWidget {
  const _CardFailed({required this.onScan, required this.onOpen});

  final VoidCallback onScan;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(l10n.buddySwap_cardFailed, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(l10n.buddySwap_action_scanCode),
            ),
            OutlinedButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.file_open_outlined),
              label: Text(l10n.buddySwap_action_openFile),
            ),
          ],
        ),
      ],
    );
  }
}
