import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/router/section_navigation.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_summary_scene_facts.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/scenes/chart_marks_painter.dart';
import 'package:submersion/shared/widgets/scenes/chart_painter.dart';
import 'package:submersion/shared/widgets/summary/chart_marks_layer.dart';
import 'package:submersion/shared/widgets/summary/scene_text.dart';
import 'package:submersion/shared/widgets/summary/summary_scene_pane.dart';

/// The Dive sites summary pane as a scene: a paper chart with the most
/// dived, best rated and last dived sites marked on it.
///
/// It reads exactly what `SiteSummaryWidget` reads. The marks sit at fixed
/// places: the chart is a drawing, not a map of where the sites are.
class SiteSummaryScene extends ConsumerWidget {
  const SiteSummaryScene({super.key});

  /// Below this width the headline shrinks and mark labels shorten.
  static const double compactWidth = 560;

  /// Where the first, second and third marked site sit, as fractions of the
  /// region below the headline.
  static const markPositions = [
    Offset(0.56, 0.24),
    Offset(0.30, 0.66),
    Offset(0.74, 0.50),
  ];

  static const _haloDelays = [0.0, -3.0, -5.0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sitesAsync = ref.watch(sitesWithCountsProvider);
    final sites = sitesAsync.hasError ? null : sitesAsync.value;
    final facts = sites == null ? null : SiteSceneFacts.from(sites);
    final palette = ChartPalette.of(Theme.of(context).brightness);

    return SummaryScenePane(
      ink: palette.ink,
      shadows: palette.inkShadows,
      painterBuilder: (seconds, brightness) =>
          ChartPainter(seconds: seconds, brightness: brightness),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final compact = w < compactWidth;
          final inset = w * 0.075;
          final footer = facts == null ? null : _footer(context, facts);
          return Padding(
            padding: EdgeInsets.only(top: h * 0.11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: inset,
                    end: compact ? inset : w * 0.30,
                  ),
                  child: _Headline(
                    facts: facts,
                    compact: compact,
                    sentenceWidth: compact ? w - 2 * inset : 520,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: facts == null
                      ? const SizedBox.shrink()
                      : ChartMarksLayer(
                          compact: compact,
                          marks: _marks(context, facts),
                        ),
                ),
                if (footer != null)
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      inset,
                      8,
                      inset,
                      h * 0.09,
                    ),
                    child: SceneFooter(footer),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<ChartMark> _marks(BuildContext context, SiteSceneFacts facts) {
    final l10n = context.l10n;
    final marked = facts.marked;
    return [
      for (var i = 0; i < marked.length; i++)
        ChartMark(
          spot: ChartSpot(at: markPositions[i], haloDelay: _haloDelays[i]),
          label: l10n.diveSites_scene_mark(
            marked[i].site.name,
            l10n.diveSites_list_tile_diveCount(marked[i].diveCount),
          ),
          compactLabel: marked[i].site.name,
          onTap: () {
            final path = GoRouterState.of(context).uri.path;
            context.goInPlace('$path?selected=${marked[i].site.id}');
          },
        ),
    ];
  }

  String? _footer(BuildContext context, SiteSceneFacts facts) {
    final l10n = context.l10n;
    final parts = [
      if (facts.withGps > 0) l10n.diveSites_scene_withGps(facts.withGps),
      if (facts.notDived > 0) l10n.diveSites_scene_notDived(facts.notDived),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class _Headline extends StatelessWidget {
  const _Headline({
    required this.facts,
    required this.compact,
    required this.sentenceWidth,
  });

  final SiteSceneFacts? facts;
  final bool compact;
  final double sentenceWidth;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final eyebrow = SceneEyebrow(l10n.diveSites_summary_header_title);
    final facts = this.facts;
    if (facts == null) return eyebrow;
    final headline = facts.countryCount == 0
        ? l10n.diveSites_scene_headlineNoCountries(facts.siteCount)
        : l10n.diveSites_scene_headline(facts.siteCount, facts.countryCount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        eyebrow,
        const SizedBox(height: 6),
        SceneHeadline(headline, compact: compact),
        // An empty library has nothing to say past its count; the pane only
        // shows a scene for one when the diver flips the toggle.
        if (facts.siteCount > 0) ...[
          const SizedBox(height: 6),
          SceneSentence(_sentence(context, facts), maxWidth: sentenceWidth),
        ],
      ],
    );
  }

  String _sentence(BuildContext context, SiteSceneFacts facts) {
    final l10n = context.l10n;
    final most = facts.mostDived?.site.name;
    final best = facts.bestRated?.site.name;
    final last = facts.lastDived?.site.name;
    if (most != null && last != null) {
      return best == null
          ? l10n.diveSites_scene_sentenceUnrated(most, last)
          : l10n.diveSites_scene_sentence(most, best, last);
    }
    return best == null
        ? l10n.diveSites_scene_sentenceNone
        : l10n.diveSites_scene_sentenceUndived(best);
  }
}
