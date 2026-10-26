import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/transmitters/data/services/transmitter_setup_target.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// `/transmitters/new?serial=&dive=`: the cylinders card's "Assign
/// transmitter" and old links (issue #3676). A transmitter is its Equipment
/// item, so this opens the item behind [serial], registering it from [diveId]
/// when no entry knows it yet, and otherwise starts a new Transmitter item
/// carrying the serial.
class TransmitterSetupRedirect extends ConsumerStatefulWidget {
  const TransmitterSetupRedirect({super.key, this.serial, this.diveId});

  final String? serial;
  final String? diveId;

  @override
  ConsumerState<TransmitterSetupRedirect> createState() =>
      _TransmitterSetupRedirectState();
}

class _TransmitterSetupRedirectState
    extends ConsumerState<TransmitterSetupRedirect> {
  static final _log = LoggerService.forClass(TransmitterSetupRedirect);

  @override
  void initState() {
    super.initState();
    _forward();
  }

  Future<void> _forward() async {
    final serial = normalizeTransmitterSerial(widget.serial);
    String? itemId;
    try {
      if (serial != null) {
        final diveId = widget.diveId;
        if (diveId != null) {
          itemId = await transmitterItemForSetup(
            serial: serial,
            diveId: diveId,
            registrar: ref.read(transmitterAutoRegistrarProvider),
          );
        }
        // No dive, or one deleted since the link was made: the entry may
        // still be known by its serial alone.
        itemId ??= await ref
            .read(transmitterRepositoryProvider)
            .itemIdForSerial(
              serial,
              diverId: await ref.read(validatedCurrentDiverIdProvider.future),
            );
      }
    } catch (e, stackTrace) {
      // A failed lookup still lands somewhere useful: a new item.
      _log.warning(
        'Finding the transmitter item for serial $serial failed',
        error: e,
        stackTrace: stackTrace,
      );
      itemId = null;
    }
    if (!mounted) return;
    context.replace(
      itemId != null
          ? '/equipment/$itemId'
          : Uri(
              path: '/equipment/new',
              queryParameters: {
                'type': EquipmentType.transmitter.name,
                'serial': ?serial,
              },
            ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.transmitters_title)),
    body: const Center(child: CircularProgressIndicator()),
  );
}
