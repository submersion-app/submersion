import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
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
  BuddySwapSession? _session;
  StreamSubscription<NearbyCardEvent>? _events;
  Timer? _refresh;
  BuddyCard? _card;
  NearbyAvailability? _availability;
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
    final card = await ref.read(myBuddyCardProvider.future);
    if (!mounted || card == null) return;
    final session = ref.read(buddySwapSessionFactoryProvider)(card);
    _session = session;
    _events = session.events.listen(_onEvent);
    final availability = await session.start();
    if (!mounted) return;
    setState(() {
      _card = card;
      _availability = availability;
      _peers = session.peers;
    });
  }

  /// Stops at once, before any await: from [dispose] nothing after the
  /// first await is guaranteed to run before the page is gone.
  Future<void> _stop() async {
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
      case CardRequested(:final from, :final decide):
        unawaited(_answer(from, decide));
      case CardReceived(:final from, :final cardBytes):
        setState(() => _waitingFor.remove(from.swapId));
        openBuddyCard(context, BuddyCardCodec.decodeFull(cardBytes));
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

  Future<void> _answer(NearbyCardPeer from, NearbyCardDecision decide) async {
    final card = _card;
    if (card == null) return decide(false);
    decide(
      await showSwapRequestSheet(
        context,
        from: from,
        youSend: buddyCardSummary(card, context.l10n),
      ),
    );
  }

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
    var changed = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ShareChoicesSheet(
        initial: choices,
        available: available,
        onChanged: (next) {
          changed = true;
          unawaited(saveMyBuddyCardChoices(ref, next));
        },
      ),
    );
    if (changed && mounted) await _restart();
  }

  Future<void> _scanCode() async {
    final text = await showPassportScanSheet(context);
    if (text == null || !mounted) return;
    openBuddyCard(context, BuddyCardCodec.decodeLink(text));
  }

  Future<void> _sendFile() async {
    final card = _card;
    if (card == null) return;
    await saveAndShareFileBytes(
      BuddyCardCodec.encodeFull(card),
      '${card.name}.${BuddyCardCodec.fileExtension}',
      'application/json',
    );
  }

  Future<void> _openFile() async {
    final bytes = await ref.read(buddyCardFilePickerProvider)();
    if (bytes == null || !mounted) return;
    openBuddyCard(context, BuddyCardCodec.decodeFull(bytes));
  }

  Future<void> _readTag() async {
    final l10n = context.l10n;
    try {
      final result = await ref
          .read(buddyCardNfcProvider)
          .readCard(promptIos: l10n.buddySwap_tap_prompt);
      if (mounted) openBuddyCard(context, result);
    } on NfcSessionCancelled {
      // The diver closed the sheet.
    } on Object {
      if (mounted) _say(l10n.buddySwap_nfc_unavailable);
    }
  }

  Future<void> _writeSticker() async {
    final card = _card;
    if (card == null) return;
    final l10n = context.l10n;
    try {
      await ref
          .read(buddyCardNfcProvider)
          .writeSticker(card, promptIos: l10n.buddySwap_sticker_prompt);
      _say(l10n.buddySwap_sticker_written);
    } on NfcSessionCancelled {
      // The diver closed the sheet.
    } on BuddyCardStickerTooSmall {
      _say(l10n.buddySwap_sticker_tooSmall);
    } on BuddyCardStickerNotWritable {
      _say(l10n.buddySwap_sticker_notWritable);
    } on Object {
      _say(l10n.buddySwap_nfc_unavailable);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final card = _card;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.buddySwap_title)),
      body: card == null
          ? const Center(child: CircularProgressIndicator())
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
                  _Unavailable(availability: _availability, onRetry: _restart),
                const SizedBox(height: 8),
                _SharingLine(
                  summary: buddyCardSummary(card, l10n),
                  onChange: _changeChoices,
                ),
                SwapFallbackButtons(
                  onShowCode: () => showCardQrSheet(context, card),
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
  const _Unavailable({required this.availability, required this.onRetry});

  final NearbyAvailability? availability;
  final VoidCallback onRetry;

  static bool get _isPhone =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  String _message(AppLocalizations l10n) => switch (availability) {
    NearbyAvailability.unauthorized => l10n.nearbyPair_permissionDenied,
    NearbyAvailability.bluetoothOff => l10n.nearbyPair_bluetoothOff,
    _ => l10n.nearbyPair_unsupported,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (availability == null) {
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
