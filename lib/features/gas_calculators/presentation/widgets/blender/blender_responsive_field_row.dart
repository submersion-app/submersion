import 'package:flutter/material.dart';

/// Lays [fields] out side by side when there is room for all of them at
/// [minFieldWidth] apiece, and stacks them otherwise (issue #1876) --
/// generalises `ResponsiveSectionPair`'s row-or-stack idea
/// (`lib/features/dive_log/presentation/widgets/responsive_section_pair.dart`)
/// from exactly two widgets to however many a gas role's row needs (two for
/// O2/Helium, three for Topup's added O2% field).
///
/// Measures its own available width with a [LayoutBuilder] rather than the
/// screen width, so it behaves the same inside a narrow settings card on a
/// wide window as it does on an actual narrow phone.
class BlenderResponsiveFieldRow extends StatelessWidget {
  const BlenderResponsiveFieldRow({
    super.key,
    required this.fields,
    this.minFieldWidth = 150,
    this.gap = 8,
  });

  final List<Widget> fields;

  /// The width each field needs before this stops stacking them.
  final double minFieldWidth;

  /// Gutter between fields in row mode, and between stacked fields.
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (fields.length <= 1) {
      return fields.isEmpty ? const SizedBox() : fields.single;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final needed =
            minFieldWidth * fields.length + gap * (fields.length - 1);
        if (constraints.maxWidth >= needed) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < fields.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                Expanded(child: fields[i]),
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < fields.length; i++) ...[
              if (i > 0) SizedBox(height: gap),
              fields[i],
            ],
          ],
        );
      },
    );
  }
}
