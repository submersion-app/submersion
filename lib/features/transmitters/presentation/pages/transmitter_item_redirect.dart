import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// `/transmitters/:transmitterId/edit`, kept for deep links and old back
/// stacks: a transmitter's page is its Equipment item's (issue #3676), so
/// this replaces itself with that page.
class TransmitterItemRedirect extends ConsumerWidget {
  const TransmitterItemRedirect({super.key, required this.transmitterId});

  final String transmitterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = ref.watch(transmitterProvider(transmitterId));
    final itemId = key.valueOrNull?.transmitterEquipmentId;
    if (itemId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.replace('/equipment/$itemId');
      });
    }
    final gone = key.hasValue && itemId == null;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.transmitters_title)),
      body: Center(
        child: gone
            ? Text(context.l10n.equipment_detail_notFoundMessage)
            : const CircularProgressIndicator(),
      ),
    );
  }
}
