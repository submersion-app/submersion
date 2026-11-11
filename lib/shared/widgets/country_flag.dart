import 'package:country_flags/country_flags.dart' as flags;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:jovial_svg/jovial_svg.dart';

import 'package:submersion/core/geography/country_code.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// A small flag for an ISO 3166-1 alpha-2 [code] (issue #4426).
///
/// Decoration only: the country it stands for is always named in the text
/// beside it, or labelled by the group that holds it, so it is hidden from
/// screen readers. A hairline outline keeps white-edged flags (Japan,
/// Indonesia) visible on a light surface and dark ones on a dark surface.
///
/// Draws the country_flags package's vector assets through jovial_svg
/// directly rather than through the package's widget, for two things that
/// widget does not offer: the outline appears only once the flag has
/// loaded, so a list never flashes empty boxes, and loaded flags are kept
/// in a shared cache, so a flag scrolling back into view draws at once.
class CountryFlag extends StatelessWidget {
  const CountryFlag({super.key, required this.code, this.height = 11});

  final String code;

  /// The flag's height; its width keeps a 16:11 ratio.
  final double height;

  static const double _radius = 2;

  /// Every flag a logbook is likely to show at once, and then some.
  static final ScalableImageCache _cache = ScalableImageCache(size: 64);

  /// Each code's asset name, looked up once: the package scans its whole
  /// table on every call, and a list draws a flag in every row.
  static final Map<String, String?> _flagCodes = {};

  @override
  Widget build(BuildContext context) {
    final width = height * 16 / 11;
    final flagCode = _flagCodes.putIfAbsent(
      code,
      () => flags.FlagCode.fromCountryCode(code),
    );
    final outline = Theme.of(context).colorScheme.outlineVariant;
    // Its own size whatever the parent's constraints: a stretched or tight
    // slot must not turn the flag into a banner. The slot is kept while the
    // flag loads, so the text beside it does not shift.
    return ExcludeSemantics(
      child: Align(
        widthFactor: 1,
        heightFactor: 1,
        child: SizedBox(
          width: width,
          height: height,
          child: flagCode == null
              ? null
              : ScalableImageWidget.fromSISource(
                  si: ScalableImageSource.fromSI(
                    rootBundle,
                    'packages/country_flags/res/si/$flagCode.si',
                  ),
                  cache: _cache,
                  fit: BoxFit.cover,
                  onLoading: (_) => const SizedBox.shrink(),
                  onLoaded: (_, image) => DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_radius),
                      border: Border.all(color: outline, width: 0.5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(_radius),
                      child: ScalableImageWidget(si: image, fit: BoxFit.cover),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// A location line with the flag of [country] before it, when the diver
/// shows flags and the country is recognised; otherwise [fallbackLeading]
/// (or nothing) before it.
///
/// The leading widget is centred on the text's first line, so a location
/// that wraps (the dive header on a phone) keeps its flag beside the first
/// line. [text] keeps its own line limit and overflow.
class LocationWithFlag extends ConsumerWidget {
  const LocationWithFlag({
    super.key,
    required this.country,
    required this.text,
    this.fallbackLeading,
    this.flagHeight = 11,
    this.gap = 4,
  });

  /// The site's stored country, free text.
  final String? country;

  final Widget text;

  /// Shown when there is no flag, such as the pin on Site Details.
  final Widget? fallbackLeading;

  final double flagHeight;

  /// Space between the leading widget and the text.
  final double gap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(showCountryFlagsProvider)
        ? countryCodeFor(country)
        : null;
    final leading = code != null
        ? CountryFlag(code: code, height: flagHeight)
        : fallbackLeading;
    if (leading == null) return text;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _firstLineHeight(context),
          child: Center(child: leading),
        ),
        SizedBox(width: gap),
        Flexible(child: text),
      ],
    );
  }

  /// The height of one line of [text] as it will lay out.
  ///
  /// Measured once per style, text scale and direction: a list's rows share
  /// one style, so a long list lays text out for this once, not per row.
  double _firstLineHeight(BuildContext context) {
    final own = text is Text ? (text as Text).style : null;
    final style = DefaultTextStyle.of(context).style.merge(own);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final key = (style, scaler, direction);
    // A font that loads after a line was measured (a theme's Google Font)
    // changes the line's height, so a font change forgets every measurement.
    if (!_listeningForFonts) {
      _listeningForFonts = true;
      PaintingBinding.instance.systemFonts.addListener(_lineHeights.clear);
    }
    final cached = _lineHeights[key];
    if (cached != null) return cached;

    final painter = TextPainter(
      text: TextSpan(text: 'Ag', style: style),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final height = painter.height;
    painter.dispose();
    _measurements++;
    // A handful of styles in practice; the bound only stops a theme or
    // scale being changed over and over from growing it without end.
    if (_lineHeights.length >= _maxLineHeights) _lineHeights.clear();
    return _lineHeights[key] = height;
  }

  static const _maxLineHeights = 32;
  static final Map<(TextStyle, TextScaler, TextDirection), double>
  _lineHeights = {};
  static int _measurements = 0;
  static bool _listeningForFonts = false;

  /// How many lines have been measured since [debugResetLineHeights].
  @visibleForTesting
  static int get debugLineMeasurements => _measurements;

  /// Forgets every measured line height.
  @visibleForTesting
  static void debugResetLineHeights() {
    _lineHeights.clear();
    _measurements = 0;
  }
}
