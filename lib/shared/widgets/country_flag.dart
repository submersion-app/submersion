import 'package:country_flags/country_flags.dart' as flags;
import 'package:flutter/material.dart';

import 'package:submersion/core/geography/country_code.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// A small flag for an ISO 3166-1 alpha-2 [code] (issue #4426).
///
/// Decoration only: the country it stands for is always named in the text
/// beside it, or labelled by the group that holds it, so it is hidden from
/// screen readers. A hairline outline keeps white-edged flags (Japan,
/// Indonesia) visible on a light surface and dark ones on a dark surface.
class CountryFlag extends StatelessWidget {
  const CountryFlag({super.key, required this.code, this.height = 11});

  final String code;

  /// The flag's height; its width keeps a 16:11 ratio.
  final double height;

  static const double _radius = 2;

  @override
  Widget build(BuildContext context) {
    final width = height * 16 / 11;
    // Its own size whatever the parent's constraints: a stretched or tight
    // slot must not turn the flag into a banner.
    return ExcludeSemantics(
      child: Align(
        widthFactor: 1,
        heightFactor: 1,
        child: SizedBox(
          width: width,
          height: height,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 0.5,
              ),
            ),
            child: flags.CountryFlag.fromCountryCode(
              code,
              theme: flags.ImageTheme(
                width: width,
                height: height,
                shape: const flags.RoundedRectangle(_radius),
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
  double _firstLineHeight(BuildContext context) {
    final own = text is Text ? (text as Text).style : null;
    final style = DefaultTextStyle.of(context).style.merge(own);
    final painter = TextPainter(
      text: TextSpan(text: 'Ag', style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }
}
