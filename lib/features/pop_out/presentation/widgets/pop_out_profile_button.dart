import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/pop_out/presentation/providers/pop_out_host.dart';
import 'package:submersion/features/pop_out/presentation/providers/pop_out_providers.dart';

/// Opens [diveId]'s profile in its own window (issue #5078), or brings the
/// open one to the front. Nothing on phones, tablets and the web.
class PopOutProfileButton extends ConsumerWidget {
  const PopOutProfileButton({super.key, required this.diveId});

  final String diveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(popOutAvailableProvider)) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.open_in_new),
      tooltip: context.l10n.popOut_openProfileWindow,
      visualDensity: VisualDensity.compact,
      onPressed: () =>
          ref.read(popOutHostProvider.notifier).openOrFocus(diveId: diveId),
    );
  }
}
