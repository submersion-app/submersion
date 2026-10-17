import 'package:flutter/material.dart';

/// The colour a scene's facts are set in.
///
/// A scene owns its type colour (near-white on dark water, ink on paper)
/// rather than taking a colour-scheme role: the secondary roles collapse to
/// the primary one in most presets, which is what made the old summary
/// widgets look flat.
class SceneInk extends InheritedWidget {
  const SceneInk({super.key, required this.color, required super.child});

  final Color color;

  /// The nearest scene's ink, or the theme's onSurface outside a scene.
  static Color of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SceneInk>()?.color ??
      Theme.of(context).colorScheme.onSurface;

  @override
  bool updateShouldNotify(SceneInk oldWidget) => oldWidget.color != color;
}

/// Light-weight type in the preset's family, tinted with the scene's ink.
TextStyle _sceneStyle(
  BuildContext context,
  TextStyle? base, {
  double opacity = 1,
  FontWeight weight = FontWeight.w300,
}) {
  return (base ?? const TextStyle()).copyWith(
    fontWeight: weight,
    color: SceneInk.of(context).withValues(alpha: opacity),
  );
}

/// The page name above the headline: small caps, wide tracking, quiet.
class SceneEyebrow extends StatelessWidget {
  const SceneEyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: _sceneStyle(
        context,
        Theme.of(context).textTheme.labelSmall,
        opacity: 0.68,
        weight: FontWeight.w500,
      ).copyWith(letterSpacing: 1.8),
    );
  }
}

/// The one headline fact.
class SceneHeadline extends StatelessWidget {
  const SceneHeadline(this.text, {super.key, this.compact = false});

  final String text;

  /// A narrower pane takes a smaller headline.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Text(
      text,
      style: _sceneStyle(
        context,
        compact ? theme.titleLarge : theme.headlineSmall,
      ),
    );
  }
}

/// The sentence that gives the headline its meaning.
class SceneSentence extends StatelessWidget {
  const SceneSentence(this.text, {super.key, this.maxWidth = 520});

  final String text;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Text(
        text,
        style: _sceneStyle(
          context,
          Theme.of(context).textTheme.bodyMedium,
          opacity: 0.74,
          weight: FontWeight.w400,
        ),
      ),
    );
  }
}

/// A small label under a secondary fact.
class SceneLabel extends StatelessWidget {
  const SceneLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: _sceneStyle(
        context,
        Theme.of(context).textTheme.bodySmall,
        opacity: 0.7,
        weight: FontWeight.w400,
      ),
    );
  }
}

/// A fact that opens something: plain text with a dotted underline, never a
/// button, chevron or accent colour.
class SceneLink extends StatelessWidget {
  const SceneLink({
    super.key,
    required this.text,
    required this.onTap,
    required this.semanticsLabel,
    this.style,
  });

  final String text;
  final VoidCallback onTap;
  final String semanticsLabel;

  /// Overrides the label-sized default, for a link that is itself a value.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final ink = SceneInk.of(context);
    final base =
        style ??
        _sceneStyle(
          context,
          Theme.of(context).textTheme.bodySmall,
          opacity: 0.7,
          weight: FontWeight.w400,
        );
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Text(
            text,
            style: base.copyWith(
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.dotted,
              decorationColor: ink.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}
