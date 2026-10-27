import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

import 'package:submersion/core/services/nearby/nearby_carrier.dart';
import 'package:submersion/core/services/nearby/nearby_link_manager.dart';
import 'package:submersion/features/settings/presentation/providers/nearby_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Pairs this device with another of the diver's devices (issue #3731).
///
/// While the page is open the link is in pairing mode: both devices look
/// for each other, and each device found appears with the six-digit code
/// both screens show. Confirming on both stores the pairing and starts the
/// first sync.
class NearbyPairPage extends ConsumerStatefulWidget {
  const NearbyPairPage({super.key});

  @override
  ConsumerState<NearbyPairPage> createState() => _NearbyPairPageState();
}

class _NearbyPairPageState extends ConsumerState<NearbyPairPage> {
  late final NearbyLinkManager _manager;
  late Future<NearbyAvailability> _availability;
  StreamSubscription<Object?>? _refusals;
  bool _differentLibrary = false;

  @override
  void initState() {
    super.initState();
    _manager = ref.read(nearbyLinkManagerProvider);
    _availability = _start();
    _refusals = _manager.pairingRefusals.listen((_) {
      if (mounted) setState(() => _differentLibrary = true);
    });
  }

  Future<NearbyAvailability> _start() async {
    final availability = await _manager.checkAvailability();
    // Left while the check ran: dispose already left pairing mode.
    if (availability == NearbyAvailability.ready && mounted) {
      await _manager.enterPairingMode();
    }
    return availability;
  }

  void _retry() {
    final next = _start();
    setState(() {
      _availability = next;
    });
  }

  @override
  void dispose() {
    _refusals?.cancel();
    unawaited(_manager.leavePairingMode());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings_nearby_pair)),
      body: FutureBuilder<NearbyAvailability>(
        future: _availability,
        builder: (context, snapshot) {
          final availability = snapshot.data;
          if (availability == null) return const SizedBox.shrink();
          if (availability != NearbyAvailability.ready) {
            return _Unavailable(availability: availability, onRetry: _retry);
          }
          final offers =
              ref.watch(nearbyPendingPairingsProvider).value ??
              const <NearbyPairingOffer>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_differentLibrary)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    l10n.nearbyPair_differentLibrary,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (offers.isEmpty) const _Looking(),
              for (final offer in offers)
                _OfferCard(key: ValueKey(offer.peerKey), offer: offer),
            ],
          );
        },
      ),
    );
  }
}

class _Looking extends StatelessWidget {
  const _Looking();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      children: [
        const SizedBox(height: 32),
        Icon(
          Icons.bluetooth_searching,
          size: 48,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(l10n.nearbyPair_looking, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          l10n.nearbyPair_hint,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// One device found nearby, with the code to compare.
class _OfferCard extends StatefulWidget {
  const _OfferCard({super.key, required this.offer});

  final NearbyPairingOffer offer;

  @override
  State<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<_OfferCard> {
  bool _waiting = false;

  @override
  void initState() {
    super.initState();
    // Confirmed before the diver left the page: wait for that answer again,
    // so the page still closes when the other device confirms.
    if (widget.offer.confirming) {
      _waiting = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_confirm());
      });
    }
  }

  Future<void> _confirm() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _waiting = true);
    try {
      await widget.offer.confirm();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.nearbyPair_done(widget.offer.peerName))),
      );
      // Only this page: if the diver already left it, the pop would close
      // whatever they went back to.
      if (mounted) navigator.pop();
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.nearbyPair_failed)));
      if (mounted) setState(() => _waiting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final code = widget.offer.code;
    final grouped = code.length == 6
        ? '${code.substring(0, 3)} ${code.substring(3)}'
        : code;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.nearbyPair_found(widget.offer.peerName)),
            if (widget.offer.bothPopulated) ...[
              const SizedBox(height: 8),
              Text(
                l10n.nearbyPair_bothPopulated,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              grouped,
              textAlign: TextAlign.center,
              style: theme.textTheme.displayMedium?.copyWith(
                letterSpacing: 4,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 16),
            if (_waiting)
              Text(l10n.nearbyPair_waiting, textAlign: TextAlign.center)
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.offer.reject,
                      child: Text(l10n.nearbyPair_notMine),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _confirm,
                      child: Text(l10n.nearbyPair_sameCode),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.availability, required this.onRetry});

  final NearbyAvailability availability;
  final VoidCallback onRetry;

  /// Only the phones ask for Bluetooth at runtime, and only they have an
  /// app settings page to send the diver to.
  static bool get _canOpenSettings =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final message = switch (availability) {
      NearbyAvailability.unauthorized => l10n.nearbyPair_permissionDenied,
      NearbyAvailability.bluetoothOff => l10n.nearbyPair_bluetoothOff,
      NearbyAvailability.unsupported ||
      NearbyAvailability.ready => l10n.nearbyPair_unsupported,
    };
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Icon(
            Icons.bluetooth_disabled,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          if (availability != NearbyAvailability.unsupported)
            FilledButton(
              onPressed: onRetry,
              child: Text(l10n.common_action_tryAgain),
            ),
          if (availability == NearbyAvailability.unauthorized &&
              _canOpenSettings)
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
