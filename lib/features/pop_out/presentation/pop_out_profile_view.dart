import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/fullscreen_profile_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_review_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/pop_out/presentation/providers/pop_out_client.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the profile pop-out window shows (issue #5078): the fullscreen
/// profile of the followed or pinned dive, or a short message when there is
/// none to show or App Lock has the app locked.
class PopOutProfileView extends ConsumerWidget {
  const PopOutProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(popOutClientProvider);
    // With no dive shown, the window names no dive: the title shows in the
    // Dock, the taskbar and the window switcher.
    void neutralTitle() => WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      ref.read(popOutWindowControlProvider).setTitle('Submersion');
    });
    if (client.locked) {
      neutralTitle();
      return _Message(
        icon: Icons.lock_outline,
        text: context.l10n.popOut_lockedPlaceholder,
      );
    }
    final diveId = client.follow.shownDiveId;
    if (diveId == null) {
      neutralTitle();
      return _Message(
        icon: Icons.show_chart,
        text: context.l10n.popOut_selectDivePlaceholder,
      );
    }
    return _ShownDive(diveId: diveId, pinned: client.follow.isPinned);
  }
}

class _ShownDive extends ConsumerStatefulWidget {
  const _ShownDive({required this.diveId, required this.pinned});

  final String diveId;
  final bool pinned;

  @override
  ConsumerState<_ShownDive> createState() => _ShownDiveState();
}

class _ShownDiveState extends ConsumerState<_ShownDive> {
  String? _title;

  /// "#142 Salt Pier", or whichever of the two the dive has.
  static String _label(Dive dive) => [
    if (dive.diveNumber != null) '#${dive.diveNumber}',
    if (dive.site?.name case final name? when name.isNotEmpty) name,
  ].join(' ');

  void _afterFrame(void Function() action) =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) action();
      });

  @override
  Widget build(BuildContext context) {
    final diveId = widget.diveId;
    final client = ref.read(popOutClientProvider.notifier);
    ref.listen<int?>(
      profileReviewProvider(diveId),
      (_, seconds) => client.sendCursor(diveId, seconds),
    );

    final dive = ref.watch(diveProvider(diveId));
    final activeDiver = ref.watch(currentDiverIdProvider);
    final diveDiver = dive.value?.diverId;
    // The main window switched diver: this dive is the previous diver's,
    // and would be drawn in the new diver's units and gradient factors.
    final otherDivers =
        activeDiver != null && diveDiver != null && diveDiver != activeDiver;
    if ((dive.hasValue && dive.value == null) || otherDivers) {
      // Deleted, or gone in a sync: stop showing it.
      _afterFrame(() => client.diveMissing(diveId));
      return const SizedBox.shrink();
    }
    final loaded = dive.value;
    if (loaded != null) {
      final title = context.l10n.popOut_windowTitle(_label(loaded));
      if (title != _title) {
        _title = title;
        _afterFrame(
          () => ref.read(popOutWindowControlProvider).setTitle(title),
        );
      }
    }

    return FullscreenProfilePage(
      key: ValueKey(diveId),
      diveId: diveId,
      showTransport: false,
      leading: IconButton(
        icon: Icon(widget.pinned ? Icons.push_pin : Icons.push_pin_outlined),
        tooltip: widget.pinned
            ? context.l10n.popOut_unpin
            : context.l10n.popOut_pin,
        visualDensity: VisualDensity.compact,
        isSelected: widget.pinned,
        onPressed: widget.pinned ? client.unpin : client.pin,
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                text,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
