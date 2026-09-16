import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/certification_title_l10n.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_ecard.dart';

/// Horizontal gap between cards and around the grid's edge.
const double _kSpacing = 16.0;

/// Upper bound on a single card's width. Above this the grid adds a column
/// rather than letting one card grow to fill a wide screen.
const double _kMaxCardWidth = 600.0;

/// Height of the title/share/more row under a card at the default text
/// scale.
const double _kActionRowBaseExtent = 48.0;

/// Height of the action row under a card, grown for the ambient text scale.
///
/// Mirrors [tripGroupHeaderExtent]: the row itself is a fixed-extent grid
/// child, so at 200% text a hardcoded height would either clip the label or
/// force it to wrap into the card above. Only the lower bound is held, so the
/// row never shrinks below its designed height when a platform reports a
/// scale under 1.
double _actionRowExtent(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
  return _kActionRowBaseExtent * math.max(1.0, scale);
}

/// A vertically scrolling grid of certification e-cards.
///
/// Replaces an earlier horizontal, one-card-per-page layout (issue #966):
/// cards keep their credit-card aspect ratio, but the grid wraps and scrolls
/// down instead of paging sideways, and shows as many cards at once as the
/// viewport allows. Tapping a card flips it to its back/photo face; sharing
/// and the rest of the per-card actions live in a row below each card, since
/// nothing on the card face itself has room for them.
class CertificationEcardGrid extends StatefulWidget {
  /// The certifications to display.
  final List<Certification> certifications;

  /// The name of the diver holding these certifications.
  final String diverName;

  /// Called when a card is long-pressed, with that card's certification.
  final ValueChanged<Certification>? onCardLongPress;

  /// Called when a card's share action is tapped, with that certification.
  final ValueChanged<Certification>? onShare;

  /// Called when a card's more-options action is tapped, with that
  /// certification.
  final ValueChanged<Certification>? onMoreOptions;

  const CertificationEcardGrid({
    super.key,
    required this.certifications,
    required this.diverName,
    this.onCardLongPress,
    this.onShare,
    this.onMoreOptions,
  });

  @override
  State<CertificationEcardGrid> createState() => _CertificationEcardGridState();
}

class _CertificationEcardGridState extends State<CertificationEcardGrid> {
  /// Certification ids currently showing their back face.
  ///
  /// Keyed by id rather than list index: the certification list is refetched
  /// (and rebuilt as new instances) whenever any certification changes, and
  /// an index-based flip would silently reassign itself to whatever
  /// certification ends up at that position instead.
  final Set<String> _flippedIds = {};

  void _toggleFlip(Certification certification) {
    setState(() {
      if (!_flippedIds.remove(certification.id)) {
        _flippedIds.add(certification.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.certifications.isEmpty) {
      return _buildEmptyState(context);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth - _kSpacing * 2;
        // Narrower than the grid's own padding: there is no positive space
        // to lay a card out in, so build nothing rather than a zero-height
        // tile that still tries to fit an action row into it.
        if (contentWidth <= 0) {
          return const SizedBox.shrink();
        }
        final columns = math.max(1, (contentWidth / _kMaxCardWidth).ceil());
        final cellWidth = (contentWidth - _kSpacing * (columns - 1)) / columns;
        final cardHeight = cellWidth / CertificationEcard.aspectRatio;
        final actionRowHeight = _actionRowExtent(context);
        final tileHeight = cardHeight + _kSpacing / 2 + actionRowHeight;
        final aspectRatio = cellWidth / tileHeight;

        return GridView.builder(
          padding: const EdgeInsets.all(_kSpacing),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: _kSpacing,
            mainAxisSpacing: _kSpacing,
            childAspectRatio: aspectRatio,
          ),
          itemCount: widget.certifications.length,
          itemBuilder: (context, index) =>
              _buildTile(context, widget.certifications[index]),
        );
      },
    );
  }

  Widget _buildTile(BuildContext context, Certification certification) {
    // Expanded (not a computed height) absorbs any mismatch between the
    // action row's actual rendered height and the aspect ratio computed
    // above, so a text-scale/font-metrics difference clips nothing instead
    // of overflowing the fixed-extent grid tile.
    return Column(
      children: [
        Expanded(
          child: CertificationEcard(
            certification: certification,
            diverName: widget.diverName,
            showBack: _flippedIds.contains(certification.id),
            onTap: () => _toggleFlip(certification),
            onLongPress: () => widget.onCardLongPress?.call(certification),
          ),
        ),
        const SizedBox(height: _kSpacing / 2),
        SizedBox(
          height: _actionRowExtent(context),
          child: _buildActionRow(context, certification),
        ),
      ],
    );
  }

  Widget _buildActionRow(BuildContext context, Certification certification) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Row(
      children: [
        Expanded(
          child: Text(
            certificationTitleL10n(certification, l10n),
            key: const ValueKey('actionRowTitle'),
            style: theme.textTheme.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.share),
          tooltip: l10n.certifications_wallet_tooltip_share,
          onPressed: () => widget.onShare?.call(certification),
        ),
        IconButton(
          icon: const Icon(Icons.more_vert),
          tooltip: l10n.certifications_wallet_tooltip_moreOptions,
          onPressed: () => widget.onMoreOptions?.call(certification),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.card_membership,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.certifications_ecardStack_empty_title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.certifications_ecardStack_empty_subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
